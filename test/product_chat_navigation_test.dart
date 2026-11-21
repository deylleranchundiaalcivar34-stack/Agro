import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/chat/data/models/contact_request.dart';
import 'package:proyecto_agro/features/chat/data/repositories/contact_requests_repository.dart';
import 'package:proyecto_agro/features/chat/presentation/widgets/contact_producer_button.dart';
import 'package:proyecto_agro/features/products/data/models/agricultural_product.dart';
import 'package:proyecto_agro/features/products/data/models/product_unit.dart';

class _FakeSupabaseService extends SupabaseService {
  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();
}

class _ContactRequests extends ContactRequestsRepository {
  _ContactRequests() : super(supabaseService: _FakeSupabaseService());

  ContactRequest? created;

  @override
  Future<ContactRequest> create({
    required String productId,
    required double quantity,
    required String initialMessage,
  }) async {
    created = ContactRequest(
      id: 'request-1',
      productId: productId,
      buyerId: 'buyer-1',
      productName: 'Mora',
      buyerName: 'Comprador',
      productUnit: 'kg',
      quantity: quantity,
      initialMessage: initialMessage,
      status: 'pendiente',
      createdAt: DateTime.utc(2026, 11, 17),
    );
    return created!;
  }
}

void main() {
  testWidgets('buyer sends an editable quantity inquiry to the producer', (
    tester,
  ) async {
    final repository = _ContactRequests();
    const product = AgriculturalProduct(
      id: 'product-1',
      producerId: 'producer-1',
      categoryId: 1,
      phaseId: 1,
      name: 'Mora',
      availableQuantity: 20,
      unitPrice: 2,
      isPublished: true,
      categoryName: 'Frutas',
      phaseName: 'Venta directa',
      unit: ProductUnit.kg,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContactProducerButton(product: product, repository: repository),
        ),
      ),
    );

    await tester.tap(find.text('Consultar al productor'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Cuéntale qué cantidad te interesa. Podrás revisar y editar el mensaje antes de enviarlo.',
      ),
      findsOneWidget,
    );
    expect(find.text('Enviar consulta'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '5');
    await tester.pump();
    await tester.tap(find.text('Enviar consulta'));
    await tester.pumpAndSettle();

    expect(repository.created?.productId, 'product-1');
    expect(repository.created?.quantity, 5);
    expect(
      repository.created?.initialMessage,
      'Hola, me interesa adquirir 5 kg de Mora. '
      '¿Podrías indicarme el precio y cómo coordinamos la entrega?',
    );
    expect(
      find.text(
        'Consulta enviada. Te avisaremos cuando el productor responda.',
      ),
      findsOneWidget,
    );
  });
}
