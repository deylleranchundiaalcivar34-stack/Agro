import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../map/data/repositories/public_location_repository.dart';
import '../../data/models/weather_forecast.dart';
import '../../data/repositories/open_meteo_weather_repository.dart';
import '../viewmodels/weather_viewmodel.dart';

class WeatherSummaryCard extends StatelessWidget {
  const WeatherSummaryCard({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => WeatherViewModel(
      locationRepository: PublicLocationRepository(
        supabaseService: SupabaseService(),
      ),
      weatherRepository: OpenMeteoWeatherRepository(),
    )..load(),
    child: const _WeatherSummaryCardContent(),
  );
}

class _WeatherSummaryCardContent extends StatelessWidget {
  const _WeatherSummaryCardContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WeatherViewModel>();
    final theme = Theme.of(context);
    final forecast = viewModel.forecast;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_cloudy_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Clima aproximado de tu zona',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (viewModel.hasLoaded && viewModel.location != null)
                IconButton(
                  tooltip: 'Actualizar pronóstico',
                  onPressed: viewModel.isLoading ? null : viewModel.refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (viewModel.isLoading && forecast == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            )
          else if (!viewModel.hasLoaded)
            const SizedBox(height: 4)
          else if (viewModel.location == null && viewModel.errorMessage != null)
            _Unavailable(
              message: viewModel.errorMessage,
              onRetry: viewModel.refresh,
            )
          else if (viewModel.location == null)
            _LocationRequired(onTap: () => _openPublicLocation(context))
          else if (forecast != null)
            _ForecastContent(
              forecast: forecast,
              placeName: viewModel.location!.placeName,
              onRetry: viewModel.refresh,
            )
          else
            _Unavailable(
              message: viewModel.errorMessage,
              onRetry: viewModel.refresh,
            ),
          if (forecast != null) ...[
            const SizedBox(height: 10),
            Text(
              'Pronóstico de Open-Meteo · Actualizado ${_timeLabel(forecast.fetchedAt)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://open-meteo.com/'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(
                  'Datos meteorológicos por Open-Meteo',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primaryDark,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static void _openPublicLocation(BuildContext context) =>
      context.go(AppRoutes.publicLocation);

  static String _timeLabel(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _LocationRequired extends StatelessWidget {
  const _LocationRequired({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Registra tu zona aproximada para consultar su pronóstico.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(onPressed: onTap, child: const Text('Registrar zona')),
      ],
    ),
  );
}

class _ForecastContent extends StatelessWidget {
  const _ForecastContent({
    required this.forecast,
    required this.placeName,
    required this.onRetry,
  });

  final WeatherForecast forecast;
  final String placeName;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final today = forecast.days.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          placeName,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${forecast.temperatureCelsius.round()}°',
              style: theme.textTheme.displaySmall?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _weatherDescription(forecast.weatherCode),
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    'Humedad ${forecast.relativeHumidity}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.water_drop_outlined,
              color: AppColors.info,
              size: 19,
            ),
            const SizedBox(width: 4),
            Text(
              '${today.precipitationProbability}% lluvia',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 68 * textScale,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: forecast.days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final day = forecast.days[index];
              return Container(
                width: 92 * textScale,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _dayLabel(day.date, index),
                      style: theme.textTheme.labelSmall,
                    ),
                    Text(
                      '${day.minimumCelsius.round()}° / ${day.maximumCelsius.round()}°',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${day.precipitationProbability}% lluvia',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (forecast.isStale)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Mostrando el último pronóstico guardado.',
                    style: TextStyle(color: AppColors.warning),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('Reintentar')),
              ],
            ),
          ),
      ],
    );
  }

  static String _dayLabel(DateTime date, int index) {
    if (index == 0) return 'Hoy';
    if (index == 1) return 'Mañana';
    const names = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    return names[date.weekday - 1];
  }

  static String _weatherDescription(int code) => switch (code) {
    0 => 'Despejado',
    1 || 2 => 'Parcialmente nublado',
    3 => 'Nublado',
    45 || 48 => 'Neblina',
    51 || 53 || 55 || 56 || 57 => 'Llovizna',
    61 || 63 || 65 || 66 || 67 => 'Lluvia',
    71 || 73 || 75 || 77 => 'Nieve',
    80 || 81 || 82 => 'Chubascos',
    85 || 86 => 'Nieve',
    95 || 96 || 99 => 'Tormenta',
    _ => 'Condición variable',
  };
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          message ?? 'No pudimos cargar el pronóstico ahora.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
      TextButton(onPressed: onRetry, child: const Text('Reintentar')),
    ],
  );
}
