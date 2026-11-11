class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.sentAt,
  });
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final DateTime sentAt;

  factory ChatMessage.fromMap(Map<String, dynamic> row) => ChatMessage(
    id: row['id_mensaje'] as String,
    chatId: row['id_chat'] as String,
    senderId: row['id_remitente'] as String,
    content: row['contenido'] as String,
    sentAt: DateTime.parse(row['fecha_hora_envio'] as String),
  );
}
