// Seleccion local y subida de fotografias a Cloudinary, sin guardar filas en Supabase.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Separa el mensaje visible del estado HTTP y el detalle tecnico devuelto por Cloudinary.
class ProductUploadException implements Exception {
  const ProductUploadException(
    this.message, {
    this.statusCode,
    this.cloudinaryMessage,
  });
  final String message;
  final int? statusCode;
  final String? cloudinaryMessage;
}

/// Centraliza limites, formatos y envio multipart de fotografias de productos.
class ProductStorageService {
  // Configuracion de destino y preset de subida; no se utilizan secretos de firma en el cliente.
  static const String cloudName = 'ktfyc8rj';
  static const String uploadPreset = 'agroproductos';
  static const int maxImageBytes = 5 * 1024 * 1024;

  // Permite inyectar HTTP en pruebas; el servicio solo cierra los clientes que crea.
  ProductStorageService({this._httpClient});
  final http.Client? _httpClient;

  /// Comprueba tamano y firmas JPG, PNG o WebP sin confiar en la extension del archivo.
  static String validateImageBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const ProductUploadException('La imagen seleccionada esta vacia.');
    }
    if (bytes.length > maxImageBytes) {
      throw const ProductUploadException('La imagen no debe superar los 5 MB.');
    }
    // La firma identifica el formato; la decodificacion final corresponde al visor o al servidor.
    bool startsWith(List<int> signature) =>
        bytes.length >= signature.length &&
        List.generate(
          signature.length,
          (i) => bytes[i] == signature[i],
        ).every((v) => v);
    if (startsWith([255, 216, 255])) return 'jpeg';
    if (startsWith([137, 80, 78, 71, 13, 10, 26, 10])) return 'png';
    if (bytes.length >= 12 &&
        startsWith([82, 73, 70, 70]) &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'webp';
    }
    throw const ProductUploadException(
      'Formato no admitido. Selecciona una imagen JPG, PNG o WebP.',
    );
  }

  final ImagePicker _picker = ImagePicker();

  // Seleccionar una fotografia.
  Future<XFile?> seleccionarImagen({
    ImageSource source = ImageSource.gallery,
  }) async {
    return await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
  }

  /// Selects a compact profile image while leaving product-image selection unchanged.
  Future<XFile?> seleccionarAvatar({
    ImageSource source = ImageSource.gallery,
  }) async => _picker.pickImage(
    source: source,
    imageQuality: 82,
    maxWidth: 512,
    maxHeight: 512,
  );

  // Subir la fotografia a Cloudinary.
  Future<String> subirImagen(XFile imagen) async {
    if (cloudName.trim().isEmpty || uploadPreset.trim().isEmpty) {
      throw const ProductUploadException('Falta configurar Cloudinary.');
    }
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final bytes = await imagen.readAsBytes();
    final format = validateImageBytes(bytes);

    // El preset y el archivo se envian como multipart, compatible con Chrome y moviles.
    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = uploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: 'producto.$format'),
    );

    final client = _httpClient ?? http.Client();
    try {
      // Se limita por separado la espera de respuesta y la lectura de su contenido.
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 60));
      final responseBody = await response.stream.bytesToString().timeout(
        const Duration(seconds: 60),
      );

      // Clasificar el rechazo sin mostrar el cuerpo completo; conservar el diagnostico tecnico.
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String? detail;
        try {
          final body = jsonDecode(responseBody);
          if (body is Map && body['error'] is Map) {
            final message = body['error']['message'];
            if (message is String) detail = message;
          }
        } on FormatException {
          // Conservar el estado HTTP aunque la respuesta no sea JSON.
        }
        final reason = (detail ?? '').toLowerCase();
        final message = reason.contains('preset') || reason.contains('unsigned')
            ? 'Cloudinary no acepto el preset. Comprueba que agroproductos permita subidas unsigned.'
            : response.statusCode == 413 || reason.contains('too large')
            ? 'Cloudinary rechazo el tamano de la fotografia.'
            : reason.contains('format') || reason.contains('image file')
            ? 'Cloudinary no acepto el formato. Usa JPG, PNG o WebP.'
            : response.statusCode == 429
            ? 'Demasiadas solicitudes. Espera antes de reintentar.'
            : 'Cloudinary no pudo subir la fotografia. Intenta mas tarde.';
        throw ProductUploadException(
          '$message (HTTP ${response.statusCode})',
          statusCode: response.statusCode,
          cloudinaryMessage: detail,
        );
      }

      dynamic data;
      try {
        data = jsonDecode(responseBody);
      } on FormatException {
        throw const ProductUploadException(
          'Cloudinary devolvio una respuesta invalida.',
        );
      }
      // Solo una secure_url HTTPS valida se devuelve al repositorio para su asociacion.
      final url = data is Map ? data['secure_url'] : null;
      final parsedUrl = url is String ? Uri.tryParse(url) : null;
      if (url is! String ||
          parsedUrl == null ||
          parsedUrl.scheme != 'https' ||
          parsedUrl.host.isEmpty) {
        throw const ProductUploadException(
          'Cloudinary no devolvio una URL valida.',
        );
      }

      return url;
    } on TimeoutException {
      throw const ProductUploadException(
        'La subida tardo demasiado. Revisa tu conexion e intenta de nuevo.',
      );
    } on http.ClientException {
      throw const ProductUploadException(
        'No se pudo conectar con Cloudinary. Revisa tu conexion y los errores de red o CORS en Chrome.',
      );
    } finally {
      // Un cliente inyectado pertenece al llamador y debe permanecer abierto.
      if (_httpClient == null) client.close();
    }
  }

  /// Uploads a bounded avatar through the same unsigned preset as product photos.
  Future<String> subirAvatar(XFile imagen) => subirImagen(imagen);
}
