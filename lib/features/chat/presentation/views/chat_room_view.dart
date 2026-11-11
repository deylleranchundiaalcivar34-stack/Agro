import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../main/presentation/views/main_navigation_view.dart';
import '../../../profile/data/models/public_contact_profile.dart';
import '../../../profile/presentation/widgets/public_profile_avatar.dart';
import '../../data/models/chat_conversation.dart';
import '../../data/models/chat_message.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/chat_typing_service.dart';

class ChatRoomView extends StatefulWidget {
  const ChatRoomView({super.key, required this.roomId, this.repository});
  final String roomId;
  final ChatRepository? repository;

  @override
  State<ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<ChatRoomView>
    with WidgetsBindingObserver {
  late final ChatRepository _repository =
      widget.repository ?? ChatRepository(supabaseService: SupabaseService());
  final _draft = TextEditingController();
  final _draftFocus = FocusNode();
  final _scroll = ScrollController();
  StreamSubscription<List<ChatMessage>>? _subscription;
  ChatTypingService? _typingService;
  ChatRoomHeaderController? _headerController;
  Timer? _typingDebounce;
  Timer? _remoteTypingExpiry;
  ChatConversation? _chat;
  Map<String, PublicContactProfile> _profiles = const {};
  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  bool _remoteTyping = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draftFocus.addListener(_onFocusChanged);
    _start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _headerController = ChatRoomHeaderScope.maybeOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _publishHeader();
    });
  }

  @override
  void didUpdateWidget(covariant ChatRoomView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _draft.clear();
      _draftFocus.unfocus();
      _start();
    }
  }

  Future<void> _start() async {
    final generation = ++_generation;
    await _subscription?.cancel();
    _subscription = null;
    await _typingService?.dispose();
    _typingService = null;
    _typingDebounce?.cancel();
    _remoteTypingExpiry?.cancel();

    try {
      final cachedChat = _repository.cachedConversation(widget.roomId);
      final cachedMessages = _repository.cachedMessages(widget.roomId);
      if (mounted) {
        setState(() {
          _chat = cachedChat;
          _profiles = const {};
          _messages = cachedMessages;
          _loading = cachedMessages.isEmpty;
          _remoteTyping = false;
          _error = null;
        });
        _publishHeader();
      }

      final chat = await _repository.get(widget.roomId);
      if (!mounted || generation != _generation) return;
      if (chat == null) {
        setState(() {
          _chat = null;
          _messages = const [];
          _error = 'No tienes acceso a esta conversacion.';
          _loading = false;
        });
        _publishHeader();
        return;
      }

      final profiles = await _repository.loadParticipantProfiles(chat);
      if (!mounted || generation != _generation) return;
      setState(() {
        _chat = chat;
        _profiles = profiles;
        _error = null;
      });
      _publishHeader();

      _subscription = _repository
          .watchMessages(widget.roomId)
          .listen(
            (messages) {
              if (!mounted || generation != _generation) return;
              setState(() {
                _messages = messages;
                _loading = false;
                _error = null;
              });
              _scrollToBottom();
            },
            onError: (Object _) {
              if (!mounted || generation != _generation) return;
              setState(() {
                _loading = false;
                _error = 'No se pudieron actualizar los mensajes.';
              });
            },
          );
      _connectTyping(generation);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = 'No se pudo actualizar esta conversacion.';
          _loading = false;
        });
      }
    }
  }

  void _connectTyping(int generation) {
    final chat = _chat;
    if (chat == null) return;
    final service = ChatTypingService(supabaseService: SupabaseService());
    _typingService = service;
    service.connect(
      chatId: chat.id,
      onRemoteTyping: (isTyping) {
        if (!mounted || generation != _generation) return;
        _remoteTypingExpiry?.cancel();
        setState(() => _remoteTyping = isTyping);
        _publishHeader();
        if (isTyping) {
          _remoteTypingExpiry = Timer(const Duration(seconds: 5), () {
            if (!mounted || generation != _generation) return;
            setState(() => _remoteTyping = false);
            _publishHeader();
          });
        }
      },
    );
  }

  void _onDraftChanged(String value) {
    _typingDebounce?.cancel();
    if (value.trim().isEmpty) {
      _typingService?.setLocalTyping(false);
      return;
    }
    _typingDebounce = Timer(const Duration(milliseconds: 320), () {
      _typingService?.setLocalTyping(true);
    });
  }

  void _onFocusChanged() {
    if (!_draftFocus.hasFocus) {
      _typingDebounce?.cancel();
      _typingService?.setLocalTyping(false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _typingDebounce?.cancel();
      _typingService?.setLocalTyping(false);
    }
  }

  Future<void> _send() async {
    if (_sending || _draft.text.trim().isEmpty) return;
    _typingDebounce?.cancel();
    _typingService?.setLocalTyping(false);
    final text = _draft.text;
    setState(() => _sending = true);
    try {
      final persisted = await _repository.send(widget.roomId, text);
      if (!mounted) return;
      _draft.clear();
      setState(() {
        if (!_messages.any((message) => message.id == persisted.id)) {
          _messages = [..._messages, persisted]
            ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
        }
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo enviar. El mensaje sigue en el borrador.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _nameFor(String userId) {
    if (userId == _repository.currentUserId) {
      final own = _profiles[userId];
      return own?.displayName ?? 'Tu';
    }
    return _profiles[userId]?.displayName ??
        _chat?.participantName ??
        'Usuario de Agro+';
  }

  String? _avatarFor(String userId) {
    if (userId == _chat?.participantId) {
      return _profiles[userId]?.avatarUrl ?? _chat?.participantAvatarUrl;
    }
    return _profiles[userId]?.avatarUrl;
  }

  String _initialFor(String userId) {
    final name = _nameFor(userId).trim();
    return name.isEmpty ? 'A' : name[0].toUpperCase();
  }

  void _publishHeader() {
    final chat = _chat;
    final controller = _headerController;
    if (controller == null) return;
    if (chat == null) {
      controller.clear();
      return;
    }
    final participantId = chat.participantId ?? '';
    final participant = _profiles[participantId];
    final name =
        participant?.displayName ?? chat.participantName ?? 'Usuario de Agro+';
    controller.show(
      ChatRoomHeaderData(
        name: name,
        initial: name.trim().isEmpty ? 'A' : name.trim()[0].toUpperCase(),
        avatarUrl: participant?.avatarUrl ?? chat.participantAvatarUrl,
        subtitle: _remoteTyping ? 'Esta escribiendo…' : chat.productName,
        onOpenContact: _showContactDetails,
      ),
    );
  }

  Future<void> _showContactDetails() async {
    final chat = _chat;
    if (chat == null) return;
    final participantId = chat.participantId ?? '';
    final profile = _profiles[participantId];
    final name =
        profile?.displayName ?? chat.participantName ?? 'Usuario de Agro+';
    final phone = profile?.whatsappVisible == true
        ? profile?.whatsappPhone
        : chat.participantWhatsAppPhone;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PublicProfileAvatar(
              radius: 44,
              initial: name.trim().isEmpty ? 'A' : name.trim()[0],
              imageUrl: profile?.avatarUrl ?? chat.participantAvatarUrl,
            ),
            const SizedBox(height: 12),
            Text(name, style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Conversacion por ${chat.productName}',
              textAlign: TextAlign.center,
              style: Theme.of(sheetContext).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            if (phone != null && phone.isNotEmpty) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openWhatsApp(phone),
                  icon: const Icon(Icons.chat_rounded),
                  label: Text('WhatsApp · $phone'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.https('wa.me', '/$digits');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftFocus.removeListener(_onFocusChanged);
    _typingDebounce?.cancel();
    _remoteTypingExpiry?.cancel();
    final activeChatId = _chat?.id;
    if (activeChatId != null) {
      _headerController?.clear();
    }
    _subscription?.cancel();
    unawaited(_typingService?.dispose() ?? Future<void>.value());
    _draft.dispose();
    _draftFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(child: _buildMessages()),
          if (_error != null && _messages.isNotEmpty)
            MaterialBanner(
              content: Text(_error!),
              leading: const Icon(Icons.cloud_off_outlined),
              actions: [
                TextButton(onPressed: _start, child: const Text('Reintentar')),
              ],
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _draft,
                      focusNode: _draftFocus,
                      enabled: _chat != null,
                      maxLength: 2000,
                      minLines: 1,
                      maxLines: 4,
                      onChanged: _onDraftChanged,
                      decoration: InputDecoration(
                        hintText: 'Mensaje',
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _chat == null || _sending ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.surface,
                    ),
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.surface,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    tooltip: 'Enviar mensaje',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildMessages() {
    if (_error != null && _messages.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 56),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _start, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (_loading && _messages.isEmpty) return const _ChatRoomSkeleton();
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.forum_outlined,
                size: 56,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Aun no hay mensajes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text('Saluda para empezar a conversar.'),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessage(index),
    );
  }

  Widget _buildMessage(int index) {
    final message = _messages[index];
    final mine = message.senderId == _repository.currentUserId;
    final previousSameSender =
        index > 0 && _messages[index - 1].senderId == message.senderId;
    final nextSameSender =
        index < _messages.length - 1 &&
        _messages[index + 1].senderId == message.senderId;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine || !nextSameSender ? 18 : 5),
      bottomRight: Radius.circular(!mine || !nextSameSender ? 18 : 5),
    );

    return Padding(
      padding: EdgeInsets.only(top: previousSameSender ? 2 : 8),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            SizedBox(
              width: 28,
              child: previousSameSender
                  ? const SizedBox.shrink()
                  : PublicProfileAvatar(
                      radius: 13,
                      initial: _initialFor(message.senderId),
                      imageUrl: _avatarFor(message.senderId),
                    ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.76,
              ),
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
              decoration: BoxDecoration(
                color: mine ? AppColors.primarySurface : AppColors.surface,
                borderRadius: radius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.content,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatTime(message.sentAt),
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          if (mine) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: 28,
              child: previousSameSender
                  ? const SizedBox.shrink()
                  : PublicProfileAvatar(
                      radius: 13,
                      initial: _initialFor(message.senderId),
                      imageUrl: _avatarFor(message.senderId),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _ChatRoomSkeleton extends StatelessWidget {
  const _ChatRoomSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    reverse: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
    children: const [
      _SkeletonBubble(widthFactor: 0.64, alignedRight: true),
      SizedBox(height: 16),
      _SkeletonBubble(widthFactor: 0.72, alignedRight: false),
      SizedBox(height: 16),
      _SkeletonBubble(widthFactor: 0.48, alignedRight: false),
    ],
  );
}

class _SkeletonBubble extends StatelessWidget {
  const _SkeletonBubble({
    required this.widthFactor,
    required this.alignedRight,
  });

  final double widthFactor;
  final bool alignedRight;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * widthFactor;
    final bubble = Container(
      width: maxWidth,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(18),
      ),
    );
    return Row(
      mainAxisAlignment: alignedRight
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [bubble],
    );
  }
}
