import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  bool _isOpening = false;

  Future<void> _openRecoveryPage() async {
    if (_isOpening) return;
    setState(() => _isOpening = true);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(AppConstants.passwordRecoveryUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() => _isOpening = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la pagina de recuperacion.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const headerHeight = 220.0;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  SizedBox(
                    height: headerHeight,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 8,
                          left: 8,
                          child: IconButton(
                            tooltip: 'Volver al inicio de sesion',
                            onPressed: () => context.go(AppRoutes.login),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: AppColors.surface,
                            ),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: AppColors.surface.withValues(
                                    alpha: 0.15,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lock_reset_rounded,
                                  size: 38,
                                  color: AppColors.surface,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Recuperar contrasena',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.surface,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Te ayudaremos a restablecer tu acceso',
                                style: GoogleFonts.inter(
                                  color: AppColors.surface.withValues(
                                    alpha: 0.9,
                                  ),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - headerHeight + 20,
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: _buildRequestForm(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Continua en el navegador',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Para validar el enlace de forma segura, solicita la recuperacion y abre el correo desde el mismo navegador.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _isOpening ? null : _openRecoveryPage,
          icon: _isOpening
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.surface,
                  ),
                )
              : const Icon(Icons.open_in_browser_rounded),
          label: Text(_isOpening ? 'Abriendo...' : 'Continuar en navegador'),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => context.go(AppRoutes.login),
          child: const Text('Volver al inicio de sesion'),
        ),
      ],
    );
  }
}
