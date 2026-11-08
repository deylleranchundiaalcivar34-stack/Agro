class ProfileNotification {
  const ProfileNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
  });

  final String id;
  final String title;
  final String message;
  final bool isRead;

  factory ProfileNotification.fromMap(Map<String, dynamic> map) =>
      ProfileNotification(
        id: map['id_notificacion'] as String? ?? '',
        title: map['titulo'] as String? ?? 'Notificacion',
        message: map['mensaje_cuerpo'] as String? ?? '',
        isRead: map['leida'] as bool? ?? false,
      );
}
