import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/chat/data/repositories/chat_repository.dart';
import 'package:proyecto_agro/features/chat/presentation/widgets/contact_producer_button.dart';

class _OpenChats extends ChatRepository {
  _OpenChats() : super(supabaseService: SupabaseService());
  String? openedProduct;
  @override
  Future<String> openForProduct(String productId) async {
    openedProduct = productId;
    return 'chat-123';
  }
}

void main() {
  testWidgets('contact opens the persisted chat UUID for the product', (
    tester,
  ) async {
    final repository = _OpenChats();
    final router = GoRouter(
      initialLocation: '/product',
      routes: [
        GoRoute(
          path: '/product',
          builder: (_, _) => Scaffold(
            body: ContactProducerButton(
              productId: 'product-1',
              repository: repository,
            ),
          ),
        ),
        GoRoute(
          path: '/chat/:roomId',
          builder: (_, state) =>
              Scaffold(body: Text('Chat ${state.pathParameters['roomId']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Contactar al productor'));
    await tester.pumpAndSettle();
    expect(repository.openedProduct, 'product-1');
    expect(find.text('Chat chat-123'), findsOneWidget);
  });
}
