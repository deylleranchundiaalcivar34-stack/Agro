class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.productId,
    required this.buyerId,
    required this.productName,
    this.producerId,
    this.startedAt,
  });
  final String id;
  final String productId;
  final String buyerId;
  final String productName;
  final String? producerId;
  final DateTime? startedAt;

  factory ChatConversation.fromMap(Map<String, dynamic> row) {
    final product = row['producto'] as Map<String, dynamic>?;
    return ChatConversation(
      id: row['id_chat'] as String,
      productId: row['id_producto'] as String,
      buyerId: row['id_comprador'] as String,
      productName:
          product?['nombre_producto'] as String? ?? 'Producto no disponible',
      producerId: product?['id_productor'] as String?,
      startedAt: row['fecha_inicio'] == null
          ? null
          : DateTime.tryParse(row['fecha_inicio'] as String),
    );
  }
}
