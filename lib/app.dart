import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/constants/app_routes.dart';
import 'core/behavior/agro_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'features/profile/presentation/widgets/biometric_lock_gate.dart';
import 'core/notifications/push_notifications_service.dart';

class AgroApp extends StatefulWidget {
  const AgroApp({super.key});

  static const String entryLocation = AppRoutes.welcome;

  @override
  State<AgroApp> createState() => _AgroAppState();
}

class _AgroAppState extends State<AgroApp> {
  late final AppRouter _appRouter;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    final authViewModel = context.read<AuthViewModel>();
    _appRouter = AppRouter(
      authViewModel: authViewModel,
      initialLocation: AgroApp.entryLocation,
    );
    unawaited(
      PushNotificationsService.instance
          .initialize(
            onTap: _handlePushTap,
            onForegroundNotification: _showForegroundNotification,
          )
          .catchError((Object error) {
            debugPrint('Agro+ no pudo iniciar las notificaciones: $error');
          }),
    );
    _linkSubscription = AppLinks().uriLinkStream.listen(_openEmailConfirmed);
  }

  void _handlePushTap(Map<String, dynamic> data) {
    if (!mounted) return;
    final kind = data['kind']?.toString();
    if (kind == 'contact_request' || kind == 'contact_response') {
      _appRouter.router.go(AppRoutes.contactRequests);
    } else if (kind == 'message') {
      final chatId = data['chat_id']?.toString();
      if (chatId != null && chatId.isNotEmpty) {
        _appRouter.router.go('${AppRoutes.chatList}/$chatId');
      }
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final title = message.notification?.title ?? 'Novedad en Agro+';
    final body = message.notification?.body ?? 'Tienes una nueva notificacion.';
    _scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          content: Row(
            children: [
              const Icon(Icons.notifications_active_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => _handlePushTap(message.data),
          ),
        ),
      );
  }

  Future<void> _openEmailConfirmed(Uri uri) async {
    if (uri.scheme != 'io.supabase.agro' || uri.host != 'auth') return;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (mounted) _appRouter.router.go(AppRoutes.emailConfirmed);
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    unawaited(PushNotificationsService.instance.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Agro+',
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scrollBehavior: const AgroScrollBehavior(),
      routerConfig: _appRouter.router,
      builder: (context, child) =>
          BiometricLockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
