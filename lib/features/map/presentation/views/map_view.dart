import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../chat/presentation/views/chat_room_view.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  LatLng _currentPosition = const LatLng(-1.6635, -78.6546);
  final MapController _mapController = MapController();
  double _geofenceRadiusKm = 3.0;

  final _producers = [
    {
      'roomId': 'room_1',
      'name': 'Finca San José (Productor 1)',
      'products': 'Tomate Riñón, Pimiento y Lechuga',
      'price': 'Caja desde \$15.00',
      'point': const LatLng(-1.6750, -78.6400),
    },
    {
      'roomId': 'room_2',
      'name': 'Huertos del Chimborazo (Productor 2)',
      'products': 'Papa Superchola, Habas y Melloco',
      'price': 'Quintal desde \$18.00',
      'point': const LatLng(-1.6580, -78.6250),
    },
    {
      'roomId': 'room_3',
      'name': 'AgroFrutales Guano (Productor 3)',
      'products': 'Mora de Castilla y Frutilla fresca',
      'price': 'Gaveta desde \$12.00',
      'point': const LatLng(-1.6800, -78.6500),
    },
  ];

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    if (!mounted) return;

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    _mapController.move(_currentPosition, 13.5);
  }

  double _calculateDistanceKm(LatLng target) {
    final meters = Geolocator.distanceBetween(
      _currentPosition.latitude,
      _currentPosition.longitude,
      target.latitude,
      target.longitude,
    );
    return meters / 1000.0;
  }

  void _showProducerDetails(Map producer) {
    final targetPoint = producer['point'] as LatLng;
    final distanceKm = _calculateDistanceKm(targetPoint);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.green,
                    child: Icon(Icons.agriculture, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          producer['name'].toString(),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'A ${distanceKm.toStringAsFixed(2)} km de tu ubicación',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                'Productos disponibles: ${producer['products']}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                'Referencia: ${producer['price']}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.chat),
                  label: const Text(
                    'Contactar al Productor',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (context) => ChatRoomView(
                          roomId: producer['roomId'].toString(),
                          producerName: producer['name'].toString(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mapa de Productores Agro+',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            tooltip: 'Centrar en mi ubicación',
            icon: const Icon(Icons.my_location, color: Colors.white),
            onPressed: _determinePosition,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition,
              initialZoom: 13.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.agroplus.app',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _currentPosition,
                    radius: _geofenceRadiusKm * 1000,
                    useRadiusInMeter: true,
                    color: Colors.green.withValues(alpha: 0.15),
                    borderColor: Colors.green.shade700,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  ..._producers.map((producer) {
                    return Marker(
                      point: producer['point'] as LatLng,
                      width: 55.0,
                      height: 55.0,
                      child: GestureDetector(
                        onTap: () => _showProducerDetails(producer),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                            border: Border.all(color: Colors.green, width: 2),
                          ),
                          child: const Icon(
                            Icons.agriculture,
                            color: Colors.green,
                            size: 30.0,
                          ),
                        ),
                      ),
                    );
                  }),
                  Marker(
                    point: _currentPosition,
                    width: 50.0,
                    height: 50.0,
                    child: const Icon(
                      Icons.person_pin_circle,
                      color: Colors.blue,
                      size: 42.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.radar, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Geocerca: ${_geofenceRadiusKm.toStringAsFixed(1)} km',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Slider(
                        value: _geofenceRadiusKm,
                        min: 1.0,
                        max: 10.0,
                        divisions: 18,
                        activeColor: Colors.green,
                        onChanged: (value) {
                          setState(() {
                            _geofenceRadiusKm = value;
                          });
                        },
                      ),
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