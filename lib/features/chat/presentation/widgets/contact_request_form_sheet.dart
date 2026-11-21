import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../products/data/models/agricultural_product.dart';
import '../../data/models/contact_request.dart';
import '../../data/repositories/contact_requests_repository.dart';

class ContactRequestFormSheet extends StatefulWidget {
  const ContactRequestFormSheet({
    super.key,
    required this.product,
    required this.repository,
  });

  final AgriculturalProduct product;
  final ContactRequestsRepository repository;

  @override
  State<ContactRequestFormSheet> createState() =>
      _ContactRequestFormSheetState();
}

class _ContactRequestFormSheetState extends State<ContactRequestFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _messageController = TextEditingController();
  bool _messageEdited = false;
  bool _sending = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String? get _unit => widget.product.unit?.symbol;

  void _updateSuggestedMessage(String value) {
    if (_messageEdited) return;
    final quantity = double.tryParse(value.trim().replaceAll(',', '.'));
    if (quantity == null || quantity <= 0) {
      _messageController.clear();
      return;
    }
    _messageController.text = ContactRequest.buildInitialMessage(
      productName: widget.product.name,
      quantity: quantity,
      unit: _unit,
    );
    _messageController.selection = TextSelection.collapsed(
      offset: _messageController.text.length,
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consultar al productor',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cuéntale qué cantidad te interesa. Podrás revisar y editar el mensaje antes de enviarlo.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: _updateSuggestedMessage,
                  decoration: InputDecoration(
                    labelText: 'Cantidad que deseas consultar',
                    suffixText: _unit,
                  ),
                  validator: (value) {
                    final quantity = double.tryParse(
                      (value ?? '').trim().replaceAll(',', '.'),
                    );
                    return quantity == null || quantity <= 0
                        ? 'Ingresa una cantidad mayor que cero.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 2000,
                  onChanged: (_) => _messageEdited = true,
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => Text(
                        '$currentLength/${maxLength ?? 2000} caracteres',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  decoration: const InputDecoration(
                    labelText: 'Mensaje para el productor',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Escribe un mensaje para enviar la consulta.'
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  'La consulta no reserva el producto ni descuenta existencias. El productor debe aceptarla para abrir el chat.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _submit,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _sending ? 'Enviando consulta...' : 'Enviar consulta',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final quantity = double.parse(
      _quantityController.text.trim().replaceAll(',', '.'),
    );
    setState(() => _sending = true);
    try {
      final request = await widget.repository.create(
        productId: widget.product.id,
        quantity: quantity,
        initialMessage: _messageController.text,
      );
      if (mounted) Navigator.pop(context, request);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      final message = error.code == '23505'
          ? 'Ya tienes una consulta pendiente para este producto.'
          : 'No se pudo enviar la consulta. Intenta de nuevo.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      setState(() => _sending = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar la consulta. Intenta de nuevo.'),
        ),
      );
      setState(() => _sending = false);
    }
  }
}
