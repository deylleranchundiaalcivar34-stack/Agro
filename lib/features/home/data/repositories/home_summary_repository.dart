import '../../../../../core/network/supabase_service.dart';

class HomeSummary {
  const HomeSummary({
    required this.availableLots,
    required this.recentLots,
    required this.categories,
  });

  final int availableLots;
  final int recentLots;
  final int categories;
}

class HomeSummaryRepository {
  const HomeSummaryRepository({required this.supabaseService});

  final SupabaseService supabaseService;

  Future<HomeSummary> load() async {
    final client = supabaseService.client;
    final sevenDaysAgo = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 7))
        .toIso8601String();

    final counts = await Future.wait<int>([
      client.from('productos').count().eq('estado_publicacion', true),
      client
          .from('productos')
          .count()
          .eq('estado_publicacion', true)
          .gte('created_at', sevenDaysAgo),
      client.from('categorias_agricolas').count(),
    ]);

    return HomeSummary(
      availableLots: counts[0],
      recentLots: counts[1],
      categories: counts[2],
    );
  }
}
