import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../products/data/models/agricultural_product.dart';
import '../../../products/data/repositories/products_repository.dart';
import '../../data/models/public_producer_location.dart';
import '../../data/repositories/public_location_repository.dart';

class ProducerMapEntry {
  const ProducerMapEntry(this.location, this.products);
  final PublicProducerLocation location;
  final List<AgriculturalProduct> products;

  static List<ProducerMapEntry> fromData(
    List<PublicProducerLocation> locations,
    List<AgriculturalProduct> products,
  ) => locations
      .map(
        (location) => ProducerMapEntry(
          location,
          products
              .where(
                (product) =>
                    product.producerId == location.producerId &&
                    product.isPublished &&
                    product.availableQuantity > 0,
              )
              .toList(),
        ),
      )
      .where((entry) => entry.products.isNotEmpty)
      .toList();

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
  final _service = SupabaseService();
  late final _locations =
      widget.locationRepository ??
      PublicLocationRepository(supabaseService: _service);
  late final _products =
      widget.productsRepository ??
      ProductsRepository(supabaseService: _service);
  final _controller = MapController();
  List<ProducerMapEntry> _entries = const [];
  LatLng? _position;
  double _radiusKm = 20;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final locationsFuture = _locations.listPublished();
      final productsFuture = _products.getPublishedProducts();
      final locations = await locationsFuture;
      final products = await productsFuture;
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
      if (!await Geolocator.isLocationServiceEnabled()) {
        _notice('Activa la ubicacion del dispositivo para medir distancias.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _notice('Permiso denegado. El mapa sigue disponible sin distancias.');
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _position = point);
      _controller.move(point, 12);
    } catch (_) {
      _notice('No se pudo obtener tu ubicacion.');
    }
  }

  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  double _distanceKm(LatLng target) =>
      const Distance().as(LengthUnit.Kilometer, _position!, target);

  List<ProducerMapEntry> get _visible =>
      ProducerMapEntry.withinRadius(_entries, _position, _radiusKm);

  void _showProducer(ProducerMapEntry entry) {
    final point = LatLng(entry.location.latitude, entry.location.longitude);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                entry.location.alias,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                entry.location.placeName,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (_position != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Aproximadamente ${_distanceKm(point).toStringAsFixed(1)} km',
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Productos disponibles',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ...entry.products
                  .take(3)
                  .map(
                    (product) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(product.name),
                      subtitle: Text(product.priceWithUnit),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        context.push('${AppRoutes.products}/${product.id}');
                      },
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mapa de productores'),
        actions: [
          IconButton(
            tooltip: 'Actualizar productores',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Usar mi ubicacion',
            onPressed: _locate,
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: const MapOptions(
              initialCenter: LatLng(-1.67, -78.65),
              initialZoom: 8,
            ),
            children: [
              if (widget.showTiles)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.agroplus.app',
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
                  for (final entry in visible)
                    Marker(
                      point: LatLng(
                        entry.location.latitude,
                        entry.location.longitude,
                      ),
                      width: 56,
                      height: 56,
                      child: IconButton(
                        onPressed: () => _showProducer(entry),
                        tooltip: entry.location.alias,
                        icon: const Icon(
                          Icons.agriculture,
                          size: 34,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
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
          if (_position != null)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('Radio de busqueda: ${_radiusKm.round()} km'),
                      Slider(
                        value: _radiusKm,
                        min: 5,
                        max: 100,
                        divisions: 19,
                        onChanged: (value) => setState(() => _radiusKm = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading && _error != null)
            Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 64),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!_loading && _error == null && visible.isEmpty)
            Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.map_outlined,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _position == null
                            ? 'Aun no hay productores con zona publica y productos disponibles.'
                            : 'No hay productores disponibles en este radio.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
