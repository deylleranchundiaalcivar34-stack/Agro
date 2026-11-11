import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_service.dart';
import '../../data/models/profile_notification.dart';
import '../../data/repositories/profile_notifications_repository.dart';
import '../widgets/profile_subpage.dart';

class ProfileNotificationsView extends StatefulWidget {
  const ProfileNotificationsView({super.key});

  @override
  State<ProfileNotificationsView> createState() =>
      _ProfileNotificationsViewState();
}

class _ProfileNotificationsViewState extends State<ProfileNotificationsView> {
  late final _repository = ProfileNotificationsRepository(
    supabaseService: SupabaseService(),
  );
  List<ProfileNotification> _notifications = const [];
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
      final rows = await _repository.listMine();
      if (!mounted) return;
      setState(() {
        _notifications = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar tus notificaciones.';
        _loading = false;
      });
    }
  }

  Future<void> _markAsRead(ProfileNotification notification) async {
    try {
      await _repository.markAsRead(notification.id);
      if (!mounted) return;
      setState(() {
        _notifications = [
          for (final item in _notifications)
            if (item.id == notification.id)
              ProfileNotification(
                id: item.id,
                title: item.title,
                message: item.message,
                isRead: true,
              )
            else
              item,
        ];
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo marcar como leida.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ProfileSubpage(
    title: 'Notificaciones',
    actions: [
      IconButton(
        tooltip: 'Actualizar notificaciones',
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _MessageState(
            icon: Icons.cloud_off_outlined,
            message: _error!,
            action: TextButton(
              onPressed: _load,
              child: const Text('Reintentar'),
            ),
          )
        : _notifications.isEmpty
        ? const _MessageState(
            icon: Icons.notifications_none_rounded,
            message: 'No tienes notificaciones por ahora.',
          )
        : RefreshIndicator(
            onRefresh: _load,
            color: AppColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return Card(
                  color: notification.isRead
                      ? AppColors.surface
                      : AppColors.primarySurface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: AppColors.divider.withValues(alpha: .7),
                    ),
                  ),
                  child: ListTile(
                    onTap: notification.isRead
                        ? null
                        : () => _markAsRead(notification),
                    leading: Icon(
                      notification.isRead
                          ? Icons.notifications_none_rounded
                          : Icons.notifications_active_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      notification.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(notification.message),
                    trailing: notification.isRead
                        ? null
                        : const Icon(
                            Icons.circle,
                            size: 9,
                            color: AppColors.info,
                          ),
                  ),
                );
              },
            ),
          ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 56),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          ?action,
        ],
      ),
    ),
  );
}
