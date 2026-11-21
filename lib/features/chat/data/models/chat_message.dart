class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.sentAt,
    this.attachmentPath,
    this.attachmentUrl,
    this.contentType = 'texto',
  });
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final DateTime sentAt;
  final String contentType;
  final String? attachmentPath;
  final String? attachmentUrl;

  bool get isImage => contentType == 'imagen' && attachmentPath != null;

  factory ChatMessage.fromMap(
    Map<String, dynamic> row, {
    String? attachmentUrl,
  }) => ChatMessage(
    id: row['id_mensaje'] as String,
    chatId: row['id_chat'] as String,
    senderId: row['id_remitente'] as String,
    content: row['contenido'] as String,
    sentAt: DateTime.parse(row['fecha_hora_envio'] as String),
    contentType: row['tipo_contenido'] as String? ?? 'texto',
    attachmentPath: row['adjunto_ruta'] as String?,
    attachmentUrl: attachmentUrl,
  );
}
