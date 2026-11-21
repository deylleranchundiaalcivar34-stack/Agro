class ProfileNotification {
  const ProfileNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    this.referenceType,
    this.referenceId,
  });

  final String id;
  final String title;
  final String message;
  final bool isRead;
  final String? referenceType;
  final String? referenceId;

  factory ProfileNotification.fromMap(Map<String, dynamic> map) =>
      ProfileNotification(
        id: map['id_notificacion'] as String? ?? '',
        title: map['titulo'] as String? ?? 'Notificacion',
        message: map['mensaje_cuerpo'] as String? ?? '',
        isRead: map['leida'] as bool? ?? false,
        referenceType: map['referencia_tipo'] as String?,
        referenceId: map['referencia_id'] as String?,
      );
}
