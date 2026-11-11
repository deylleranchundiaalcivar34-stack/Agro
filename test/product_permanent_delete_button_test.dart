// Pruebas de la confirmación; el callback simulado no ejecuta DELETE ni accede a datos reales.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/auth/data/repositories/profile_repository.dart';
import 'package:proyecto_agro/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:proyecto_agro/features/products/data/models/agricultural_product.dart';
import 'package:proyecto_agro/features/products/presentation/widgets/product_permanent_delete_button.dart';

class PermanentButtonSupabase extends SupabaseService {
  PermanentButtonSupabase(this.testClient);
  final SupabaseClient testClient;
  @override
  SupabaseClient get client => testClient;
  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();
  @override
  User? get currentUser => User.fromJson({
    'id': 'owner',
    'aud': 'authenticated',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'created_at': '2026-01-01T00:00:00Z',
  });
}

void main() {
  late SupabaseClient client;
  late AuthViewModel auth;
  late String role;
  late Map<String, dynamic> row;
  setUp(() {
    role = 'producer';
    row = {
      'id_producto': 'p1',
      'id_productor': 'owner',
      'id_categoria': 1,
      'id_fase_actual': 1,
      'nombre_producto': 'Tomates',
      'cantidad_disponible': 5,
      'precio_unitario': 2,
      'unidad_medida': 'kg',
      'estado_publicacion': true,
    };
    client = SupabaseClient(
      'https://example.supabase.co',
      'fake-key',
      httpClient: MockClient(
        (r) async => http.Response(
          jsonEncode({
            'id_usuario': 'owner',
            'tipos_usuario': {'nombre_tipo': role},
          }),
          200,
          request: r,
        ),
      ),
    );
  });
  tearDown(() async {
    auth.dispose();
    await client.dispose();
  });

  Future<void> open(
    WidgetTester tester,
    Future<bool> Function(String) callback, {
    VoidCallback? onDeleted,
  }) async {
    final service = PermanentButtonSupabase(client);
    auth = AuthViewModel(
      supabaseService: service,
      profileRepository: ProfileRepository(supabaseService: service),
    );
    await auth.initialLoad;
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: auth,
        child: MaterialApp(
          home: Scaffold(
            body: ProductPermanentDeleteButton(
              product: AgriculturalProduct.fromMap(row),
              onConfirmed: callback,
              onDeleted: onDeleted ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('cancelar cierra el diálogo sin ejecutar el callback', (
    tester,
  ) async {
    var calls = 0;
    await open(tester, (_) async {
      calls++;
      return true;
    });
    await tester.tap(find.text('Eliminar definitivamente'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar producto?'), findsOneWidget);
    expect(
      find.text(
        '¿Está seguro de que desea eliminar este producto definitivamente?',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Eliminar'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Producto eliminado definitivamente'), findsNothing);
  });

  for (final visible in [true, false]) {
    testWidgets(
      'confirmar conserva el nombre y bloquea duplicados, visible=$visible',
      (tester) async {
        row['estado_publicacion'] = visible;
        final wait = Completer<bool>();
        var calls = 0;
        var removed = false;
        await open(tester, (name) {
          expect(name, 'Tomates');
          calls++;
          return wait.future;
        }, onDeleted: () => removed = true);
        await tester.tap(find.text('Eliminar definitivamente'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(calls, 1);
        expect(removed, isFalse);
        expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull,
        );
        wait.complete(true);
        await tester.pumpAndSettle();
        expect(removed, isTrue);
        expect(find.text('Producto eliminado definitivamente'), findsOneWidget);
      },
    );
  }

  testWidgets('un fallo conserva el producto y no anuncia éxito', (
    tester,
  ) async {
    var removed = false;
    await open(tester, (_) async => false, onDeleted: () => removed = true);
    await tester.tap(find.text('Eliminar definitivamente'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(removed, isFalse);
    expect(find.text('Producto eliminado definitivamente'), findsNothing);
    expect(find.textContaining('No se pudo confirmar'), findsOneWidget);
  });

  testWidgets('no aparece para compradores', (tester) async {
    role = 'buyer';
    await open(tester, (_) async => true);
    expect(find.text('Eliminar definitivamente'), findsNothing);
  });

  testWidgets('no aparece para un productor que no sea propietario', (
    tester,
  ) async {
    row['id_productor'] = 'other';
    await open(tester, (_) async => true);
    expect(find.text('Eliminar definitivamente'), findsNothing);
  });
}
