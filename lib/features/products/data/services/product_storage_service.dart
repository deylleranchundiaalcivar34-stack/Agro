import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ProductUploadException implements Exception {
  const ProductUploadException(this.message);
  final String message;
}

class ProductStorageService {
  static const String cloudName = 'ktfyc8rj';
  static const String uploadPreset = 'agroproductos';
  static const int maxImageBytes = 5 * 1024 * 1024;

  final ImagePicker _picker = ImagePicker();

  // Seleccionar una fotografía.
  Future<XFile?> seleccionarImagen() async {
    return await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
  }

  // Subir la fotografía a Cloudinary.
  Future<String> subirImagen(XFile imagen) async {
    if (cloudName.trim().isEmpty || uploadPreset.trim().isEmpty) {
      throw const ProductUploadException('Falta configurar Cloudinary.');
    }
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final bytes = await imagen.readAsBytes();

    if (bytes.isEmpty) {
      throw const ProductUploadException('La imagen seleccionada está vacía.');
    }
    if (bytes.length > maxImageBytes) {
      throw const ProductUploadException('La imagen no debe superar los 5 MB.');
    }

    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = uploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: imagen.name),
    );

    final response = await request.send().timeout(const Duration(seconds: 60));
    final responseBody = await response.stream.bytesToString().timeout(
      const Duration(seconds: 60),
    );

    if (response.statusCode != 200) {
      throw const ProductUploadException(
        'Cloudinary rechazó la fotografía. Intenta con otra imagen.',
      );
    }

    dynamic data;
    try {
      data = jsonDecode(responseBody);
    } on FormatException {
      throw const ProductUploadException(
        'Cloudinary devolvió una respuesta inválida.',
      );
    }
    final url = data is Map ? data['secure_url'] : null;
    final parsedUrl = url is String ? Uri.tryParse(url) : null;
    if (url is! String ||
        parsedUrl == null ||
        parsedUrl.scheme != 'https' ||
        parsedUrl.host.isEmpty) {
      throw const ProductUploadException(
        'Cloudinary no devolvió una URL válida.',
      );
    }

    return url;
  }
}
