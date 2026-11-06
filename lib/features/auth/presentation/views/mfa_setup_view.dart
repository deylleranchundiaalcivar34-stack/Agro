import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../viewmodels/auth_viewmodel.dart';

class MfaSetupView extends StatefulWidget {
  const MfaSetupView({super.key});

  @override
  State<MfaSetupView> createState() => _MfaSetupViewState();
}

class _MfaSetupViewState extends State<MfaSetupView> {
  final _code = TextEditingController();
  String? _factorId;
  String? _uri;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final result = await context.read<AuthViewModel>().enrollTotp();
    if (!mounted) return;
    setState(() {
      _factorId = result?.id;
      _uri = result?.totp?.uri;
      _loading = false;
    });
  }

  Future<void> _verify() async {
    if (_factorId == null || _code.text.trim().length != 6) return;
    final ok = await context.read<AuthViewModel>().verifyTotp(
      _factorId!,
      _code.text.trim(),
    );
    if (!mounted) return;
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
      appBar: AppBar(title: const Text('Google Authenticator')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _loading
                ? const CircularProgressIndicator()
                : Column(
                    children: [
                      const Icon(
                        Icons.security_rounded,
                        color: AppColors.primary,
                        size: 56,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Protege tu cuenta',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Escanea este codigo con Google Authenticator y escribe los seis numeros.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_uri != null)
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(16),
                          child: QrImageView(data: _uri!, size: 200),
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
                        onPressed: _verify,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                        ),
                        child: const Text('Activar verificacion'),
                      ),
                    ],
                  ).animate().fadeIn(duration: 350.ms).slideY(begin: .04),
          ),
        ),
      ),
    );
  }
}
