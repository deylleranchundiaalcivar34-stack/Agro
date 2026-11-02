import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../viewmodels/auth_viewmodel.dart';

/// Vista para solicitar la recuperación de contraseña por correo electrónico.
/// Conecta con Supabase Auth a través de [AuthViewModel.resetPasswordForEmail].
class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthViewModel>();
    final success = await auth.resetPasswordForEmail(_emailController.text);

    if (!mounted) return;

    if (success) {
      setState(() => _emailSent = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'No se pudo enviar el correo.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
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
                  // Cabecera verde con botón de volver y logotipo/icono
                  SizedBox(
                    height: headerHeight,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 8,
                          left: 8,
                          child: IconButton(
                            tooltip: 'Volver al inicio de sesión',
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
                                  color: AppColors.surface.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lock_reset_rounded,
                                  size: 38,
                                  color: AppColors.surface,
                                ),
                              )
                                  .animate()
                                  .fadeIn(duration: 260.ms)
                                  .scale(begin: const Offset(.9, .9)),
                              const SizedBox(height: 12),
                              Text(
                                'Recuperar contraseña',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.surface,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ).animate(delay: 80.ms).fadeIn(duration: 220.ms),
                              const SizedBox(height: 4),
                              Text(
                                'Te ayudaremos a restablecer tu acceso',
                                style: GoogleFonts.inter(
                                  color: AppColors.surface.withValues(alpha: 0.9),
                                  fontSize: 13,
                                ),
                              ).animate(delay: 130.ms).fadeIn(duration: 220.ms),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tarjeta inferior curva blanca
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
                          child: _emailSent
                              ? _buildSuccessView()
                              : _buildRequestForm(),
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ingresa tu correo electrónico',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enviaremos un enlace para que puedas definir una nueva contraseña de forma segura.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 24),

          // Campo de correo
          Text(
            'Correo electrónico',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'ejemplo@agro.com',
              prefixIcon: const Icon(Icons.mail_outline_rounded),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.inputFocused, width: 2),
              ),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return 'Ingresa tu correo electrónico.';
              return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)
                  ? null
                  : 'Ingresa un correo electrónico válido.';
            },
          ),
          const SizedBox(height: 28),

          // Botón de enviar
          Consumer<AuthViewModel>(
            builder: (context, auth, _) => FilledButton(
              onPressed: auth.isLoading ? null : _submit,
              child: auth.isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.surface,
                      ),
                    )
                  : const Text('Enviar enlace de recuperación'),
            ),
          ),
          const SizedBox(height: 16),

          // Botón volver
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('Volver al inicio de sesión'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.03, end: 0);
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 44,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '¡Revisa tu bandeja de entrada!',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Hemos enviado un correo a:\n${_emailController.text}\n\nSigue las instrucciones del enlace recibido para actualizar tu contraseña.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => context.go(AppRoutes.login),
          child: const Text('Volver al inicio de sesión'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _emailSent = false),
          child: const Text('¿No te llegó el correo? Reintentar'),
        ),
      ],
    ).animate().fadeIn(duration: 260.ms).scale(begin: const Offset(0.96, 0.96));
  }
}
