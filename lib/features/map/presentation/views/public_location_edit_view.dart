import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_service.dart';
import '../../data/repositories/public_location_repository.dart';

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
  final _alias = TextEditingController();
  final _place = TextEditingController();
  LatLng? _point;
  bool _loading = true;
  bool _saving = false;
  bool _published = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final mine = await _repository.getMine();
      if (!mounted) return;
      if (mine != null) {
        _alias.text = mine.alias;
        _place.text = mine.placeName;
        _point = LatLng(mine.latitude, mine.longitude);
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
      final saved = await _repository.saveMine(
        alias: _alias.text,
        placeName: _place.text,
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
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Mi zona publica')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Elige una zona aproximada',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Toca el mapa para elegir una zona que quieras compartir. '
                  'El punto se redondea y no se toma tu ubicacion privada.',
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
                TextField(
                  controller: _place,
                  maxLength: 120,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Lugar o sector',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 280,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: _point ?? const LatLng(-1.67, -78.65),
                        initialZoom: 11,
                        onTap: (_, point) => setState(() => _point = point),
                      ),
                      children: [
                        if (widget.showTiles)
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.agroplus.app',
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
                            TextSourceAttribution('OpenStreetMap contributors'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _point == null
                      ? 'Aun no has elegido un punto.'
                      : 'Zona aproximada: ${(_point!.latitude * 100).round() / 100}, '
                            '${(_point!.longitude * 100).round() / 100}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed:
                      _saving ||
                          _point == null ||
                          _alias.text.trim().isEmpty ||
                          _place.text.trim().isEmpty
                      ? null
                      : _save,
                  child: _saving
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Text('Publicar zona'),
                ),
                if (_published) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _saving ? null : _remove,
                    child: const Text('Retirar mi zona'),
                  ),
                ],
              ],
            ),
          ),
  );
}
