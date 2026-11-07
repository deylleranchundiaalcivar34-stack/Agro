import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../viewmodels/auth_viewmodel.dart';

class MfaChallengeView extends StatefulWidget {
  const MfaChallengeView({super.key});

  @override
  State<MfaChallengeView> createState() => _MfaChallengeViewState();
}

class _MfaChallengeViewState extends State<MfaChallengeView> {
  final _code = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() => _loading = true);
    final ok = await context.read<AuthViewModel>().verifyCurrentTotp(
      _code.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      context.go(AppRoutes.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Codigo no valido. Intenta otra vez.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.phonelink_lock_rounded,
                  color: AppColors.primary,
                  size: 56,
                ),
                const SizedBox(height: 16),
                Text(
                  'Verificacion en dos pasos',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Abre Google Authenticator y escribe el codigo de seis digitos.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'Codigo de 6 digitos',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _loading ? null : _verify,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verificar'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          await context.read<AuthViewModel>().signOut();
                          if (context.mounted) context.go(AppRoutes.login);
                        },
                  child: const Text('Cerrar sesion'),
                ),
              ],
            ).animate().fadeIn(duration: 350.ms).slideY(begin: .04),
          ),
        ),
      ),
    );
  }
}
