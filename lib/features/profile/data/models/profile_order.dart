class ProfileOrderLine {
  const ProfileOrderLine({required this.name, required this.quantity});

  final String name;
  final num quantity;

  factory ProfileOrderLine.fromMap(Map<String, dynamic> map) {
    final product = map['productos'];
    final productMap = product is Map<String, dynamic> ? product : const {};
    return ProfileOrderLine(
      name: productMap['nombre_producto'] as String? ?? 'Producto',
      quantity: map['cantidad_solicitada'] as num? ?? 0,
    );
  }
}

class ProfileOrder {
  const ProfileOrder({
    required this.id,
    required this.buyerId,
    required this.producerId,
    required this.total,
    required this.status,
    required this.lines,
  });

  final String id;
  final String? buyerId;
  final String? producerId;
  final num total;
  final String status;
  final List<ProfileOrderLine> lines;

  factory ProfileOrder.fromMap(Map<String, dynamic> map) {
    final rawLines = map['detalles_pedido'];
    final lines = rawLines is List
        ? rawLines
              .whereType<Map<String, dynamic>>()
              .map(ProfileOrderLine.fromMap)
              .toList(growable: false)
        : const <ProfileOrderLine>[];
    return ProfileOrder(
      id: map['id_pedido'] as String? ?? '',
      buyerId: map['id_comprador'] as String?,
      producerId: map['id_productor'] as String?,
      total: map['monto_total'] as num? ?? 0,
      status: map['estado_pedido'] as String? ?? 'Pendiente',
      lines: lines,
    );
  }
}
