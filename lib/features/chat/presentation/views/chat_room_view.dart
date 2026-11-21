import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
import '../../utils/chat_timestamp_formatter.dart';

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
  final _imagePicker = ImagePicker();
  StreamSubscription<List<ChatMessage>>? _subscription;
  StreamSubscription<DateTime?>? _readSubscription;
  ChatTypingService? _typingService;
  ChatRoomHeaderController? _headerController;
  Timer? _typingDebounce;
  Timer? _remoteTypingExpiry;
  ChatConversation? _chat;
  Map<String, PublicContactProfile> _profiles = const {};
  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  bool _sendingImage = false;
  bool _remoteTyping = false;
  bool _isAppResumed = true;
  int _unreadNewMessages = 0;
  DateTime? _participantReadAt;
  DateTime? _lastMarkedReadAt;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draftFocus.addListener(_onFocusChanged);
    _scroll.addListener(_onScrollChanged);
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
    await _readSubscription?.cancel();
    _readSubscription = null;
    await _typingService?.dispose();
    _typingService = null;
    _typingDebounce?.cancel();
    _remoteTypingExpiry?.cancel();

    try {
      final cachedChat = _repository.cachedConversation(widget.roomId);
      final cachedMessages = _orderedMessages(
        _repository.cachedMessages(widget.roomId),
      );
      if (mounted) {
        setState(() {
          _chat = cachedChat;
          _profiles = const {};
          _messages = cachedMessages;
          _loading = cachedMessages.isEmpty;
          _remoteTyping = false;
          _participantReadAt = null;
          _lastMarkedReadAt = null;
          _unreadNewMessages = 0;
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

      final otherParticipantId = chat.participantId;
      if (otherParticipantId != null && otherParticipantId.isNotEmpty) {
        _readSubscription = _repository
            .watchReadAt(chat.id, otherParticipantId)
            .listen((readAt) {
              if (!mounted || generation != _generation) return;
              setState(() => _participantReadAt = readAt);
            });
      }

      _subscription = _repository
          .watchMessages(widget.roomId)
          .listen(
            (incomingMessages) {
              if (!mounted || generation != _generation) return;
              final messages = _orderedMessages(incomingMessages);
              final wasNearLatest = _isNearLatest;
              final oldIds = _messages.map((message) => message.id).toSet();
              final newIncoming = messages
                  .where(
                    (message) =>
                        !oldIds.contains(message.id) &&
                        message.senderId != _repository.currentUserId,
                  )
                  .length;
              setState(() {
                _messages = messages;
                _loading = false;
                _error = null;
                if (wasNearLatest) {
                  _unreadNewMessages = 0;
                } else {
                  _unreadNewMessages += newIncoming;
                }
              });
              if (wasNearLatest) {
                _scrollToLatest(animate: false);
                _markLatestIncomingRead();
              }
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
    _isAppResumed = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) {
      _typingDebounce?.cancel();
      _typingService?.setLocalTyping(false);
    } else if (_isNearLatest) {
      _markLatestIncomingRead();
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
      _scrollToLatest();
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

  Future<void> _attachImage() async {
    if (_sendingImage || _chat == null) return;
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null || !mounted) return;
      setState(() => _sendingImage = true);
      _typingService?.setLocalTyping(false);
      final persisted = await _repository.sendImage(widget.roomId, image);
      if (!mounted) return;
      setState(() {
        if (!_messages.any((message) => message.id == persisted.id)) {
          _messages = [..._messages, persisted]
            ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
        }
      });
      _scrollToLatest();
    } catch (error) {
      if (mounted) {
        final message = error is ChatFailure
            ? error.message
            : 'No se pudo adjuntar la imagen. Intenta de nuevo.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
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

  bool get _isNearLatest =>
      !_scroll.hasClients || _scroll.position.pixels <= 72;

  void _onScrollChanged() {
    if (!_isNearLatest) return;
    if (_unreadNewMessages > 0 && mounted) {
      setState(() => _unreadNewMessages = 0);
    }
    _markLatestIncomingRead();
  }

  void _markLatestIncomingRead() {
    if (!_isAppResumed || !_isNearLatest || _chat == null) return;
    final currentUserId = _repository.currentUserId;
    ChatMessage? latestIncoming;
    for (final message in _messages.reversed) {
      if (message.senderId != currentUserId) {
        latestIncoming = message;
        break;
      }
    }
    if (latestIncoming == null ||
        (_lastMarkedReadAt != null &&
            !latestIncoming.sentAt.isAfter(_lastMarkedReadAt!))) {
      return;
    }
    final readThrough = latestIncoming.sentAt;
    final chatId = _chat!.id;
    _lastMarkedReadAt = readThrough;
    unawaited(
      _repository.markRead(chatId, readThrough).catchError((_) {
        if (mounted && _lastMarkedReadAt == readThrough) {
          _lastMarkedReadAt = null;
        }
      }),
    );
  }

  void _scrollToLatest({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        if (!animate) {
          _scroll.jumpTo(0);
          return;
        }
        _scroll.animateTo(
          0,
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
    _scroll.removeListener(_onScrollChanged);
    _typingDebounce?.cancel();
    _remoteTypingExpiry?.cancel();
    final activeChatId = _chat?.id;
    if (activeChatId != null) {
      _headerController?.clear();
    }
    _subscription?.cancel();
    _readSubscription?.cancel();
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
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _buildMessages()),
                if (_unreadNewMessages > 0)
                  Positioned(
                    right: 16,
                    bottom: 14,
                    child: FilledButton.tonalIcon(
                      onPressed: _scrollToLatest,
                      icon: const Icon(Icons.south_rounded),
                      label: Text(
                        _unreadNewMessages == 1
                            ? '1 mensaje nuevo'
                            : '$_unreadNewMessages mensajes nuevos',
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
                  IconButton(
                    onPressed: _chat == null || _sendingImage || _sending
                        ? null
                        : _attachImage,
                    tooltip: 'Adjuntar imagen',
                    icon: _sendingImage
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined),
                    color: AppColors.primary,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _draft,
                      focusNode: _draftFocus,
                      enabled: _chat != null && !_sendingImage,
                      maxLength: 2000,
                      minLines: 1,
                      maxLines: 4,
                      onChanged: _onDraftChanged,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje',
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
                    onPressed: _chat == null || _sending || _sendingImage
                        ? null
                        : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.surface,
                    ),
                    icon: _sending || _sendingImage
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

    final timeline = <_ChatTimelineEntry>[];
    for (var index = 0; index < _messages.length; index++) {
      if (index == 0 ||
          !_isSameEcuadorianDay(
            _messages[index - 1].sentAt,
            _messages[index].sentAt,
          )) {
        timeline.add(
          _ChatTimelineEntry.divider(
            index,
            _dateDividerLabel(_messages[index].sentAt),
          ),
        );
      }
      timeline.add(_ChatTimelineEntry.message(index));
    }
    // Mantener el índice cero como mensaje más reciente al fondo del chat.
    final reversedTimeline = timeline.reversed.toList(growable: false);

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      itemCount: reversedTimeline.length,
      itemBuilder: (context, index) {
        final entry = reversedTimeline[index];
        return entry.isDivider
            ? _DateDivider(label: entry.label)
            : _buildMessage(entry.messageIndex);
      },
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
    final metadata = _buildMessageMetadata(message, mine, index);
    final imageWidth = (MediaQuery.sizeOf(context).width * 0.76 - 17)
        .clamp(0.0, 250.0)
        .toDouble();
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
              padding: const EdgeInsets.fromLTRB(7, 7, 10, 7),
              decoration: BoxDecoration(
                color: mine ? AppColors.primarySurface : AppColors.surface,
                borderRadius: radius,
                border: Border.all(
                  color: mine
                      ? AppColors.primarySurface
                      : AppColors.divider.withValues(alpha: .55),
                ),
              ),
              child: message.isImage
                  ? SizedBox(
                      width: imageWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MessageImage(
                            width: imageWidth,
                            imageUrl: message.attachmentUrl,
                            onTap: message.attachmentUrl == null
                                ? null
                                : () => _showImage(message),
                          ),
                          if (message.content.trim().isNotEmpty &&
                              message.content != 'Foto adjunta') ...[
                            const SizedBox(height: 6),
                            Text(
                              message.content,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 3),
                          Align(
                            alignment: Alignment.centerRight,
                            child: metadata,
                          ),
                        ],
                      ),
                    )
                  : IntrinsicWidth(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.content,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 3),
                          Align(
                            alignment: Alignment.centerRight,
                            child: metadata,
                          ),
                        ],
                      ),
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

  Widget _buildMessageMetadata(ChatMessage message, bool mine, int index) {
    final textStyle = Theme.of(context).textTheme.labelSmall;
    final isRead = _isRead(message);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(message.sentAt),
          style: textStyle?.copyWith(color: AppColors.textSecondary),
        ),
        if (mine && _isLastOutgoingMessage(index)) ...[
          const SizedBox(width: 6),
          Text(
            isRead ? 'Leído' : 'Enviado',
            style: textStyle?.copyWith(
              color: isRead ? AppColors.primaryDark : AppColors.textSecondary,
              fontWeight: isRead ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    return ChatTimestampFormatter.time(dateTime);
  }

  List<ChatMessage> _orderedMessages(Iterable<ChatMessage> messages) {
    // La vista depende de este orden y descarta eventos de otra conversación.
    final scoped = messages
        .where((message) => message.chatId == widget.roomId)
        .toList();
    scoped.sort((a, b) {
      final sentAtOrder = a.sentAt.compareTo(b.sentAt);
      return sentAtOrder != 0 ? sentAtOrder : a.id.compareTo(b.id);
    });
    return scoped;
  }

  bool _isLastOutgoingMessage(int index) =>
      _messages.lastIndexWhere(
        (message) => message.senderId == _repository.currentUserId,
      ) ==
      index;

  bool _isRead(ChatMessage message) =>
      _participantReadAt != null &&
      !_participantReadAt!.isBefore(message.sentAt);

  bool _isSameEcuadorianDay(DateTime first, DateTime second) {
    final a = first.toUtc().add(const Duration(hours: -5));
    final b = second.toUtc().add(const Duration(hours: -5));
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dateDividerLabel(DateTime dateTime) {
    final date = dateTime.toUtc().add(const Duration(hours: -5));
    final now = DateTime.now().toUtc().add(const Duration(hours: -5));
    final today = DateTime.utc(now.year, now.month, now.day);
    final day = DateTime.utc(date.year, date.month, date.day);
    if (day == today) return 'Hoy';
    if (day == today.subtract(const Duration(days: 1))) return 'Ayer';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _showImage(ChatMessage message) async {
    final url = message.attachmentUrl;
    if (url == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.textPrimary,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, _) => const Center(
                  child: CircularProgressIndicator(color: AppColors.surface),
                ),
                errorWidget: (_, _, _) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 56,
                    color: AppColors.surface,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.pop(dialogContext),
                tooltip: 'Cerrar imagen',
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTimelineEntry {
  const _ChatTimelineEntry.message(this.messageIndex)
    : isDivider = false,
      label = '';
  const _ChatTimelineEntry.divider(this.messageIndex, this.label)
    : isDivider = true;

  final int messageIndex;
  final bool isDivider;
  final String label;
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider.withValues(alpha: .7)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

class _MessageImage extends StatelessWidget {
  const _MessageImage({
    required this.width,
    required this.imageUrl,
    required this.onTap,
  });
  final double width;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Imagen adjunta al mensaje',
    button: onTap != null,
    child: GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: width,
          height: width * 0.76,
          child: imageUrl == null
              ? const ColoredBox(
                  color: AppColors.surfaceVariant,
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const ColoredBox(
                    color: AppColors.surfaceVariant,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => const ColoredBox(
                    color: AppColors.surfaceVariant,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    ),
  );
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
