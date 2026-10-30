import 'package:flutter/foundation.dart';
import '../../../../core/network/supabase_service.dart';

/// Modelo ligero para métricas o accesos rápidos de la pantalla de inicio.
class HomeMetricItem {
  final String label;
  final String value;
  final String change;
  final bool isPositive;

  const HomeMetricItem({
    required this.label,
    required this.value,
    required this.change,
    required this.isPositive,
  });
}

/// ViewModel para la pantalla de inicio (HomeView) bajo arquitectura MVVM.
class HomeViewModel extends ChangeNotifier {
  final SupabaseService supabaseService;

  HomeViewModel({required this.supabaseService}) {
    _loadInitialData();
  }

  bool _isLoading = false;
  List<HomeMetricItem> _metrics = [];

  bool get isLoading => _isLoading;
  List<HomeMetricItem> get metrics => _metrics;

  /// Obtiene el nombre del usuario actual para el saludo dinámico.
  String get userName {
    final user = supabaseService.currentUser;
    final metadataName = user?.userMetadata?['full_name'] as String?;
    if (metadataName != null && metadataName.trim().isNotEmpty) {
      return metadataName.trim();
    }
    return 'Productor';
  }

  /// Retorna la primera letra del usuario para el avatar circular.
  String get userInitial {
    final name = userName;
    return name.isNotEmpty ? name[0].toUpperCase() : 'A';
  }

  /// Saludo dinámico según la hora del día.
  String get dynamicGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return '¡Buenos días!';
    } else if (hour < 18) {
      return '¡Buenas tardes!';
    } else {
      return '¡Buenas noches!';
    }
  }

  /// Carga inicial o refresco de métricas agrícolas.
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    // Simulación de carga fluida para actualización de datos en tiempo real
    await Future.delayed(const Duration(milliseconds: 300));

    _metrics = const [
      HomeMetricItem(
        label: 'Lotes en Preventa',
        value: '14 Lotes',
        change: '+3 esta semana',
        isPositive: true,
      ),
      HomeMetricItem(
        label: 'Compradores Activos',
        value: '28 Redes',
        change: 'En tu región',
        isPositive: true,
      ),
      HomeMetricItem(
        label: 'Precio Café Prom.',
        value: '\$18,400',
        change: '+4.2% mercado',
        isPositive: true,
      ),
    ];

    _isLoading = false;
    notifyListeners();
  }

  void _loadInitialData() {
    _metrics = const [
      HomeMetricItem(
        label: 'Lotes en Preventa',
        value: '14 Lotes',
        change: '+3 esta semana',
        isPositive: true,
      ),
      HomeMetricItem(
        label: 'Compradores Activos',
        value: '28 Redes',
        change: 'En tu región',
        isPositive: true,
      ),
      HomeMetricItem(
        label: 'Precio Café Prom.',
        value: '\$18,400',
        change: '+4.2% mercado',
        isPositive: true,
      ),
    ];
  }
}
