import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/services/product_storage_service.dart';

class ProductImagePicker extends StatefulWidget {
  const ProductImagePicker({
    super.key,
    required this.onChanged,
    this.enabled = true,
    this.onLoadingChanged,
  });

  final ValueChanged<XFile?> onChanged;
  final bool enabled;
  final ValueChanged<bool>? onLoadingChanged;

  @override
  State<ProductImagePicker> createState() => _ProductImagePickerState();
}

class _ProductImagePickerState extends State<ProductImagePicker> {
  final ProductStorageService _storageService = ProductStorageService();

  Uint8List? _imageBytes;
  bool _isLoading = false;

  Future<void> _selectImage() async {
    setState(() => _isLoading = true);
    widget.onLoadingChanged?.call(true);

    try {
      final XFile? image = await _storageService.seleccionarImagen();

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (bytes.length > ProductStorageService.maxImageBytes) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La imagen no debe superar los 5 MB.')),
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
      });

      widget.onChanged(image);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo seleccionar la imagen. Revisa los permisos de la galería.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onLoadingChanged?.call(false);
      }
    }
  }

  void _removeImage() {
    setState(() {
      _imageBytes = null;
    });

    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fotografía del producto',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        Container(
          width: double.infinity,
            constraints: const BoxConstraints(
            minHeight: 150,
            maxHeight: 320,
          ),
          clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _imageBytes != null
                ? Image.memory(
                    _imageBytes!,
                    fit: BoxFit.contain,
                  )
                : const SizedBox(
                    height: 190,
                    child: Center(
                      child: Text('Selecciona una fotografía'),
                    ),
                  ),
          ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading || !widget.enabled ? null : _selectImage,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_library_outlined),
                label: Text(_isLoading ? 'Cargando...' : 'Seleccionar imagen'),
              ),
            ),

            if (_imageBytes != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isLoading || !widget.enabled ? null : _removeImage,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Quitar imagen',
              ),
            ],
          ],
        ),
      ],
    );
  }
}
