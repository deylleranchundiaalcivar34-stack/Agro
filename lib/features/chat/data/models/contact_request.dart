class ContactRequest {
  const ContactRequest({
    required this.id,
    required this.productId,
    required this.buyerId,
    required this.productName,
    required this.buyerName,
    required this.productUnit,
    required this.quantity,
    required this.initialMessage,
    required this.status,
    required this.createdAt,
    this.chatId,
  });

  final String id;
  final String productId;
  final String buyerId;
  final String productName;
  final String buyerName;
  final String? productUnit;
  final double quantity;
  final String initialMessage;
  final String status;
  final DateTime? createdAt;
  final String? chatId;

  bool get isPending => status == 'pendiente';
  bool get isAccepted => status == 'aceptada';
  bool get isRejected => status == 'rechazada';

  factory ContactRequest.fromMap(Map<String, dynamic> map) {
    final product = map['producto'] as Map<String, dynamic>? ?? const {};
    final buyer = map['comprador'] as Map<String, dynamic>? ?? const {};
    final name = (buyer['nombre_publico'] as String? ?? '').trim();

    return ContactRequest(
      id: map['id_solicitud'] as String? ?? '',
      productId: map['id_producto'] as String? ?? '',
      buyerId: map['id_comprador'] as String? ?? '',
      productName: product['nombre_producto'] as String? ?? 'Producto',
      buyerName: name.isEmpty ? 'Comprador de Agro+' : name,
      productUnit: product['unidad_medida'] as String?,
      quantity: (map['cantidad_solicitada'] as num?)?.toDouble() ?? 0,
      initialMessage: map['mensaje_inicial'] as String? ?? '',
      status: map['estado_solicitud'] as String? ?? 'pendiente',
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'] as String),
      chatId: map['id_chat'] as String?,
    );
  }

  static String buildInitialMessage({
    required String productName,
    required double quantity,
    String? unit,
  }) {
    final formattedQuantity = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toString();
    final quantityWithUnit = [
      formattedQuantity,
      unit?.trim(),
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');

    return 'Hola, me interesa adquirir $quantityWithUnit de $productName. '
        '¿Podrías indicarme el precio y cómo coordinamos la entrega?';
  }
}
