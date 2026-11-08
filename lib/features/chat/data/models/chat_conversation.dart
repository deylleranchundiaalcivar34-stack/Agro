import '../../../profile/data/models/public_contact_profile.dart';

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.productId,
    String? interestedUserId,
    String? buyerId,
    required this.productName,
    this.producerId,
    this.startedAt,
    this.producerAlias,
    this.participantId,
    this.participantName,
    this.participantAvatarUrl,
    this.participantWhatsAppPhone,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.lastMessageSenderId,
  }) : assert(interestedUserId != null || buyerId != null),
       interestedUserId = interestedUserId ?? buyerId ?? '';
  final String id;
  final String productId;
  final String interestedUserId;
  @Deprecated('Use interestedUserId; the database column remains id_comprador.')
  String get buyerId => interestedUserId;
  final String productName;
  final String? producerId;
  final DateTime? startedAt;
  final String? producerAlias;
  final String? participantId;
  final String? participantName;
  final String? participantAvatarUrl;
  final String? participantWhatsAppPhone;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;

  ChatConversation withProducerAlias(String? alias) => ChatConversation(
    id: id,
    productId: productId,
    interestedUserId: interestedUserId,
    productName: productName,
    producerId: producerId,
    startedAt: startedAt,
    producerAlias: alias ?? producerAlias,
    participantId: participantId,
    participantName: participantName,
    participantAvatarUrl: participantAvatarUrl,
    participantWhatsAppPhone: participantWhatsAppPhone,
    lastMessagePreview: lastMessagePreview,
    lastMessageAt: lastMessageAt,
    lastMessageSenderId: lastMessageSenderId,
  );

  String otherParticipantIdFor(String currentUserId) =>
      currentUserId == interestedUserId ? producerId ?? '' : interestedUserId;

  ChatConversation withParticipant({
    required String participantId,
    PublicContactProfile? profile,
    String? fallbackName,
  }) => ChatConversation(
    id: id,
    productId: productId,
    interestedUserId: interestedUserId,
    productName: productName,
    producerId: producerId,
    startedAt: startedAt,
    producerAlias: producerAlias,
    participantId: participantId,
    participantName: profile?.displayName.trim().isNotEmpty == true
        ? profile!.displayName
        : fallbackName,
    participantAvatarUrl: profile?.avatarUrl,
    participantWhatsAppPhone: profile?.whatsappVisible == true
        ? profile?.whatsappPhone
        : null,
    lastMessagePreview: lastMessagePreview,
    lastMessageAt: lastMessageAt,
    lastMessageSenderId: lastMessageSenderId,
  );

  factory ChatConversation.fromMap(Map<String, dynamic> row) {
    final product = row['producto'] as Map<String, dynamic>?;
    final messages = row['mensajes'];
    final latestMessage = messages is List
        ? messages.whereType<Map<String, dynamic>>().firstOrNull
        : null;
    return ChatConversation(
      id: row['id_chat'] as String,
      productId: row['id_producto'] as String,
      interestedUserId: row['id_comprador'] as String,
      productName:
          product?['nombre_producto'] as String? ?? 'Producto no disponible',
      producerId: product?['id_productor'] as String?,
      startedAt: row['fecha_inicio'] == null
          ? null
          : DateTime.tryParse(row['fecha_inicio'] as String),
      lastMessagePreview: latestMessage?['contenido'] as String?,
      lastMessageAt: latestMessage?['fecha_hora_envio'] == null
          ? null
          : DateTime.tryParse(latestMessage!['fecha_hora_envio'] as String),
      lastMessageSenderId: latestMessage?['id_remitente'] as String?,
    );
  }
}
