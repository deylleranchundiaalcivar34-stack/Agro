import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_service.dart';
import '../../data/models/ecuador_administrative_catalog.dart';
import '../../data/repositories/public_location_repository.dart';
import '../../data/services/administrative_area_resolver.dart';
import '../../../profile/presentation/widgets/profile_subpage.dart';

class PublicLocationEditView extends StatefulWidget {
  const PublicLocationEditView({
    super.key,
    this.repository,
    this.showTiles = true,
  });
  final PublicLocationRepository? repository;
  final bool showTiles;

  @override
  State<PublicLocationEditView> createState() => _PublicLocationEditViewState();
}

class _PublicLocationEditViewState extends State<PublicLocationEditView> {
  late final PublicLocationRepository _repository =
      widget.repository ??
      PublicLocationRepository(supabaseService: SupabaseService());
  late final Future<List<EcuadorProvince>> _catalogFuture =
      EcuadorAdministrativeCatalog.load();
  final _areaResolver = AdministrativeAreaResolver();
  final _alias = TextEditingController();
  final _mapController = MapController();
  List<EcuadorProvince> _provinces = const [];
  String? _selectedProvince;
  String? _selectedCanton;
  LatLng? _point;
  bool _mapReady = false;
  bool _loading = true;
  bool _saving = false;
  bool _resolvingArea = false;
  bool _allowManualAreaFallback = false;
  bool _published = false;
  String? _error;
  String? _areaStatus;
  int _areaLookupRevision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final provinces = await _catalogFuture;
      final mine = await _repository.getMine();
      if (!mounted) return;
      _provinces = provinces;
      if (mine != null) {
        _alias.text = mine.alias;
        _point = LatLng(mine.latitude, mine.longitude);
        final province = provinces.where((item) => item.name == mine.province);
        if (province.isNotEmpty) {
          _selectedProvince = province.first.name;
          if (province.first.cantons.any((item) => item.name == mine.canton)) {
            _selectedCanton = mine.canton;
          }
        }
      }
      setState(() {
        _published = mine != null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar tu zona. Intenta de nuevo.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final point = _point;
    if (point == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _repository.saveMineWithAdministrativeArea(
        alias: _alias.text,
        province: _selectedProvince!,
        canton: _selectedCanton!,
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (!mounted) return;
      setState(() {
        _point = LatLng(saved.latitude, saved.longitude);
        _published = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Zona publica guardada.')));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo publicar. Revisa los datos y tu conexion.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _remove() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository.removeMine();
      if (!mounted) return;
      setState(() {
        _point = null;
        _published = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu zona ya no es publica.')),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo retirar tu zona.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _alias.dispose();
    super.dispose();
  }

  EcuadorProvince? get _selectedProvinceModel {
    for (final province in _provinces) {
      if (province.name == _selectedProvince) return province;
    }
    return null;
  }

  EcuadorCanton? get _selectedCantonModel {
    for (final canton in _selectedProvinceModel?.cantons ?? const []) {
      if (canton.name == _selectedCanton) return canton;
    }
    return null;
  }

  LatLng get _selectedAreaCenter {
    final canton = _selectedCantonModel;
    if (canton != null) return LatLng(canton.latitude, canton.longitude);
    final province = _selectedProvinceModel;
    if (province != null) return LatLng(province.latitude, province.longitude);
    return const LatLng(-1.67, -78.65);
  }

  void _centerPreview({required bool cantonSelected}) {
    if (!_mapReady) return;
    _mapController.move(_selectedAreaCenter, cantonSelected ? 11 : 8);
  }

  void _zoomMap(double delta) {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    _mapController.move(camera.center, (camera.zoom + delta).clamp(6, 18));
  }

  void _clearMarker() {
    _areaLookupRevision++;
    setState(() {
      _point = null;
      _resolvingArea = false;
      _allowManualAreaFallback = false;
      _areaStatus = null;
    });
  }

  double _roundToPublishedCoordinate(double value) =>
      (value * 100).round() / 100;

  Future<void> _handleMapTap(LatLng point) async {
    final revision = ++_areaLookupRevision;
    final latitude = _roundToPublishedCoordinate(point.latitude);
    final longitude = _roundToPublishedCoordinate(point.longitude);
    setState(() {
      _point = point;
      _resolvingArea = true;
      _allowManualAreaFallback = false;
      _areaStatus = 'Identificando provincia y cantón…';
    });

    try {
      final match = await _areaResolver.resolve(
        latitude: latitude,
        longitude: longitude,
      );
      if (!mounted || revision != _areaLookupRevision) return;
      final province = _provinces
          .where((item) => item.code == match?.provinceCode)
          .firstOrNull;
      final canton = province?.cantons
          .where((item) => item.code == match?.cantonCode)
          .firstOrNull;
      setState(() {
        _resolvingArea = false;
        if (province == null || canton == null) {
          _selectedProvince = null;
          _selectedCanton = null;
          _allowManualAreaFallback = true;
          _areaStatus = 'No encontramos una coincidencia. Puedes completar la zona manualmente.';
        } else {
          _selectedProvince = province.name;
          _selectedCanton = canton.name;
          _areaStatus = 'Zona sugerida: ${canton.name}, ${province.name}';
        }
      });
    } catch (_) {
      if (!mounted || revision != _areaLookupRevision) return;
      setState(() {
        _selectedProvince = null;
        _selectedCanton = null;
        _resolvingArea = false;
        _allowManualAreaFallback = true;
        _areaStatus = 'No pudimos detectar la zona. Selecciona provincia y cantón manualmente.';
      });
    }
  }

  void _selectProvince(String? value) {
    _areaLookupRevision++;
    final keepPointForManualFallback =
        _allowManualAreaFallback && _point != null;
    setState(() {
      _resolvingArea = false;
      if (value != _selectedProvince && !keepPointForManualFallback) {
        _point = null;
      }
      _selectedProvince = value;
      _selectedCanton = null;
      _areaStatus = keepPointForManualFallback
          ? 'Punto conservado; confirma manualmente la provincia y el cantón.'
          : null;
    });
    if (!keepPointForManualFallback) _centerPreview(cantonSelected: false);
  }

  void _selectCanton(String? value) {
    _areaLookupRevision++;
    final keepPointForManualFallback =
        _allowManualAreaFallback && _point != null;
    setState(() {
      _resolvingArea = false;
      if (value != _selectedCanton && !keepPointForManualFallback) {
        _point = null;
      }
      _selectedCanton = value;
      _areaStatus = keepPointForManualFallback
          ? 'Punto conservado; confirma manualmente la provincia y el cantón.'
          : null;
    });
    if (!keepPointForManualFallback) _centerPreview(cantonSelected: true);
  }

  @override
  Widget build(BuildContext context) => ProfileSubpage(
    title: 'Mi zona publica',
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Elige una zona aproximada',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Selecciona provincia y cantón; luego toca el mapa para '
                        'ajustar tu zona aproximada. El punto se redondea y no '
                        'se toma tu ubicación privada.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _alias,
                        maxLength: 80,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Alias publico',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: ValueKey('province-$_selectedProvince'),
                        initialValue: _selectedProvince,
                        isExpanded: true,
                        menuMaxHeight: 224,
                        decoration: const InputDecoration(
                          labelText: 'Provincia',
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Selecciona una provincia'),
                        items: _provinces
                            .map(
                              (province) => DropdownMenuItem(
                                value: province.name,
                                child: Text(province.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          _selectProvince(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'canton-$_selectedProvince-$_selectedCanton',
                        ),
                        initialValue: _selectedCanton,
                        isExpanded: true,
                        menuMaxHeight: 224,
                        decoration: const InputDecoration(
                          labelText: 'Cantón / ciudad',
                          border: OutlineInputBorder(),
                        ),
                        hint: Text(
                          _selectedProvince == null
                              ? 'Primero selecciona una provincia'
                              : 'Selecciona un cantón o ciudad',
                        ),
                        items: (_selectedProvinceModel?.cantons ?? const [])
                            .map(
                              (canton) => DropdownMenuItem(
                                value: canton.name,
                                child: Text(canton.name),
                              ),
                            )
                            .toList(),
                        onChanged: _selectedProvince == null
                            ? null
                            : _selectCanton,
                      ),
                      if (_published &&
                          (_selectedProvince == null ||
                              _selectedCanton == null)) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Elige provincia y cantón para que tu zona aparezca en los nuevos filtros del mapa.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.warning),
                        ),
                      ],
                      if (_point != null) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _clearMarker,
                            icon: const Icon(Icons.location_off_outlined),
                            label: const Text('Quitar marcador'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              minimumSize: const Size(44, 44),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        height: (MediaQuery.sizeOf(context).height * 0.42)
                            .clamp(320, 480),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter:
                                        _point ?? _selectedAreaCenter,
                                    initialZoom: _selectedCanton == null
                                        ? 8.5
                                        : 11,
                                    minZoom: 6,
                                    maxZoom: 18,
                                    onMapReady: () => _mapReady = true,
                                    onTap: (_, point) => _handleMapTap(point),
                                  ),
                                  children: [
                                    if (widget.showTiles)
                                      TileLayer(
                                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        userAgentPackageName:
                                            'com.agroplus.app',
                                      ),
                                    if (_point != null)
                                      MarkerLayer(
                                        markers: [
                                          Marker(
                                            point: _point!,
                                            width: 48,
                                            height: 48,
                                            child: const Icon(
                                              Icons.place,
                                              color: AppColors.primary,
                                              size: 40,
                                            ),
                                          ),
                                        ],
                                      ),
                                    const RichAttributionWidget(
                                      attributions: [
                                        TextSourceAttribution(
                                          'OpenStreetMap contributors',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 48,
                                right: 12,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Material(
                                      color: Colors.white.withValues(
                                        alpha: 0.96,
                                      ),
                                      shape: const CircleBorder(),
                                      elevation: 2,
                                      child: IconButton(
                                        tooltip: 'Acercar mapa',
                                        onPressed: () => _zoomMap(1),
                                        icon: const Icon(Icons.add),
                                        color: AppColors.primary,
                                        constraints: const BoxConstraints(
                                          minWidth: 44,
                                          minHeight: 44,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Material(
                                      color: Colors.white.withValues(
                                        alpha: 0.96,
                                      ),
                                      shape: const CircleBorder(),
                                      elevation: 2,
                                      child: IconButton(
                                        tooltip: 'Alejar mapa',
                                        onPressed: () => _zoomMap(-1),
                                        icon: const Icon(Icons.remove),
                                        color: AppColors.primary,
                                        constraints: const BoxConstraints(
                                          minWidth: 44,
                                          minHeight: 44,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_areaStatus != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_resolvingArea)
                              const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Icon(
                                _selectedProvince == null
                                    ? Icons.info_outline
                                    : Icons.check_circle_outline,
                                size: 18,
                                color: _selectedProvince == null
                                    ? AppColors.warning
                                    : AppColors.primary,
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _areaStatus!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: _selectedProvince == null
                                          ? AppColors.warning
                                          : AppColors.primary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        _point == null
                            ? 'Aún no has elegido un punto aproximado.'
                            : 'Zona aproximada: ${(_point!.latitude * 100).round() / 100}, '
                                  '${(_point!.longitude * 100).round() / 100}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed:
                            _saving ||
                                _point == null ||
                                _selectedProvince == null ||
                                _selectedCanton == null ||
                                _alias.text.trim().isEmpty ||
                                _resolvingArea
                            ? null
                            : _save,
                        child: _saving
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : const Text('Publicar zona'),
                      ),
                      if (_published) ...[
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _saving ? null : _remove,
                          child: const Text('Retirar mi zona'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
  );
}
