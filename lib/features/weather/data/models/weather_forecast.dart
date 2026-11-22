class WeatherForecast {
  const WeatherForecast({
    required this.temperatureCelsius,
    required this.relativeHumidity,
    required this.weatherCode,
    required this.days,
    required this.timezone,
    required this.fetchedAt,
    this.isStale = false,
  });

  final double temperatureCelsius;
  final int relativeHumidity;
  final int weatherCode;
  final List<WeatherForecastDay> days;
  final String timezone;
  final DateTime fetchedAt;
  final bool isStale;

  factory WeatherForecast.fromMap(Map<String, dynamic> map) {
    final current = map['current'];
    final daily = map['daily'];
    if (current is! Map<String, dynamic> || daily is! Map<String, dynamic>) {
      throw const FormatException('Respuesta meteorológica incompleta.');
    }

    final dates = _list(daily, 'time');
    final minimums = _list(daily, 'temperature_2m_min');
    final maximums = _list(daily, 'temperature_2m_max');
    final rain = _list(daily, 'precipitation_probability_max');
    if (dates.isEmpty ||
        dates.length != minimums.length ||
        dates.length != maximums.length ||
        dates.length != rain.length) {
      throw const FormatException('Pronóstico diario inválido.');
    }

    final days = <WeatherForecastDay>[];
    for (var index = 0; index < dates.length; index++) {
      if (dates[index] is! String) {
        throw const FormatException('Fecha del pronóstico inválida.');
      }
      days.add(
        WeatherForecastDay(
          date: DateTime.parse(dates[index] as String),
          minimumCelsius: _number(minimums[index]),
          maximumCelsius: _number(maximums[index]),
          precipitationProbability: _integer(rain[index]).clamp(0, 100).toInt(),
        ),
      );
    }

    return WeatherForecast(
      temperatureCelsius: _number(current['temperature_2m']),
      relativeHumidity: _integer(current['relative_humidity_2m'])
          .clamp(0, 100)
          .toInt(),
      weatherCode: _integer(current['weather_code']),
      days: days,
      timezone: map['timezone'] as String? ?? 'UTC',
      fetchedAt: DateTime.now(),
    );
  }

  WeatherForecast copyWith({DateTime? fetchedAt, bool? isStale}) =>
      WeatherForecast(
        temperatureCelsius: temperatureCelsius,
        relativeHumidity: relativeHumidity,
        weatherCode: weatherCode,
        days: days,
        timezone: timezone,
        fetchedAt: fetchedAt ?? this.fetchedAt,
        isStale: isStale ?? this.isStale,
      );

  Map<String, dynamic> toMap() => {
    'current': {
      'temperature_2m': temperatureCelsius,
      'relative_humidity_2m': relativeHumidity,
      'weather_code': weatherCode,
    },
    'daily': {
      'time': days.map((day) => _dateKey(day.date)).toList(),
      'temperature_2m_min': days.map((day) => day.minimumCelsius).toList(),
      'temperature_2m_max': days.map((day) => day.maximumCelsius).toList(),
      'precipitation_probability_max': days
          .map((day) => day.precipitationProbability)
          .toList(),
    },
    'timezone': timezone,
  };

  static List<dynamic> _list(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is! List) throw FormatException('Falta el campo $key.');
    return value;
  }

  static double _number(dynamic value) {
    if (value is num && value.isFinite) return value.toDouble();
    throw const FormatException('Valor numérico inválido.');
  }

  static int _integer(dynamic value) {
    if (value is num && value.isFinite) return value.round();
    throw const FormatException('Valor entero inválido.');
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class WeatherForecastDay {
  const WeatherForecastDay({
    required this.date,
    required this.minimumCelsius,
    required this.maximumCelsius,
    required this.precipitationProbability,
  });

  final DateTime date;
  final double minimumCelsius;
  final double maximumCelsius;
  final int precipitationProbability;
}
