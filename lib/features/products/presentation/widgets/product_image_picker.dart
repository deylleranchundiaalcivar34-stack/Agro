// Seleccion y vista previa local de fotografias; la subida se realiza al guardar el formulario.

import 'package:flutter/material.dart';

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/skeleton_block.dart';

import 'package:image_picker/image_picker.dart';

import '../../data/services/product_storage_service.dart';

/// Comunica el archivo seleccionado y el estado de lectura al formulario que lo contiene.
class ProductImagePicker extends StatefulWidget {
  const ProductImagePicker({
    super.key,
    required this.onChanged,
    this.enabled = true,
    this.onLoadingChanged,
    this.initialImageUrl,
    this.productName,
    this.storageService,
  });

  final ValueChanged<XFile?> onChanged;
  final bool enabled;
  final String? initialImageUrl;
  final ValueChanged<bool>? onLoadingChanged;
  // La edicion activa la cabecera compacta; la creacion conserva su selector actual.
  final String? productName;
  final ProductStorageService? storageService;

  @override
  State<ProductImagePicker> createState() => _ProductImagePickerState();
}

class _ProductImagePickerState extends State<ProductImagePicker> {
  late final ProductStorageService _storageService;
  String? _selectionError;

  @override
  void initState() {
    super.initState();
    // La inyeccion permite probar la seleccion sin abrir una galeria ni subir archivos.
    _storageService = widget.storageService ?? ProductStorageService();
  }

  // Bytes para la vista previa y bloqueo temporal de los controles durante la seleccion.
  Uint8List? _imageBytes;
  bool _isLoading = false;

  /// Abre galeria o camara, valida el archivo y conserva la seleccion previa si falla.
  Future<void> _selectImage([ImageSource source = ImageSource.gallery]) async {
    if (_isLoading || !widget.enabled) return;
    setState(() {
      _isLoading = true;
      _selectionError = null;
    });
    widget.onLoadingChanged?.call(true);

    try {
      final XFile? image = await _storageService.seleccionarImagen(
        source: source,
      );

      if (image == null) return;

      // Validar el contenido y tamano antes de aceptar el archivo para la publicacion.
      final bytes = await image.readAsBytes();
      ProductStorageService.validateImageBytes(bytes);
      // Una firma valida no basta: rechazar imagenes corruptas antes de aceptar la vista previa.
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        try {
          final frame = await codec.getNextFrame();
          frame.image.dispose();
        } finally {
          codec.dispose();
        }
      } catch (_) {
        throw const ProductUploadException(
          'No se pudo leer la fotografia. Selecciona una imagen valida.',
        );
      }

      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
      });

      widget.onChanged(image);
    } on ProductUploadException catch (error) {
      if (!mounted) return;
      setState(() => _selectionError = error.message);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _selectionError =
            'No se pudo seleccionar la fotografia. Intenta nuevamente.',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo seleccionar la imagen. Revisa los permisos de la galeria.',
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

  /// Descarta la seleccion local sin borrar fotografias de Supabase ni de Cloudinary.
  void _removeImage() {
    setState(() {
      _imageBytes = null;
      _selectionError = null;
    });

    widget.onChanged(null);
  }

  /// Cabecera de edicion: restaurar la imagen original solo descarta el archivo local.
  Widget _editHeader(BuildContext context) {
    final preview = Container(
      width: 110,
      height: 110,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: _imageBytes != null
          ? Image.memory(_imageBytes!, fit: BoxFit.contain)
          : widget.initialImageUrl != null && widget.initialImageUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: widget.initialImageUrl!,
              fit: BoxFit.contain,
              placeholder: (_, _) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined),
            )
          : const Icon(Icons.eco_outlined, color: AppColors.primary, size: 42),
    );
    final controls = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.productName!,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isLoading || !widget.enabled
              ? null
              : () => _selectImage(),
          icon: _isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.image_outlined),
          label: Text(_isLoading ? 'Cargando...' : 'Cambiar fotografia'),
        ),
        if (_imageBytes != null)
          TextButton.icon(
            onPressed: _isLoading || !widget.enabled ? null : _removeImage,
            icon: const Icon(Icons.undo),
            label: const Text('Cancelar cambio de fotografia'),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Apilar con poco ancho o texto grande; Expanded solo reparte el ancho de la fila.
        LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth >=
                  122 + MediaQuery.textScalerOf(context).scale(180)
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    preview,
                    const SizedBox(width: 12),
                    Expanded(child: controls),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [preview, const SizedBox(height: 12), controls],
                ),
        ),
        if (_selectionError != null) ...[
          const SizedBox(height: 8),
          Text(
            _selectionError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.productName != null) return _editHeader(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fotografia del producto',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),

        // BoxFit.contain mantiene la fotografia completa dentro de una altura limitada.
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 150, maxHeight: 240),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: _imageBytes != null
              ? Image.memory(_imageBytes!, fit: BoxFit.contain)
              : widget.initialImageUrl != null
              ? CachedNetworkImage(
                  imageUrl: widget.initialImageUrl!,
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const SkeletonBlock(height: 190),
                  errorWidget: (_, _, _) => const SizedBox(
                    height: 190,
                    child: Icon(Icons.broken_image_outlined),
                  ),
                )
              : const SizedBox(
                  height: 190,
                  child: Center(child: Text('Selecciona una fotografia')),
                ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading || !widget.enabled
                    ? null
                    : () => _selectImage(),
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

            // La camara se ofrece en Android e iOS; Chrome utiliza el selector de archivos.
            if (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS))
              IconButton(
                onPressed: _isLoading || !widget.enabled
                    ? null
                    : () => _selectImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                tooltip: 'Tomar fotografia',
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
