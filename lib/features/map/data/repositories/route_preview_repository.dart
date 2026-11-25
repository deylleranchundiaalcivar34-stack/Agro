import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_service.dart';
import '../models/route_preview.dart';

class RoutePreviewRepository {
  RoutePreviewRepository({SupabaseService? supabaseService})
    : _service = supabaseService ?? SupabaseService();

  final SupabaseService _service;

  Future<RoutePreview> calculate({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    try {
      final response = await _service.client.functions.invoke(
        'calculate-route',
        body: {
          'origin': {'latitude': originLatitude, 'longitude': originLongitude},
          'destination': {
            'latitude': destinationLatitude,
            'longitude': destinationLongitude,
          },
        },
      );
      if (response.data is! Map) {
        throw const FormatException('La respuesta del servicio no es válida.');
      }
      return RoutePreview.fromMap(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on FunctionException catch (error) {
      final status = error.status;
      if (status == 401 || status == 403) {
        throw Exception('Inicia sesión para consultar una ruta.');
      }
      if (status == 429) {
        throw Exception(
          'Se alcanzó el límite de consultas. Intenta más tarde.',
        );
      }
      if (status == 503) {
        throw Exception('El servicio de rutas aún no está configurado.');
      }
      throw Exception('No se pudo calcular la ruta. Intenta de nuevo.');
    } on FormatException {
      rethrow;
    } catch (_) {
      throw Exception('No se pudo conectar con el servicio de rutas.');
    }
  }
}
