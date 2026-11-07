import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_service.dart';
import '../../data/models/chat_conversation.dart';
import '../../data/models/chat_message.dart';
import '../../data/repositories/chat_repository.dart';

class ChatRoomView extends StatefulWidget {
  const ChatRoomView({super.key, required this.roomId, this.repository});
  final String roomId;
  final ChatRepository? repository;
  @override
  State<ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<ChatRoomView> {
  late final ChatRepository _repository =
      widget.repository ?? ChatRepository(supabaseService: SupabaseService());
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<List<ChatMessage>>? _subscription;
  ChatConversation? _chat;
  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await _subscription?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chat = await _repository.get(widget.roomId);
      if (!mounted) return;
      if (chat == null) {
        setState(() {
          _error = 'No tienes acceso a esta conversacion.';
          _loading = false;
        });
        return;
      }
      setState(() => _chat = chat);
      _subscription = _repository
          .watchMessages(widget.roomId)
          .listen(
            (messages) {
              if (!mounted) return;
              setState(() {
                _messages = messages;
                _loading = false;
              });
              _scrollToBottom();
            },
            onError: (Object _) {
              if (mounted) {
                setState(() {
                  _error = 'No se pudieron cargar los mensajes.';
                  _loading = false;
                });
              }
            },
          );
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo abrir esta conversacion.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _send() async {
    if (_sending || _draft.text.trim().isEmpty) return;
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: Text(_chat?.productName ?? 'Conversacion')),
    body: _loading
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
                  onPressed: _start,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          )
        : Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.forum_outlined,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Aun no hay mensajes. Saluda para empezar.',
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final mine =
                              message.senderId == _repository.currentUserId;
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * 0.75,
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: mine
                                    ? AppColors.primarySurface
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    message.content,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${message.sentAt.hour.toString().padLeft(2, '0')}:'
                                    '${message.sentAt.minute.toString().padLeft(2, '0')}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _draft,
                          maxLength: 2000,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Escribe un mensaje',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : const Icon(Icons.send),
                        color: AppColors.primary,
                        tooltip: 'Enviar mensaje',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );
}
