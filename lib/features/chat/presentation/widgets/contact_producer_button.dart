import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../products/data/models/agricultural_product.dart';
import '../../data/models/contact_request.dart';
import '../../data/repositories/contact_requests_repository.dart';
import 'contact_request_form_sheet.dart';

class ContactProducerButton extends StatefulWidget {
  const ContactProducerButton({
    super.key,
    required this.product,
    this.repository,
  });

  final AgriculturalProduct product;
  final ContactRequestsRepository? repository;

  @override
  State<ContactProducerButton> createState() => _ContactProducerButtonState();
}

class _ContactProducerButtonState extends State<ContactProducerButton> {
  late final ContactRequestsRepository _repository =
      widget.repository ??
      ContactRequestsRepository(supabaseService: SupabaseService());
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final requestFuture = showModalBottomSheet<ContactRequest>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (_) => ContactRequestFormSheet(
          product: widget.product,
          repository: _repository,
        ),
      );
      if (mounted) setState(() => _opening = false);
      final request = await requestFuture;
      if (mounted && request != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Consulta enviada. Te avisaremos cuando el productor responda.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo enviar la consulta. Intenta de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton.icon(
      onPressed: _opening ? null : _open,
      icon: _opening
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.question_answer_outlined),
      label: const Text('Consultar al productor'),
    ),
  );
}
