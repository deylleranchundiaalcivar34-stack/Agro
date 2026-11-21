import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/network/supabase_service.dart';
import '../../data/models/contact_request.dart';
import '../../data/repositories/contact_requests_repository.dart';

class ContactRequestsView extends StatefulWidget {
  const ContactRequestsView({super.key, this.repository});

  final ContactRequestsRepository? repository;

  @override
  State<ContactRequestsView> createState() => _ContactRequestsViewState();
}

class _ContactRequestsViewState extends State<ContactRequestsView> {
  late final ContactRequestsRepository _repository =
      widget.repository ??
      ContactRequestsRepository(supabaseService: SupabaseService());
  List<ContactRequest> _requests = const [];
  bool _loading = true;
  String? _error;
  String? _respondingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await _repository.listMine();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las solicitudes.';
        _loading = false;
      });
    }
  }

  Future<void> _respond(ContactRequest request, {required bool accept}) async {
    if (_respondingId != null) return;
    setState(() => _respondingId = request.id);
    try {
      final chatId = await _repository.respond(
        requestId: request.id,
        accept: accept,
      );
      await _load();
      if (mounted && accept && chatId != null) {
        context.push('${AppRoutes.chatList}/$chatId');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo responder. Actualiza e intenta de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _respondingId = null);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _RequestMessageState(
        icon: Icons.cloud_off_outlined,
        message: _error!,
        actionLabel: 'Reintentar',
        onPressed: _load,
      );
    }
    if (_requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            _RequestMessageState(
              icon: Icons.mark_chat_unread_outlined,
              message: 'Todavia no tienes solicitudes de producto.',
              actionLabel: 'Ver productos',
              onPressed: () => context.go(AppRoutes.products),
            ),
          ],
        ),
      );
    }

    final userId = _repository.currentUserId;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _requests.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final request = _requests[index];
          final isBuyer = request.buyerId == userId;
          final responding = _respondingId == request.id;
          return _ContactRequestCard(
            request: request,
            isBuyer: isBuyer,
            responding: responding,
            onAccept: () => _respond(request, accept: true),
            onReject: () => _respond(request, accept: false),
            onOpenChat: request.chatId == null
                ? null
                : () => context.push('${AppRoutes.chatList}/${request.chatId}'),
          );
        },
      ),
    );
  }
}

class _ContactRequestCard extends StatelessWidget {
  const _ContactRequestCard({
    required this.request,
    required this.isBuyer,
    required this.responding,
    required this.onAccept,
    required this.onReject,
    required this.onOpenChat,
  });

  final ContactRequest request;
  final bool isBuyer;
  final bool responding;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (request.status) {
      'aceptada' => 'Aceptada',
      'rechazada' => 'Rechazada',
      _ => 'Pendiente',
    };
    final title = isBuyer
        ? request.productName
        : '${request.buyerName} consulta por ${request.productName}';

    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.divider.withValues(alpha: .7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusChip(label: statusLabel, accepted: request.isAccepted),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isBuyer
                  ? 'Tu consulta por ${_quantityLabel(request)}'
                  : 'Cantidad solicitada: ${_quantityLabel(request)}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                request.initialMessage,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (request.isPending && !isBuyer) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: responding ? null : onAccept,
                    icon: responding
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chat_outlined),
                    label: const Text('Aceptar y abrir chat'),
                  ),
                  OutlinedButton.icon(
                    onPressed: responding ? null : onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Rechazar'),
                  ),
                ],
              ),
            ] else if (request.isPending && isBuyer) ...[
              const SizedBox(height: 8),
              Text(
                'Esperando respuesta del productor. Aun no es un pedido.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ] else if (request.isAccepted && onOpenChat != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: onOpenChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Abrir conversación'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _quantityLabel(ContactRequest value) {
    final quantity = value.quantity == value.quantity.roundToDouble()
        ? value.quantity.toStringAsFixed(0)
        : value.quantity.toString();
    return [quantity, value.productUnit].whereType<String>().join(' ');
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.accepted});

  final String label;
  final bool accepted;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: accepted ? AppColors.primarySurface : AppColors.background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: accepted ? AppColors.primaryDark : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _RequestMessageState extends StatelessWidget {
  const _RequestMessageState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onPressed, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
