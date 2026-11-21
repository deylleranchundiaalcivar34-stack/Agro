/// Formats chat timestamps for Ecuador continental (America/Guayaquil, UTC-5).
/// Stored instants remain unchanged; only the displayed wall time is shifted.
abstract final class ChatTimestampFormatter {
  static const Duration _ecuadorOffset = Duration(hours: -5);

  static DateTime _inEcuador(DateTime timestamp) =>
      timestamp.toUtc().add(_ecuadorOffset);

  static String time(DateTime timestamp) {
    final ecuadorTime = _inEcuador(timestamp);
    return '${ecuadorTime.hour.toString().padLeft(2, '0')}:'
        '${ecuadorTime.minute.toString().padLeft(2, '0')}';
  }

  /// Shows the time for today's conversations and the Ecuadorian date otherwise.
  static String listLabel(DateTime timestamp, {DateTime? now}) {
    final ecuadorTime = _inEcuador(timestamp);
    final ecuadorNow = _inEcuador(now ?? DateTime.now());
    final isToday = ecuadorTime.year == ecuadorNow.year &&
        ecuadorTime.month == ecuadorNow.month &&
        ecuadorTime.day == ecuadorNow.day;

    if (isToday) return time(timestamp);
    return '${ecuadorTime.day.toString().padLeft(2, '0')}/'
        '${ecuadorTime.month.toString().padLeft(2, '0')}';
  }
}
