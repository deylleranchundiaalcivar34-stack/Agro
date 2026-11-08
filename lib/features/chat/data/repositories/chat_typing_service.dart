import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_service.dart';

class ChatTypingService {
  ChatTypingService({required SupabaseService supabaseService})
    : _service = supabaseService;

  final SupabaseService _service;
  RealtimeChannel? _channel;
  Timer? _inactiveTimer;
  void Function(bool isTyping)? _onRemoteTyping;
  bool _isSubscribed = false;
  bool _localTyping = false;
  bool? _pendingState;
  bool _disposed = false;

  void connect({
    required String chatId,
    required void Function(bool isTyping) onRemoteTyping,
  }) {
    _onRemoteTyping = onRemoteTyping;
    final channel = _service.client.channel(
      'agro-chat:$chatId:typing',
      opts: const RealtimeChannelConfig(private: true),
    );
    _channel = channel;
    channel
        .onBroadcast(
          event: 'typing',
          callback: (event) {
            final data = event['payload'] is Map
                ? Map<String, dynamic>.from(event['payload'] as Map)
                : event;
            if (data['user_id'] == _service.currentUser?.id) return;
            _onRemoteTyping?.call(data['is_typing'] == true);
          },
        )
        .subscribe((status, _) {
          _isSubscribed = status == RealtimeSubscribeStatus.subscribed;
          if (_isSubscribed && _pendingState != null) {
            final pending = _pendingState!;
            _pendingState = null;
            unawaited(_sendTyping(pending));
          }
        });
  }

  void setLocalTyping(bool isTyping) {
    if (_disposed || _channel == null) return;
    _inactiveTimer?.cancel();
    if (isTyping) {
      _inactiveTimer = Timer(const Duration(seconds: 5), () {
        unawaited(setLocalTypingAsync(false));
      });
    }
    if (_localTyping == isTyping) return;
    _localTyping = isTyping;
    if (!_isSubscribed) {
      _pendingState = isTyping;
      return;
    }
    unawaited(_sendTyping(isTyping));
  }

  Future<void> setLocalTypingAsync(bool isTyping) async {
    if (_disposed || _channel == null) return;
    _inactiveTimer?.cancel();
    if (_localTyping == isTyping) return;
    _localTyping = isTyping;
    if (!_isSubscribed) {
      _pendingState = isTyping;
      return;
    }
    await _sendTyping(isTyping);
  }

  Future<void> _sendTyping(bool isTyping) async {
    final channel = _channel;
    final userId = _service.currentUser?.id;
    if (channel == null || userId == null || !_isSubscribed || _disposed) {
      return;
    }
    try {
      await channel.sendBroadcastMessage(
        event: 'typing',
        payload: {'user_id': userId, 'is_typing': isTyping},
      );
    } catch (_) {
      // Typing is best-effort; message delivery does not depend on it.
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _inactiveTimer?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel == null) return;
    final userId = _service.currentUser?.id;
    if (_localTyping && userId != null && _isSubscribed) {
      try {
        await channel.sendBroadcastMessage(
          event: 'typing',
          payload: {'user_id': userId, 'is_typing': false},
        );
      } catch (_) {
        // A disconnect will also clear remote typing after its expiry window.
      }
    }
    _onRemoteTyping = null;
    await channel.unsubscribe();
  }
}
