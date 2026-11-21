import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_agro/features/chat/data/models/contact_request.dart';

void main() {
  group('ContactRequest', () {
    test('parses the request state and the linked product and buyer', () {
      final request = ContactRequest.fromMap({
        'id_solicitud': 'request-1',
        'id_producto': 'product-1',
        'id_comprador': 'buyer-1',
        'cantidad_solicitada': 5,
        'mensaje_inicial': '¿Cuál es el precio?',
        'estado_solicitud': 'pendiente',
        'id_chat': null,
        'created_at': '2026-11-17T17:00:00Z',
        'producto': {'nombre_producto': 'Mora', 'unidad_medida': 'kg'},
        'comprador': {'nombre_publico': 'Ana Paz'},
      });

      expect(request.id, 'request-1');
      expect(request.productName, 'Mora');
      expect(request.productUnit, 'kg');
      expect(request.buyerName, 'Ana Paz');
      expect(request.quantity, 5);
      expect(request.isPending, isTrue);
      expect(request.chatId, isNull);
    });

    test('builds an editable inquiry with the product unit', () {
      expect(
        ContactRequest.buildInitialMessage(
          productName: 'Mora',
          quantity: 5,
          unit: 'kg',
        ),
        'Hola, me interesa adquirir 5 kg de Mora. '
        '¿Podrías indicarme el precio y cómo coordinamos la entrega?',
      );
    });
  });
}
