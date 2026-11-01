import 'package:flutter/foundation.dart';

import '../../../../core/network/supabase_service.dart';
import '../../data/repositories/home_summary_repository.dart';

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
  final Future<HomeSummary> Function() _summaryLoader;
  late final Future<void> initialLoad;

  HomeViewModel({
    required this.supabaseService,
    Future<HomeSummary> Function()? summaryLoader,
  }) : _summaryLoader =
           summaryLoader ??
           HomeSummaryRepository(supabaseService: supabaseService).load {
    _loadInitialData();
    initialLoad = refresh();
  }

  bool _isLoading = false;
  bool _disposed = false;
  String? _errorMessage;
  Future<void>? _pendingRefresh;
  List<HomeMetricItem> _metrics = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get summaryLabel => _isLoading
      ? 'Actualizando'
      : _errorMessage != null
      ? 'Sin conexión'
      : 'Datos del catálogo';
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
  Future<void> refresh() {
    if (_pendingRefresh != null) return _pendingRefresh!;
    late final Future<void> request;
    request = _refreshSummary().whenComplete(() {
      _pendingRefresh = null;
    });
    _pendingRefresh = request;
    return request;
  }

  Future<void> _refreshSummary() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final summary = await _summaryLoader();
      if (_disposed) return;
      _metrics = [
        HomeMetricItem(
          label: 'Lotes disponibles',
          value: '${summary.availableLots}',
          change: 'En el catálogo',
          isPositive: true,
        ),
        HomeMetricItem(
          label: 'Nuevos en 7 días',
          value: '${summary.recentLots}',
          change: 'Publicados recientemente',
          isPositive: true,
        ),
        HomeMetricItem(
          label: 'Categorías agrícolas',
          value: '${summary.categories}',
          change: 'Para explorar',
          isPositive: true,
        ),
      ];
    } catch (_) {
      if (_disposed) return;
      _errorMessage = 'No se pudo actualizar el resumen.';
      _loadInitialData(message: 'Desliza para reintentar');
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _loadInitialData({String message = 'Consultando catálogo'}) {
    _metrics = [
      HomeMetricItem(
        label: 'Lotes disponibles',
        value: '—',
        change: message,
        isPositive: true,
      ),
      HomeMetricItem(
        label: 'Nuevos en 7 días',
        value: '—',
        change: message,
        isPositive: true,
      ),
      HomeMetricItem(
        label: 'Categorías agrícolas',
        value: '—',
        change: message,
        isPositive: true,
      ),
    ];
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
