import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/supabase_service.dart';

typedef PushNotificationTap = void Function(Map<String, dynamic> data);
typedef PushForegroundNotification = void Function(RemoteMessage message);

class PushNotificationsService {
  PushNotificationsService._();

  static final PushNotificationsService instance = PushNotificationsService._();

  SupabaseService? _supabase;
  PushNotificationTap? _onTap;
  PushForegroundNotification? _onForegroundNotification;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _registeredInstallationId;
  bool _initialized = false;

  bool get _supportsFcm =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize({
    required PushNotificationTap onTap,
    required PushForegroundNotification onForegroundNotification,
  }) async {
    if (!_supportsFcm || _initialized || Firebase.apps.isEmpty) return;
    _initialized = true;
    _supabase = SupabaseService();
    _onTap = onTap;
    _onForegroundNotification = onForegroundNotification;

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      (message) => _onForegroundNotification?.call(message),
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _onTap?.call(message.data),
    );
    _authSubscription = _supabase!.authStateChanges.listen((state) {
      if (state.session != null) unawaited(_registerCurrentDevice());
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _onTap?.call(initialMessage.data);
    if (_supabase!.currentUser != null) await _registerCurrentDevice();
  }

  Future<void> _registerCurrentDevice() async {
    final supabase = _supabase;
    final user = supabase?.currentUser;
    if (!_supportsFcm || !_initialized || user == null) return;

    try {
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;

      _tokenSubscription ??= messaging.onRegistered.listen((installationId) {
        _registeredInstallationId = installationId;
        final currentUser = _supabase?.currentUser;
        if (currentUser != null) {
          unawaited(_saveToken(installationId, currentUser.id));
        }
      });
      await messaging.register();
    } catch (error) {
      debugPrint('Agro+ no pudo registrar notificaciones push: $error');
    }
  }

  Future<void> _saveToken(String token, String userId) async {
    await _supabase!.client.from('dispositivos_fcm').upsert({
      'id_usuario': userId,
      'token': token,
      'plataforma': 'android',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id_usuario,token');
  }

  Future<void> unregisterCurrentDevice() async {
    final supabase = _supabase;
    final user = supabase?.currentUser;
    if (!_supportsFcm || user == null || Firebase.apps.isEmpty) return;
    try {
      final installationId = _registeredInstallationId;
      if (installationId == null || installationId.isEmpty) return;
      await FirebaseMessaging.instance.unregister();
      await supabase!.client
          .from('dispositivos_fcm')
          .delete()
          .eq('id_usuario', user.id)
          .eq('token', installationId);
      _registeredInstallationId = null;
    } catch (error) {
      debugPrint('Agro+ no pudo desvincular el dispositivo push: $error');
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    _initialized = false;
  }
}

@pragma('vm:entry-point')
Future<void> agroFcmBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
}
