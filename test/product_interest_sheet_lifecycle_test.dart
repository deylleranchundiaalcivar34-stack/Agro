import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/auth/data/repositories/profile_repository.dart';
import 'package:proyecto_agro/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:proyecto_agro/features/products/data/models/agricultural_product.dart';
import 'package:proyecto_agro/features/products/data/repositories/products_repository.dart';
import 'package:proyecto_agro/features/products/presentation/viewmodels/products_viewmodel.dart';
import 'package:proyecto_agro/features/products/presentation/views/product_detail_view.dart';

class _InterestSupabase extends SupabaseService {
  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;
}

class _InterestProductsRepository extends ProductsRepository {
  _InterestProductsRepository(SupabaseService supabaseService)
    : super(supabaseService: supabaseService);

  @override
  String? get currentUserId => null;

  @override
  Future<AgriculturalProduct?> getProduct(String productId) async =>
      const AgriculturalProduct(
        id: 'product-1',
        producerId: 'producer-1',
        categoryId: 1,
        phaseId: 1,
        name: 'Moras',
        availableQuantity: 50,
        unitPrice: 2,
        isPublished: true,
        categoryName: 'Frutas',
        phaseName: 'Preventa',
      );
}

void main() {
  testWidgets(
    'cerrar el formulario con el campo activo no usa controlador dispuesto',
    (tester) async {
      final supabase = _InterestSupabase();
      final auth = AuthViewModel(
        supabaseService: supabase,
        profileRepository: ProfileRepository(supabaseService: supabase),
      );
      final products = ProductsViewModel(
        productsRepository: _InterestProductsRepository(supabase),
      );
      addTearDown(auth.dispose);
      addTearDown(products.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthViewModel>.value(value: auth),
            ChangeNotifierProvider<ProductsViewModel>.value(value: products),
          ],
          child: const MaterialApp(
            home: ProductDetailView(productId: 'product-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Registrar interes'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Registrar interes'));
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byType(TextFormField));
      await tester.pump();

      await tester.tapAt(const Offset(8, 8));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.takeException(), isNull);
    },
  );
}
