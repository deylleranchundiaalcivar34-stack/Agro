import 'package:flutter/foundation.dart';

import '../../../map/data/models/public_producer_location.dart';
import '../../../map/data/repositories/public_location_repository.dart';
import '../../data/models/weather_forecast.dart';
import '../../data/repositories/open_meteo_weather_repository.dart';

class WeatherViewModel extends ChangeNotifier {
  WeatherViewModel({
    required this.locationRepository,
    required this.weatherRepository,
  });

  final PublicLocationRepository locationRepository;
  final OpenMeteoWeatherRepository weatherRepository;

  PublicProducerLocation? _location;
  WeatherForecast? _forecast;
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  PublicProducerLocation? get location => _location;
  WeatherForecast? get forecast => _forecast;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;

  Future<void> load() => _load(forceRefresh: false);

  Future<void> refresh() => _load(forceRefresh: true);

  Future<void> _load({required bool forceRefresh}) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final nextLocation = await locationRepository.getMine();
      final locationChanged =
          _location == null ||
          nextLocation == null ||
          _location!.latitude != nextLocation.latitude ||
          _location!.longitude != nextLocation.longitude;
      if (locationChanged) _forecast = null;
      _location = nextLocation;
      if (_location == null) {
        _forecast = null;
        _errorMessage = null;
        return;
      }
      _forecast = await weatherRepository.fetchForecast(
        latitude: _location!.latitude,
        longitude: _location!.longitude,
        forceRefresh: forceRefresh,
      );
      _errorMessage = null;
    } on Object catch (error) {
      _errorMessage = 'No pudimos cargar el clima de tu zona.';
      if (_forecast != null) {
        _forecast = _forecast!.copyWith(isStale: true);
      }
      debugPrint('Weather load failed: $error');
    } finally {
      _hasLoaded = true;
      _isLoading = false;
      notifyListeners();
    }
  }
}
