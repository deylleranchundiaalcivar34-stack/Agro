import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_forecast.dart';

class WeatherRepositoryException implements Exception {
  const WeatherRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OpenMeteoWeatherRepository {
  OpenMeteoWeatherRepository({http.Client? client, this.preferences})
    : _client = client ?? http.Client();

  static const _cacheDuration = Duration(minutes: 60);
  static const _timeout = Duration(seconds: 12);
  static const _cachePrefix = 'open_meteo_forecast_v1_';

  final http.Client _client;
  final SharedPreferences? preferences;

  Future<WeatherForecast> fetchForecast({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    _validateCoordinates(latitude, longitude);
    final cache = preferences ?? await SharedPreferences.getInstance();
    final cacheKey = _key(latitude, longitude);
    final cached = _readCache(cache.getString(cacheKey));
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().toUtc().difference(cached.fetchedAt) < _cacheDuration) {
      return cached.copyWith(isStale: false);
    }

    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': latitude.toStringAsFixed(2),
        'longitude': longitude.toStringAsFixed(2),
        'current':
            'temperature_2m,relative_humidity_2m,precipitation,weather_code',
        'daily': 'temperature_2m_min,temperature_2m_max,precipitation_probability_max',
        'forecast_days': '3',
        'timezone': 'auto',
      });
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        throw WeatherRepositoryException(
          'Open-Meteo respondió con estado ${response.statusCode}.',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Respuesta meteorológica inválida.');
      }
      final forecast = WeatherForecast.fromMap(decoded);
      await cache.setString(
        cacheKey,
        jsonEncode({
          'fetched_at': forecast.fetchedAt.toUtc().toIso8601String(),
          'payload': forecast.toMap(),
        }),
      );
      return forecast;
    } on WeatherRepositoryException {
      if (cached != null) return cached.copyWith(isStale: true);
      rethrow;
    } on Object catch (error) {
      if (cached != null) return cached.copyWith(isStale: true);
      throw WeatherRepositoryException(
        'No se pudo consultar el pronóstico: $error',
      );
    }
  }

  String _key(double latitude, double longitude) =>
      '$_cachePrefix${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}';

  WeatherForecast? _readCache(String? value) {
    if (value == null) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['payload'] is! Map<String, dynamic> ||
          decoded['fetched_at'] is! String) {
        return null;
      }
      return WeatherForecast.fromMap(decoded['payload'] as Map<String, dynamic>)
          .copyWith(
            fetchedAt: DateTime.parse(decoded['fetched_at'] as String).toUtc(),
          );
    } on Object {
      return null;
    }
  }

  void _validateCoordinates(double latitude, double longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const WeatherRepositoryException(
        'La ubicación guardada no tiene coordenadas válidas.',
      );
    }
  }
}
