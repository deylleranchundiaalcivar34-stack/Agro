import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/profile_order.dart';
import '../../data/repositories/profile_orders_repository.dart';
import '../widgets/profile_subpage.dart';

import 'package:provider/provider.dart';

class ProfileOrdersView extends StatefulWidget {
  const ProfileOrdersView({super.key});

  @override
  State<ProfileOrdersView> createState() => _ProfileOrdersViewState();
}

class _ProfileOrdersViewState extends State<ProfileOrdersView> {
  late final ProfileOrdersRepository _repository = ProfileOrdersRepository(
    supabaseService: SupabaseService(),
  );
  List<ProfileOrder> _orders = const [];
  bool _loading = true;
  String? _error;

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
      final orders = await _repository.listMine();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar tus pedidos.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthViewModel>().currentUser?.id;
    return ProfileSubpage(
      title: 'Mis pedidos',
      actions: [
        IconButton(
          tooltip: 'Actualizar pedidos',
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _StateMessage(
              icon: Icons.cloud_off_outlined,
              message: _error!,
              actionLabel: 'Reintentar',
              onPressed: _load,
            )
          : _orders.isEmpty
          ? const _StateMessage(
              icon: Icons.receipt_long_outlined,
              message: 'Todavia no tienes pedidos registrados.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _OrderCard(order: _orders[index], userId: userId),
              ),
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.userId});

  final ProfileOrder order;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final isBuyer = order.buyerId == userId;
    final names = order.lines.map((line) => line.name).take(2).join(', ');
    final more = order.lines.length > 2
        ? ' y ${order.lines.length - 2} mas'
        : '';
    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.divider.withValues(alpha: .65)),
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
                    isBuyer ? 'Compra' : 'Pedido recibido',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      order.status,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              names.isEmpty
                  ? 'Pedido ${order.id.substring(0, 8)}'
                  : '$names$more',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Pedido ${order.id.substring(0, 8)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  '\$${order.total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
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
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onPressed, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
