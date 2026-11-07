import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/products/data/models/product_unit.dart';
import 'package:proyecto_agro/features/products/data/repositories/products_repository.dart';
import 'package:proyecto_agro/features/products/data/services/product_storage_service.dart';
import 'package:proyecto_agro/features/products/presentation/viewmodels/products_viewmodel.dart';

class PhotoSupabase extends SupabaseService {
  PhotoSupabase(this.testClient);
  final SupabaseClient testClient;
  @override
  SupabaseClient get client => testClient;
  @override
  User? get currentUser => User.fromJson({
    'id': 'owner',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': '2026-01-01T00:00:00Z',
  });
}

void main() {
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=',
  );
  XFile photo() =>
      XFile.fromData(png, name: 'sin-extension', mimeType: 'image/png');
  const url = 'https://res.cloudinary.com/ktfyc8rj/image/upload/photo.png';

  test(
    'sube multipart al cloud y preset confirmados y devuelve secure_url',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/v1_1/ktfyc8rj/image/upload');
        expect(latin1.decode(request.bodyBytes), contains('agroproductos'));
        expect(latin1.decode(request.bodyBytes), contains('producto.png'));
        return http.Response(jsonEncode({'secure_url': url}), 200);
      });
      addTearDown(client.close);
      expect(
        await ProductStorageService(httpClient: client).subirImagen(photo()),
        url,
      );
    },
  );

  test('conserva HTTP y error.message de Cloudinary sin exponer el cuerpo completo', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'error': {'message': 'Upload preset not found'},
        }),
        400,
      ),
    );
    addTearDown(client.close);
    await expectLater(
      ProductStorageService(httpClient: client).subirImagen(photo()),
      throwsA(
        isA<ProductUploadException>()
            .having((e) => e.statusCode, 'HTTP', 400)
            .having(
              (e) => e.cloudinaryMessage,
              'detalle',
              'Upload preset not found',
            )
            .having((e) => e.message, 'mensaje', contains('preset')),
      ),
    );
  });

  test('rechaza archivos vacios, grandes y formatos no admitidos antes de conectar', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    for (final data in [
      Uint8List(0),
      Uint8List(ProductStorageService.maxImageBytes + 1),
      Uint8List.fromList([1, 2, 3]),
    ]) {
      await expectLater(
        ProductStorageService(httpClient: client)
            .subirImagen(XFile.fromData(data, name: 'falso.jpg')),
        throwsA(isA<ProductUploadException>()),
      );
    }
    expect(calls, 0);
    expect(
      ProductStorageService.validateImageBytes(
        Uint8List.fromList([255, 216, 255, 0]),
      ),
      'jpeg',
    );
    expect(
      ProductStorageService.validateImageBytes(
        Uint8List.fromList([82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80]),
      ),
      'webp',
    );
  });

  test('maneja desconexion, timeout, HTML inesperado y URL insegura', () async {
    for (var mode = 0; mode < 4; mode++) {
      final client = MockClient((_) async {
        if (mode == 0) throw http.ClientException('offline');
        if (mode == 1) throw TimeoutException('timeout');
        if (mode == 2) return http.Response('<html>error</html>', 502);
        return http.Response(
          '{"secure_url":"http://example.com/photo.png"}',
          200,
        );
      });
      await expectLater(
        ProductStorageService(httpClient: client).subirImagen(photo()),
        throwsA(isA<ProductUploadException>()),
      );
      client.close();
    }
  });

  for (final unit in ProductUnit.values) {
    test(
      'ViewModel guarda la unidad ${unit.value} sin convertir la cantidad',
      () async {
        final writes = <http.Request>[];
        final client = SupabaseClient(
          'https://example.supabase.co',
          'fake-key',
          httpClient: MockClient((r) async {
            if (r.method == 'POST') {
              writes.add(r);
              expect(r.url.path, endsWith('/productos'));
              final data = jsonDecode(r.body) as Map<String, dynamic>;
              expect(data['unidad_medida'], unit.value);
              expect(data['cantidad_disponible'], 5);
              return http.Response(
                '{"id_producto":"product-1"}',
                201,
                request: r,
              );
            }
            return http.Response(
              r.url.path.endsWith('/fases_comercializacion')
                  ? '{"id_fase":1}'
                  : '[]',
              200,
              request: r,
            );
          }),
        );
        final vm = ProductsViewModel(
          productsRepository: ProductsRepository(
            supabaseService: PhotoSupabase(client),
          ),
        );
        expect(
          await vm.createPreorderProduct(
            name: 'Tomates',
            categoryId: 1,
            quantity: 5,
            unit: unit,
            price: 2,
          ),
          isTrue,
        );
        expect(writes, hasLength(1));
        vm.dispose();
        await client.dispose();
      },
    );
  }

  test('no consulta ni publica sin unidad o con cantidad cero', () async {
    var calls = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'fake-key',
      httpClient: MockClient((r) async {
        calls++;
        return http.Response('{}', 200, request: r);
      }),
    );
    final vm = ProductsViewModel(
      productsRepository: ProductsRepository(
        supabaseService: PhotoSupabase(client),
      ),
    );
    expect(
      await vm.createPreorderProduct(
        name: 'Tomates',
        categoryId: 1,
        quantity: 5,
        price: 2,
      ),
      isFalse,
    );
    expect(vm.errorMessage, contains('unidad'));
    expect(
      await vm.createPreorderProduct(
        name: 'Tomates',
        categoryId: 1,
        quantity: 0,
        unit: ProductUnit.kg,
        price: 2,
      ),
      isFalse,
    );
    expect(calls, 0);
    vm.dispose();
    await client.dispose();
  });

  for (final mode in [
    'success',
    'photoFailure',
    'productFailure',
    'uploadFailure',
    'refreshFailure',
  ]) {
    test('flujo de publicacion simulado: $mode', () async {
      final writes = <http.Request>[];
      var uploaded = false;
      final wait = Completer<void>();
      final uploadClient = MockClient((_) async {
        await wait.future;
        uploaded = true;
        return http.Response(
          jsonEncode(
            mode == 'uploadFailure'
                ? {
                    'error': {'message': 'Upload preset not found'},
                  }
                : {'secure_url': url},
          ),
          mode == 'uploadFailure' ? 400 : 200,
        );
      });
      final client = SupabaseClient(
        'https://example.supabase.co',
        'fake-key',
        httpClient: MockClient((r) async {
          if (r.method == 'POST') {
            expect(uploaded, isTrue);
            writes.add(r);
            if (r.url.path.endsWith('/productos')) {
              if (mode == 'productFailure') {
                throw http.ClientException('response lost');
              }
              return http.Response(
                '{"id_producto":"product-1"}',
                201,
                request: r,
              );
            }
            expect(jsonDecode(r.body), {
              'id_producto': 'product-1',
              'url_fotografia': url,
            });
            return http.Response(
              mode == 'photoFailure' ? '{"message":"denied"}' : '',
              mode == 'photoFailure' ? 403 : 201,
              request: r,
            );
          }
          if (r.url.path.endsWith('/fases_comercializacion')) {
            return http.Response('{"id_fase":1}', 200, request: r);
          }
          if (mode == 'refreshFailure') {
            return http.Response('{"message":"offline"}', 503, request: r);
          }
          return http.Response('[]', 200, request: r);
        }),
      );
      final vm = ProductsViewModel(
        productsRepository: ProductsRepository(
          supabaseService: PhotoSupabase(client),
          storageService: ProductStorageService(httpClient: uploadClient),
        ),
      );
      Future<bool> publish() => vm.createPreorderProduct(
        name: 'Tomates',
        categoryId: 1,
        quantity: 5,
        unit: ProductUnit.kg,
        price: 2,
        image: photo(),
      );
      final pending = publish();
      expect(vm.isSubmitting, isTrue);
      expect(await publish(), isFalse);
      wait.complete();
      final result = await pending;
      expect(result, mode != 'productFailure' && mode != 'uploadFailure');
      expect(
        writes.where((r) => r.url.path.endsWith('/productos')).length,
        mode == 'uploadFailure' ? 0 : 1,
      );
      expect(
        writes
            .where((r) => r.url.path.endsWith('/fotografias_producto'))
            .length,
        mode == 'uploadFailure' || mode == 'productFailure' ? 0 : 1,
      );
      if (mode == 'photoFailure' || mode == 'refreshFailure') {
        expect(vm.publicationWarning, isNotNull);
      }
      if (mode == 'uploadFailure') expect(vm.lastUploadError?.statusCode, 400);
      if (mode == 'productFailure') {
        expect(vm.publicationRequiresReview, isTrue);
        expect(await publish(), isFalse);
        expect(writes, hasLength(1));
      }
      expect(vm.isSubmitting, isFalse);
      vm.dispose();
      await client.dispose();
      uploadClient.close();
    });
  }
}
