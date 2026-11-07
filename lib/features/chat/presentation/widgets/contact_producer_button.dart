import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/network/supabase_service.dart';
import '../../data/repositories/chat_repository.dart';

class ContactProducerButton extends StatefulWidget {
  const ContactProducerButton({
    super.key,
    required this.productId,
    this.repository,
  });
  final String productId;
  final ChatRepository? repository;
  @override
  State<ContactProducerButton> createState() => _ContactProducerButtonState();
}

class _ContactProducerButtonState extends State<ContactProducerButton> {
  late final ChatRepository _repository =
      widget.repository ?? ChatRepository(supabaseService: SupabaseService());
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final chatId = await _repository.openForProduct(widget.productId);
      if (mounted) context.push('${AppRoutes.chatList}/$chatId');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el chat. Intenta de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: _opening ? null : _open,
    icon: _opening
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.chat_outlined),
    label: const Text('Contactar al productor'),
  );
}
