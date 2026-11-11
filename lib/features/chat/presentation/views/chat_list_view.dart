import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../main/presentation/views/main_navigation_view.dart';
import '../../../profile/presentation/widgets/public_profile_avatar.dart';
import '../../data/models/chat_conversation.dart';
import '../../data/repositories/chat_repository.dart';

class ChatListView extends StatefulWidget {
  const ChatListView({super.key, this.repository});
  final ChatRepository? repository;
  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  ModuleRefreshRegistry? _refreshRegistry;
  late final ChatRepository _repository =
      widget.repository ?? ChatRepository(supabaseService: SupabaseService());
  List<ChatConversation> _chats = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = ModuleRefreshScope.maybeOf(context);
    if (identical(registry, _refreshRegistry)) return;
    _refreshRegistry?.unregister(AppRoutes.chatList);
    _refreshRegistry = registry;
    _refreshRegistry?.register(AppRoutes.chatList, _load);
  }

  @override
  void dispose() {
    _refreshRegistry?.unregister(AppRoutes.chatList);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _chats.isEmpty;
      _error = null;
    });
    try {
      final chats = await _repository.listMine();
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        final hasCachedChats = _chats.isNotEmpty;
        setState(() {
          _error = hasCachedChats
              ? null
              : 'No se pudieron cargar tus conversaciones.';
          _loading = false;
        });
        if (hasCachedChats) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo actualizar. Se muestran tus conversaciones recientes.',
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: _loading && _chats.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64),
                const SizedBox(height: 16),
                Text(_error!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _load,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          )
        : _chats.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aun no tienes conversaciones',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Abre una publicacion para conversar con la otra persona.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go(AppRoutes.products),
                    child: const Text('Ver productos'),
                  ),
                ],
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: _chats.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final chat = _chats[index];
                final isInterestedUser =
                    chat.interestedUserId == _repository.currentUserId;
                final participantName = chat.participantName?.trim();
                final displayName =
                    participantName == null || participantName.isEmpty
                    ? 'Usuario de Agro+'
                    : participantName;
                final messagePreview = chat.lastMessagePreview?.trim();
                final hasMessage =
                    messagePreview != null && messagePreview.isNotEmpty;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: PublicProfileAvatar(
                    radius: 24,
                    initial: displayName[0].toUpperCase(),
                    imageUrl: chat.participantAvatarUrl,
                  ),
                  title: Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  isThreeLine: hasMessage,
                  subtitle: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        hasMessage
                            ? '${chat.lastMessageSenderId == _repository.currentUserId ? 'Tu: ' : ''}$messagePreview'
                            : isInterestedUser
                            ? 'Tu interes en esta publicacion'
                            : 'Interes en tu publicacion',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (chat.lastMessageAt != null)
                        Text(
                          _formatMessageTime(chat.lastMessageAt!),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => context
                      .push('${AppRoutes.chatList}/${chat.id}')
                      .then((_) {
                        if (mounted) _load();
                      }),
                );
              },
            ),
          ),
  );

  String _formatMessageTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
  }
}
