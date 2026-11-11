import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../chat/presentation/widgets/contact_producer_button.dart';
import '../../../products/data/models/agricultural_product.dart';
import '../../../products/data/repositories/products_repository.dart';
import '../../../main/presentation/views/main_navigation_view.dart';
import '../../data/models/public_producer_location.dart';
import '../../data/repositories/public_location_repository.dart';

class ProducerMapEntry {
  const ProducerMapEntry(this.location, this.products);
  final PublicProducerLocation location;
  final List<AgriculturalProduct> products;

  static List<ProducerMapEntry> fromData(
    List<PublicProducerLocation> locations,
    List<AgriculturalProduct> products,
  ) {
    final productsByProducer = <String, List<AgriculturalProduct>>{};
    for (final product in products) {
      if (!product.isPublished || product.availableQuantity <= 0) continue;
      (productsByProducer[product.producerId] ??= []).add(product);
    }

    return locations
        .map((location) {
          return ProducerMapEntry(
            location,
            productsByProducer[location.producerId] ?? const [],
          );
        })
        .where((entry) => entry.products.isNotEmpty)
        .toList(growable: false);
  }

  static List<ProducerMapEntry> withinRadius(
    List<ProducerMapEntry> entries,
    LatLng? position,
    double radiusKm,
  ) {
    if (position == null) {
      return entries;
    }
    return entries
        .where(
          (entry) =>
              const Distance().as(
                LengthUnit.Kilometer,
                position,
                LatLng(entry.location.latitude, entry.location.longitude),
              ) <=
              radiusKm,
        )
        .toList();
  }
}

class ProducerMapCluster {
  const ProducerMapCluster({required this.entries, required this.point});

  final List<ProducerMapEntry> entries;
  final LatLng point;

  bool get isCluster => entries.length > 1;

  static List<ProducerMapCluster> group(
    List<ProducerMapEntry> entries,
    MapCamera? camera,
  ) {
    if (camera == null || entries.length < 2) {
      return entries
          .map(
            (entry) => ProducerMapCluster(
              entries: [entry],
              point: LatLng(entry.location.latitude, entry.location.longitude),
            ),
          )
          .toList(growable: false);
    }

    const radius = 52.0;
    const cellSize = 52.0;
    final projected = entries
        .map(
          (entry) => camera.project(
            LatLng(entry.location.latitude, entry.location.longitude),
          ),
        )
        .toList(growable: false);
    final parents = List<int>.generate(entries.length, (index) => index);

    int rootOf(int index) {
      var root = index;
      while (parents[root] != root) {
        root = parents[root];
      }
      while (parents[index] != index) {
        final parent = parents[index];
        parents[index] = root;
        index = parent;
      }
      return root;
    }

    void join(int first, int second) {
      final firstRoot = rootOf(first);
      final secondRoot = rootOf(second);
      if (firstRoot != secondRoot) parents[secondRoot] = firstRoot;
    }

    final cells = <(int, int), List<int>>{};
    for (var index = 0; index < projected.length; index++) {
      final point = projected[index];
      final cellX = (point.x / cellSize).floor();
      final cellY = (point.y / cellSize).floor();
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          for (final neighbor in cells[(cellX + dx, cellY + dy)] ?? const []) {
            final other = projected[neighbor];
            final differenceX = point.x - other.x;
            final differenceY = point.y - other.y;
            if (differenceX * differenceX + differenceY * differenceY <=
                radius * radius) {
              join(index, neighbor);
            }
          }
        }
      }
      (cells[(cellX, cellY)] ??= []).add(index);
    }

    final grouped = <int, List<ProducerMapEntry>>{};
    for (var index = 0; index < entries.length; index++) {
      (grouped[rootOf(index)] ??= []).add(entries[index]);
    }
    return grouped.values
        .map((group) {
          if (group.length == 1) {
            final location = group.single.location;
            return ProducerMapCluster(
              entries: group,
              point: LatLng(location.latitude, location.longitude),
            );
          }
          final latitude =
              group
                  .map((entry) => entry.location.latitude)
                  .reduce((a, b) => a + b) /
              group.length;
          final longitude =
              group
                  .map((entry) => entry.location.longitude)
                  .reduce((a, b) => a + b) /
              group.length;
          return ProducerMapCluster(
            entries: group,
            point: LatLng(
              (latitude * 100).roundToDouble() / 100,
              (longitude * 100).roundToDouble() / 100,
            ),
          );
        })
        .toList(growable: false);
  }
}

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    this.locationRepository,
    this.productsRepository,
    this.showTiles = true,
  });
  final PublicLocationRepository? locationRepository;
  final ProductsRepository? productsRepository;
  final bool showTiles;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  ModuleRefreshRegistry? _refreshRegistry;
  final _service = SupabaseService();
  late final _locations =
      widget.locationRepository ??
      PublicLocationRepository(supabaseService: _service);
  late final _products =
      widget.productsRepository ??
      ProductsRepository(supabaseService: _service);
  final _controller = MapController();
  final _searchController = TextEditingController();
  MapCamera? _mapCamera;
  int _clusterZoomLevel = 8;
  List<ProducerMapEntry> _entries = const [];
  LatLng? _position;
  double _radiusKm = 20;
  bool _loading = true;
  String? _error;
  String _query = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = ModuleRefreshScope.maybeOf(context);
    if (identical(registry, _refreshRegistry)) return;
    _refreshRegistry?.unregister(AppRoutes.map);
    _refreshRegistry = registry;
    _refreshRegistry?.register(AppRoutes.map, _load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final locations = await _locations.listPublished();
      if (!mounted) return;
      if (locations.isEmpty) {
        setState(() {
          _entries = const [];
          _loading = false;
        });
        return;
      }
      final producerIds = locations.map((location) => location.producerId);
      final products = await _products.getPublishedProductsForProducers(
        producerIds,
      );
      if (!mounted) return;
      setState(() {
        _entries = ProducerMapEntry.fromData(locations, products);
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar el mapa. Intenta de nuevo.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _locate() async {
    try {
      final continueToLocation = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.my_location_outlined),
          title: const Text('Buscar cerca de mi'),
          content: const Text(
            'Usaremos tu ubicacion solo mientras exploras el mapa para '
            'centrarlo y calcular distancias. No se guardara en tu perfil.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (continueToLocation != true || !mounted) return;
      if (!await Geolocator.isLocationServiceEnabled()) {
        _notice(
          'Activa la ubicacion del dispositivo para buscar cerca de ti.',
          actionLabel: 'Activar',
          onAction: Geolocator.openLocationSettings,
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _notice(
          'El permiso esta bloqueado. Puedes activarlo en los ajustes; '
          'el mapa manual sigue disponible.',
          actionLabel: 'Ajustes',
          onAction: Geolocator.openAppSettings,
        );
        return;
      }
      if (permission == LocationPermission.denied) {
        _notice(
          'Sin permiso no calculamos distancias. Puedes explorar el mapa manualmente.',
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _position = point);
      _controller.move(point, 12);
    } catch (_) {
      _notice('No se pudo obtener tu ubicacion.');
    }
  }

  void _notice(
    String message, {
    String? actionLabel,
    Future<bool> Function()? onAction,
  }) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: () => onAction()),
        ),
      );
    }
  }

  double _distanceKm(LatLng target) =>
      const Distance().as(LengthUnit.Kilometer, _position!, target);

  List<String> get _categories =>
      _entries
          .expand(
            (entry) => entry.products.map((product) => product.categoryName),
          )
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  List<ProducerMapEntry> get _visible {
    final radiusEntries = ProducerMapEntry.withinRadius(
      _entries,
      _position,
      _radiusKm,
    );
    final query = _query.trim().toLowerCase();
    final results = radiusEntries
        .map((entry) {
          final producerMatches =
              entry.location.alias.toLowerCase().contains(query) ||
              entry.location.placeName.toLowerCase().contains(query);
          final products = entry.products.where((product) {
            final matchesCategory =
                _selectedCategory == null ||
                product.categoryName == _selectedCategory;
            final matchesQuery =
                query.isEmpty ||
                producerMatches ||
                product.name.toLowerCase().contains(query) ||
                product.categoryName.toLowerCase().contains(query);
            return matchesCategory && matchesQuery;
          }).toList();
          return ProducerMapEntry(entry.location, products);
        })
        .where((entry) => entry.products.isNotEmpty)
        .toList();
    if (_position != null) {
      results.sort(
        (first, second) =>
            _distanceKm(
              LatLng(first.location.latitude, first.location.longitude),
            ).compareTo(
              _distanceKm(
                LatLng(second.location.latitude, second.location.longitude),
              ),
            ),
      );
    }
    return results;
  }

  void _showProducer(ProducerMapEntry entry) {
    final mapContext = context;
    final point = LatLng(entry.location.latitude, entry.location.longitude);
    final auth = context.read<AuthViewModel>();
    final userId = auth.currentUser?.id;
    final canContact =
        (auth.selectedRole == UserRole.buyer ||
            auth.selectedRole == UserRole.producer) &&
        entry.location.producerId != userId;
    final contactProduct = entry.products
        .where((product) => product.producerId != userId)
        .firstOrNull;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.52,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, scrollController) => SafeArea(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.primarySurface,
                    child: Icon(Icons.agriculture, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.location.alias,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(entry.location.placeName),
                      ],
                    ),
                  ),
                ],
              ),
              if (_position != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Aproximadamente ${_distanceKm(point).toStringAsFixed(1)} km de ti',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Productos disponibles',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...entry.products.map(
                (product) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: const Icon(
                      Icons.eco_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(product.name),
                    subtitle: Text(
                      '${product.categoryName} · ${product.phaseName}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          product.priceWithUnit,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.push('${AppRoutes.products}/${product.id}');
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    mapContext.push(
                      AppRoutes.publicProducerProfile.replaceFirst(
                        ':producerId',
                        entry.location.producerId,
                      ),
                    );
                  });
                },
                icon: const Icon(Icons.person_outline),
                label: const Text('Ver perfil del productor'),
              ),
              if (canContact && contactProduct != null) ...[
                const SizedBox(height: 12),
                ContactProducerButton(productId: contactProduct.id),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showProducerCluster(ProducerMapCluster cluster) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          itemCount: cluster.entries.length + 1,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${cluster.entries.length} productores en esta zona',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              );
            }
            final entry = cluster.entries[index - 1];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppColors.primarySurface,
                child: Icon(Icons.agriculture, color: AppColors.primary),
              ),
              title: Text(entry.location.alias),
              subtitle: Text(
                '${entry.location.placeName} · ${entry.products.length} '
                '${entry.products.length == 1 ? 'producto' : 'productos'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(sheetContext);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _showProducer(entry);
                });
              },
            );
          },
        ),
      ),
    );
  }

  List<Marker> _producerMarkers(
    List<ProducerMapEntry> entries,
  ) => ProducerMapCluster.group(entries, _mapCamera)
      .map((cluster) {
        if (!cluster.isCluster) {
          final entry = cluster.entries.single;
          return Marker(
            point: cluster.point,
            width: 56,
            height: 56,
            child: Tooltip(
              message:
                  '${entry.location.alias} · ${entry.products.length} productos',
              child: Material(
                color: AppColors.surface,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _showProducer(entry),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.agriculture,
                      size: 30,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return Marker(
          point: cluster.point,
          width: 52,
          height: 52,
          child: Tooltip(
            message: '${cluster.entries.length} productores en esta zona',
            child: Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _showProducerCluster(cluster),
                child: Center(
                  child: Text(
                    '${cluster.entries.length}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.surface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      })
      .toList(growable: false);

  void _showFilters() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        var selectedCategory = _selectedCategory;
        var radiusKm = _radiusKm;
        return StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filtrar productores',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar filtros',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (_categories.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Categoria de producto',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Todas'),
                        selected: selectedCategory == null,
                        onSelected: (_) {
                          setSheetState(() => selectedCategory = null);
                          setState(() => _selectedCategory = null);
                        },
                      ),
                      ..._categories.map(
                        (category) => ChoiceChip(
                          label: Text(category),
                          selected: selectedCategory == category,
                          onSelected: (selected) {
                            final value = selected ? category : null;
                            setSheetState(() => selectedCategory = value);
                            setState(() => _selectedCategory = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Distancia',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (_position == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Activa “Buscar cerca de mi” en el mapa para filtrar por distancia.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.radar, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('${radiusKm.round()} km'),
                      Expanded(
                        child: Slider(
                          value: radiusKm,
                          min: 5,
                          max: 100,
                          divisions: 19,
                          label: '${radiusKm.round()} km',
                          onChanged: (value) {
                            setSheetState(() => radiusKm = value);
                            setState(() => _radiusKm = value);
                          },
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      setSheetState(() {
                        selectedCategory = null;
                        radiusKm = 20;
                      });
                      setState(() {
                        _selectedCategory = null;
                        _radiusKm = 20;
                      });
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Limpiar filtros'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultsSheet(
    List<ProducerMapEntry> visible,
  ) => DraggableScrollableSheet(
    initialChildSize: 0.22,
    minChildSize: 0.19,
    maxChildSize: 0.62,
    snap: true,
    snapSizes: const [0.22, 0.42, 0.62],
    builder: (context, scrollController) {
      final hasResults = !_loading && _error == null && visible.isNotEmpty;
      return Material(
        color: AppColors.surface,
        elevation: 12,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          itemCount: hasResults ? visible.length + 2 : 3,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }
            if (index == 1) {
              return Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _position == null
                                ? 'Productores en el mapa'
                                : 'Productores cerca de ti',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '© OpenStreetMap contributors',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (!_loading && _error == null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${visible.length}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: AppColors.primaryDark),
                        ),
                      ),
                  ],
                ),
              );
            }

            if (hasResults) {
              final entry = visible[index - 2];
              final point = LatLng(
                entry.location.latitude,
                entry.location.longitude,
              );
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primarySurface,
                  child: Icon(
                    Icons.agriculture_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: Text(
                  entry.location.alias,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${entry.location.placeName} · ${entry.products.length} '
                  '${entry.products.length == 1 ? 'producto' : 'productos'}'
                  '${entry.products.isNotEmpty ? ' · ${entry.products.first.name}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: _position == null
                    ? const Icon(Icons.chevron_right)
                    : Text(
                        '${_distanceKm(point).toStringAsFixed(1)} km',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                onTap: () => _showProducer(entry),
              );
            }

            if (_loading) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (_error != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  const Icon(
                    Icons.agriculture_outlined,
                    size: 38,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _entries.isEmpty
                        ? 'Aun no hay productores con zona publica y productos disponibles.'
                        : 'No encontramos resultados. Prueba otra busqueda o cambia el radio.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (_query.isNotEmpty || _selectedCategory != null)
                    TextButton(
                      onPressed: () => setState(() {
                        _query = '';
                        _searchController.clear();
                        _selectedCategory = null;
                      }),
                      child: const Text('Quitar busqueda y filtros'),
                    ),
                ],
              ),
            );
          },
        ),
      );
    },
  );

  @override
  void dispose() {
    _refreshRegistry?.unregister(AppRoutes.map);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: LatLng(-1.67, -78.65),
              initialZoom: 8,
              onMapReady: () {
                if (!mounted) return;
                final camera = _controller.camera;
                setState(() {
                  _mapCamera = camera;
                  _clusterZoomLevel = camera.zoom.floor();
                });
                _load();
              },
              onPositionChanged: (camera, _) {
                final zoomLevel = camera.zoom.floor();
                if (_mapCamera == null || zoomLevel != _clusterZoomLevel) {
                  setState(() {
                    _mapCamera = camera;
                    _clusterZoomLevel = zoomLevel;
                  });
                } else {
                  // Panning translates every marker equally; cluster membership
                  // changes only with zoom, so avoid rebuilding on every drag.
                  _mapCamera = camera;
                }
              },
            ),
            children: [
              if (widget.showTiles)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.agro.app.proyecto_agro',
                ),
              if (_position != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _position!,
                      radius: _radiusKm * 1000,
                      useRadiusInMeter: true,
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderColor: AppColors.primary,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  ..._producerMarkers(visible),
                  if (_position != null)
                    Marker(
                      point: _position!,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.person_pin_circle,
                        size: 40,
                        color: AppColors.info,
                      ),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: AppColors.surface,
                elevation: 8,
                shadowColor: Theme.of(context).shadowColor,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _query = value),
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            hintText: 'Producto, productor o sector',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        IconButton(
                          tooltip: 'Limpiar busqueda',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                      IconButton(
                        tooltip: 'Filtrar productores',
                        onPressed: _showFilters,
                        icon: Badge(
                          isLabelVisible: _selectedCategory != null,
                          child: const Icon(Icons.tune_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16 + MediaQuery.sizeOf(context).height * 0.22,
            child: SafeArea(
              top: false,
              child: FloatingActionButton.small(
                heroTag: 'map-locate-button',
                tooltip: 'Buscar cerca de mi',
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.primary,
                elevation: 6,
                onPressed: _locate,
                child: const Icon(Icons.my_location_rounded),
              ),
            ),
          ),
          _buildResultsSheet(visible),
        ],
      ),
    );
  }
}
