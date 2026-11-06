// Verifica la edición con HTTP y selección de archivos simulados; no modifica servicios reales.
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/auth/data/repositories/profile_repository.dart';
import 'package:proyecto_agro/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:proyecto_agro/features/products/data/repositories/products_repository.dart';
import 'package:proyecto_agro/features/products/data/services/product_storage_service.dart';
import 'package:proyecto_agro/features/products/presentation/viewmodels/products_viewmodel.dart';
import 'package:proyecto_agro/features/products/presentation/views/product_edit_view.dart';
import 'package:proyecto_agro/features/products/presentation/widgets/product_image_picker.dart';

class EditSupabase extends SupabaseService {
  EditSupabase(this.testClient);
  final SupabaseClient testClient;
  @override
  SupabaseClient get client => testClient;
  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();
  @override
  User? get currentUser => User.fromJson({
    'id': 'owner',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': '2026-01-01T00:00:00Z',
  });
}

class EditPickerStorage extends ProductStorageService {
  XFile? selected;
  @override
  Future<XFile?> seleccionarImagen({
    ImageSource source = ImageSource.gallery,
  }) async => selected;
  @override
  Future<String> subirImagen(XFile imagen) =>
      throw StateError('La vista previa no debe subir archivos');
}

// Imagen válida generada en memoria para verificar también la decodificación previa.
Future<XFile> localPhoto() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
      .drawRect(const Rect.fromLTWH(0, 0, 4, 8), Paint()..color = Colors.green);
  final picture = recorder.endRecording();
  final image = await picture.toImage(4, 8);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return XFile.fromData(bytes!.buffer.asUint8List(), name: 'producto.png');
}

void main() {
  testWidgets('cabecera adaptable de 110 px sin desbordar con texto ampliado', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [240.0, 360.0, 900.0]) {
      tester.view.physicalSize = Size(width, 900);
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: ProductImagePicker(
                    productName: 'Tomates de cosecha anunciada',
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Cambiar fotografía'), findsOneWidget);
        expect(find.byIcon(Icons.eco_outlined), findsOneWidget);
        final preview = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.maxWidth == 110 &&
              w.constraints?.maxHeight == 110,
        );
        expect(tester.getSize(preview), const Size(110, 110));
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
    'selecciona, previsualiza y cancela restaurando la URL anterior sin subir',
    (tester) async {
      final storage = EditPickerStorage();
      storage.selected = await tester.runAsync(localPhoto);
      late Completer<void> selected;
      final changes = <XFile?>[];
      // La portada anterior se resuelve desde memoria: no se abre red ni caché de disco en pruebas.
      final originalImage = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(
          await storage.selected!.readAsBytes(),
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        return frame.image;
      });
      PaintingBinding.instance.imageCache.putIfAbsent(
        const CachedNetworkImageProvider('https://example.com/old.jpg'),
        () => OneFrameImageStreamCompleter(
          Future.value(ImageInfo(image: originalImage!)),
        ),
      );
      addTearDown(PaintingBinding.instance.imageCache.clear);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductImagePicker(
              productName: 'Tomates',
              initialImageUrl: 'https://example.com/old.jpg',
              storageService: storage,
              onChanged: (file) {
                changes.add(file);
                if (!selected.isCompleted) selected.complete();
              },
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        selected = Completer<void>();
        await tester.tap(find.text('Cambiar fotografía'));
        await selected.future.timeout(const Duration(seconds: 5));
      });
      await tester.pumpAndSettle();
      expect(changes.single, storage.selected);
      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
      expect(find.text('Cancelar cambio de fotografía'), findsOneWidget);
      await tester.tap(find.text('Cancelar cambio de fotografía'));
      await tester.pumpAndSettle();
      expect(changes.last, isNull);
      expect(
        tester
            .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
            .imageUrl,
        'https://example.com/old.jpg',
      );
      expect(find.text('Cancelar cambio de fotografía'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('un archivo inválido conserva la imagen y muestra el error', (
    tester,
  ) async {
    final storage = EditPickerStorage()
      ..selected = XFile.fromData(
        utf8.encode('no es una imagen'),
        name: 'falsa.jpg',
      );
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductImagePicker(
            productName: 'Tomates',
            storageService: storage,
            onChanged: (_) => changes++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Cambiar fotografía'));
    await tester.pumpAndSettle();
    expect(changes, 0);
    expect(find.textContaining('Formato no admitido'), findsWidgets);
    expect(find.byIcon(Icons.eco_outlined), findsOneWidget);
  });

  // Montaje real del formulario con Supabase simulado para verificar precarga y PATCH.
  group('formulario de edición', () {
    late SupabaseClient client;
    late EditSupabase supabase;
    late ProductsViewModel vm;
    late AuthViewModel auth;
    late GoRouter router;
    late List<http.Request> requests;
    late Map<String, dynamic> row;

    setUp(() async {
      requests = [];
      row = {
        'id_producto': 'product-1',
        'id_productor': 'owner',
        'id_categoria': 1,
        'id_fase_actual': 1,
        'nombre_producto': 'Tomates',
        'cantidad_disponible': 10,
        'unidad_medida': 'kg',
        'precio_unitario': 2,
        'estado_publicacion': true,
        'fecha_estimada_cosecha': '2030-01-15',
        'categoria': {'nombre_categoria': 'Hortalizas'},
        'fase': {'nombre_fase': 'Preventa'},
        'fotografias_producto': <Object>[],
      };
      client = SupabaseClient(
        'https://example.supabase.co',
        'fake-key',
        httpClient: MockClient((r) async {
          requests.add(r);
          if (r.url.path.endsWith('/usuarios'))
            return http.Response(
              jsonEncode({
                'id_usuario': 'owner',
                'tipos_usuario': {'nombre_tipo': 'producer'},
              }),
              200,
              request: r,
            );
          if (r.url.path.endsWith('/categorias_agricolas'))
            return http.Response(
              '[{"id_categoria":1,"nombre_categoria":"Hortalizas"}]',
              200,
              request: r,
            );
          if (r.method == 'PATCH')
            row.addAll(jsonDecode(r.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode(
              r.url.queryParameters.containsKey('id_producto') ? row : [row],
            ),
            200,
            request: r,
          );
        }),
      );
      supabase = EditSupabase(client);
      vm = ProductsViewModel(
        productsRepository: ProductsRepository(supabaseService: supabase),
      );
      auth = AuthViewModel(
        supabaseService: supabase,
        profileRepository: ProfileRepository(supabaseService: supabase),
      );
      await auth.initialLoad;
      router = GoRouter(
        initialLocation: '/products/product-1/edit',
        routes: [
          GoRoute(
            path: '/products/:id',
            builder: (_, _) =>
                const Scaffold(body: Text('Detalle actualizado')),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, _) =>
                    const ProductEditView(productId: 'product-1'),
              ),
            ],
          ),
        ],
      );
    });
    tearDown(() async {
      router.dispose();
      auth.dispose();
      vm.dispose();
      await client.dispose();
    });
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthViewModel>.value(value: auth),
            ChangeNotifierProvider<ProductsViewModel>.value(value: vm),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'precarga, guarda el mismo ID, quita fecha y conserva la fotografía',
      (tester) async {
        await open(tester);
        expect(find.text('Cambiar fotografía'), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          'Tomates',
        );
        expect(
          tester.getBottomRight(find.text('Guardar cambios')).dy,
          lessThan(600),
        );
        await tester.enterText(
          find.byType(TextFormField).first,
          'Tomates editados',
        );
        await tester.ensureVisible(find.text('Quitar fecha de cosecha'));
        await tester.tap(find.text('Quitar fecha de cosecha'));
        await tester.pump();
        await tester.tap(find.text('Guardar cambios'));
        await tester.pumpAndSettle();
        final write = requests.singleWhere((r) => r.method == 'PATCH');
        expect(write.url.queryParameters['id_producto'], 'eq.product-1');
        expect(row['nombre_producto'], 'Tomates editados');
        expect(row['fecha_estimada_cosecha'], isNull);
        expect(row['id_fase_actual'], 1);
        expect(
          requests.any((r) => r.method == 'POST' || r.method == 'DELETE'),
          isFalse,
        );
        expect(
          find.text('Publicación actualizada correctamente'),
          findsOneWidget,
        );
        expect(find.text('Detalle actualizado'), findsOneWidget);
      },
    );

    testWidgets('cancelar regresa sin escrituras', (tester) async {
      await open(tester);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(requests.every((r) => r.method == 'GET'), isTrue);
      expect(find.text('Detalle actualizado'), findsOneWidget);
    });

    testWidgets('un producto ajeno no abre los campos editables', (
      tester,
    ) async {
      row['id_productor'] = 'other';
      await open(tester);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Guardar cambios'), findsNothing);
      expect(requests.every((r) => r.method == 'GET'), isTrue);
    });

    testWidgets('errores de nombre, cantidad y precio bloquean escrituras', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(find.byType(TextFormField).at(0), '');
      await tester.ensureVisible(find.byType(TextFormField).at(1));
      await tester.enterText(find.byType(TextFormField).at(1), '0');
      await tester.ensureVisible(find.byType(TextFormField).at(2));
      await tester.enterText(find.byType(TextFormField).at(2), '-1');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(requests.every((r) => r.method == 'GET'), isTrue);
      expect(find.text('Ingresa un precio válido.'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);
    });
  });
}
