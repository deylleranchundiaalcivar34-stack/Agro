import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/services/local_biometric_lock.dart';

class BiometricLockGate extends StatefulWidget {
  const BiometricLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends State<BiometricLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _authenticating = false;
  bool _returnedFromBackground = false;
  bool _unlockedForCurrentForeground = false;
  String? _observedUserId;
  bool? _observedEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _returnedFromBackground = true;
      FocusManager.instance.primaryFocus?.unfocus();
      final lock = context.read<LocalBiometricLock>();
      final auth = context.read<AuthViewModel>();
      if (lock.enabled && auth.isAuthenticated) {
        _unlockedForCurrentForeground = false;
        setState(() => _locked = true);
      }
      return;
    }
    if (state == AppLifecycleState.resumed && _returnedFromBackground) {
      _returnedFromBackground = false;
      _authenticateIfNeeded();
    }
  }

  void _syncUser(AuthViewModel auth, LocalBiometricLock lock) {
    final userId = auth.isAuthenticated ? auth.currentUser?.id : null;
    if (userId == _observedUserId) return;
    if (userId != _observedUserId) {
      _observedUserId = userId;
      _observedEnabled = null;
      _locked = false;
      _unlockedForCurrentForeground = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      lock.loadForUser(userId);
    });
  }

  Future<void> _authenticateIfNeeded() async {
    if (_authenticating || !mounted) return;
    final lock = context.read<LocalBiometricLock>();
    final auth = context.read<AuthViewModel>();
    if (!lock.enabled || !auth.isAuthenticated) {
      _unlockedForCurrentForeground = true;
      if (mounted) setState(() => _locked = false);
      return;
    }
    setState(() => _locked = true);
    _authenticating = true;
    final accepted = await lock.authenticate();
    _authenticating = false;
    if (!mounted) return;
    if (accepted) {
      _unlockedForCurrentForeground = true;
      setState(() => _locked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final lock = context.watch<LocalBiometricLock>();
    _syncUser(auth, lock);
    if (_observedEnabled != lock.enabled) {
      _observedEnabled = lock.enabled;
      if (lock.loaded && lock.enabled && auth.isAuthenticated) {
        final alreadyAuthenticatedToEnable = lock.consumeAuthenticatedEnable();
        if (alreadyAuthenticatedToEnable) {
          _unlockedForCurrentForeground = true;
          return widget.child;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _locked = true);
          _authenticateIfNeeded();
        });
      } else if (lock.loaded && !lock.enabled) {
        _locked = false;
      }
    }

    final activeUserId = auth.isAuthenticated ? auth.currentUser?.id : null;
    final loadingPreference =
        activeUserId != null && (lock.userId != activeUserId || !lock.loaded);
    if (auth.isAuthenticated && loadingPreference) {
      return const Material(
        color: AppColors.background,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final shouldLock =
        auth.isAuthenticated &&
        (loadingPreference ||
            (_locked || (lock.enabled && !_unlockedForCurrentForeground)));
    if (!shouldLock) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: shouldLock,
          child: ExcludeFocus(
            excluding: shouldLock,
            child: IgnorePointer(ignoring: shouldLock, child: widget.child),
          ),
        ),
        Material(
          color: AppColors.background,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        color: AppColors.primary,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Agro+ esta protegido',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Confirma tu identidad con la seguridad de tu celular para continuar.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _authenticating ? null : _authenticateIfNeeded,
                      icon: const Icon(Icons.lock_open_rounded),
                      label: const Text('Desbloquear'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await context.read<AuthViewModel>().signOut();
                        if (context.mounted) context.go(AppRoutes.login);
                      },
                      child: const Text('Cerrar sesion'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
