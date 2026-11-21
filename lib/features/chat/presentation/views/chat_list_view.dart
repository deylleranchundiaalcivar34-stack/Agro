import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../main/presentation/views/main_navigation_view.dart';
import '../../../profile/presentation/widgets/public_profile_avatar.dart';
import '../../data/models/chat_conversation.dart';
import '../../data/repositories/chat_repository.dart';
import 'contact_requests_view.dart';
import '../../utils/chat_timestamp_formatter.dart';

class ChatListView extends StatefulWidget {
  const ChatListView({
    super.key,
    this.repository,
    this.showRequestsInitially = false,
  });
  final ChatRepository? repository;
  final bool showRequestsInitially;
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
  bool _showRequests = false;

  @override
  void initState() {
    super.initState();
    _showRequests = widget.showRequestsInitially;
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
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                  label: Text('Conversaciones'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.mark_chat_unread_outlined),
                  label: Text('Solicitudes'),
                ),
              ],
              selected: {_showRequests},
              onSelectionChanged: (selection) {
                setState(() => _showRequests = selection.first);
              },
            ),
          ),
        ),
        Expanded(
          child: _showRequests
              ? const ContactRequestsView()
              : _buildConversationBody(context),
        ),
      ],
    ),
  );

  Widget _buildConversationBody(BuildContext context) =>
      _loading && _chats.isEmpty
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
              ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
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
                  'Envia una consulta desde una publicacion. El chat se habilitara cuando el productor la acepte.',
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: _chats.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
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
              final isImage = chat.lastMessageContentType == 'imagen';
              final preview = isImage ? 'Imagen adjunta' : messagePreview;
              return Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => context
                      .push('${AppRoutes.chatList}/${chat.id}')
                      .then((_) {
                        if (mounted) _load();
                      }),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.divider.withValues(alpha: .75),
                      ),
                    ),
                    child: Row(
                      children: [
                        PublicProfileAvatar(
                          radius: 25,
                          initial: displayName[0].toUpperCase(),
                          imageUrl: chat.participantAvatarUrl,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  if (chat.lastMessageAt != null)
                                    Text(
                                      _formatMessageTime(chat.lastMessageAt!),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    chat.productName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  if (isImage) ...[
                                    const Icon(
                                      Icons.image_outlined,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      hasMessage
                                          ? '${chat.lastMessageSenderId == _repository.currentUserId ? 'Tú: ' : ''}${preview ?? ''}'
                                          : isInterestedUser
                                          ? 'Tu consulta está en esta conversación'
                                          : 'Consulta sobre tu publicación',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );

  String _formatMessageTime(DateTime dateTime) {
    return ChatTimestampFormatter.listLabel(dateTime);
  }
}
