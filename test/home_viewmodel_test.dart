import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/home/data/repositories/home_summary_repository.dart';
import 'package:proyecto_agro/features/home/presentation/viewmodels/home_viewmodel.dart';

void main() {
  test('el inicio no muestra cifras de ejemplo antes de recibir datos', () {
    final viewModel = HomeViewModel(
      supabaseService: SupabaseService(),
      summaryLoader: () async =>
          const HomeSummary(availableLots: 4, recentLots: 1, categories: 2),
    );
    addTearDown(viewModel.dispose);

    expect(viewModel.metrics, hasLength(3));
    expect(viewModel.metrics.every((metric) => metric.value == '—'), isTrue);
  });

  test('carga conteos reales sin alterar las tres tarjetas', () async {
    final viewModel = HomeViewModel(
      supabaseService: SupabaseService(),
      summaryLoader: () async =>
          const HomeSummary(availableLots: 4, recentLots: 1, categories: 2),
    );
    addTearDown(viewModel.dispose);

    await viewModel.initialLoad;

    expect(viewModel.metrics.map((metric) => metric.value).toList(), [
      '4',
      '1',
      '2',
    ]);
    expect(viewModel.isLoading, isFalse);
  });

  test('si falla la consulta, muestra un estado para reintentar', () async {
    final viewModel = HomeViewModel(
      supabaseService: SupabaseService(),
      summaryLoader: () async => throw Exception('Sin red'),
    );
    addTearDown(viewModel.dispose);

    await viewModel.initialLoad;

    expect(viewModel.summaryLabel, 'Sin conexion');
    expect(viewModel.metrics.every((metric) => metric.value == '—'), isTrue);
    expect(
      viewModel.metrics.every(
        (metric) => metric.change == 'Desliza para reintentar',
      ),
      isTrue,
    );
  });
}
