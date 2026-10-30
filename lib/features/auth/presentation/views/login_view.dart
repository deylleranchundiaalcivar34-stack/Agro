import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../viewmodels/auth_viewmodel.dart';

/// Single sign-in surface. Administrative access verifies an existing role;
/// it never creates or elevates a user from the client.
class LoginView extends StatefulWidget {
  const LoginView({super.key, this.adminOnly = false});
  final bool adminOnly;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthViewModel>();
    final signedIn = await auth.signIn(
      email: _email.text,
      password: _password.text,
    );
    if (!mounted) return;

    if (!signedIn) {
      _showMessage(auth.errorMessage ?? 'No se pudo iniciar sesión.');
      return;
    }
    if (widget.adminOnly && auth.selectedRole != UserRole.admin) {
      await auth.signOut();
      if (mounted) {
        _showMessage('Esta cuenta no tiene acceso administrativo.');
      }
      return;
    }
    context.go(AppRoutes.home);
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );

  @override
  Widget build(BuildContext context) {
    const headerHeight = 236.0;
    final title = widget.adminOnly ? 'Acceso administrativo' : 'Iniciar sesión';
    final subtitle = widget.adminOnly
        ? 'Ingresa con la cuenta asignada por Agro+'
        : 'Ingresa con tu correo y contraseña';
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                              width: 72,
                              height: 72,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Image.asset(
                                'assets/images/logotipo_oficial.png',
                                fit: BoxFit.contain,
                                cacheWidth: 144,
                                filterQuality: FilterQuality.medium,
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 260.ms)
                            .scale(begin: const Offset(.92, .92)),
                        const SizedBox(height: 14),
                        Text(
                          widget.adminOnly ? 'AGRO+ ADMIN' : 'Agro+',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.surface,
                            fontSize: widget.adminOnly ? 24 : 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ).animate(delay: 80.ms).fadeIn(duration: 220.ms),
                        if (!widget.adminOnly) ...[
                          const SizedBox(height: 4),
                          Text(
                            AppStrings.appTagline,
                            style: GoogleFonts.inter(
                              color: AppColors.surface,
                              fontSize: 14,
                            ),
                          ).animate(delay: 130.ms).fadeIn(duration: 220.ms),
                        ],
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -20),
                    child:
                        Container(
                              width: double.infinity,
                              constraints: BoxConstraints(
                                minHeight:
                                    constraints.maxHeight - headerHeight + 20,
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                24,
                                24,
                                32,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(28),
                                ),
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Center(
                                          child: Container(
                                            width: 40,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: AppColors.divider,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          subtitle,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                        const SizedBox(height: 28),
                                        _Label('Correo electrónico'),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _email,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction: TextInputAction.next,
                                          decoration: _decoration(
                                            'ejemplo@agro.com',
                                            Icons.mail_outline_rounded,
                                          ),
                                          validator: _emailValidator,
                                        ),
                                        const SizedBox(height: 16),
                                        _Label('Contraseña'),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _password,
                                          obscureText: _obscurePassword,
                                          textInputAction: TextInputAction.done,
                                          onFieldSubmitted: (_) => _submit(),
                                          decoration:
                                              _decoration(
                                                '••••••••',
                                                Icons.lock_outline_rounded,
                                              ).copyWith(
                                                suffixIcon: IconButton(
                                                  tooltip: _obscurePassword
                                                      ? 'Mostrar contraseña'
                                                      : 'Ocultar contraseña',
                                                  onPressed: () => setState(
                                                    () => _obscurePassword =
                                                        !_obscurePassword,
                                                  ),
                                                  icon: Icon(
                                                    _obscurePassword
                                                        ? Icons
                                                              .visibility_outlined
                                                        : Icons
                                                              .visibility_off_outlined,
                                                  ),
                                                ),
                                              ),
                                          validator: (value) =>
                                              value == null || value.length < 6
                                              ? 'Ingresa una contraseña válida.'
                                              : null,
                                        ),
                                        const SizedBox(height: 28),
                                        Consumer<AuthViewModel>(
                                          builder: (context, auth, _) =>
                                              FilledButton(
                                                onPressed: auth.isLoading
                                                    ? null
                                                    : _submit,
                                                child: auth.isLoading
                                                    ? const SizedBox.square(
                                                        dimension: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color: AppColors
                                                                  .surface,
                                                            ),
                                                      )
                                                    : Text(
                                                        widget.adminOnly
                                                            ? 'Verificar acceso'
                                                            : 'Ingresar',
                                                      ),
                                              ),
                                        ),
                                        const SizedBox(height: 20),
                                        if (!widget.adminOnly) ...[
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Text('¿No tienes cuenta? '),
                                              TextButton(
                                                onPressed: () => context.go(
                                                  AppRoutes.register,
                                                ),
                                                child: const Text(
                                                  'Crear cuenta',
                                                ),
                                              ),
                                            ],
                                          ),
                                          TextButton.icon(
                                            onPressed: () => context.go(
                                              '${AppRoutes.login}?mode=admin',
                                            ),
                                            icon: const Icon(
                                              Icons
                                                  .admin_panel_settings_outlined,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'Acceso administrativo',
                                            ),
                                          ),
                                        ] else
                                          TextButton(
                                            onPressed: () =>
                                                context.go(AppRoutes.login),
                                            child: const Text(
                                              'Volver al inicio de sesión',
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .animate(delay: 100.ms)
                            .fadeIn(duration: 260.ms)
                            .slideY(begin: .04, end: 0),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon),
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
  );

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)
        ? null
        : 'Ingresa un correo válido.';
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontWeight: FontWeight.w700),
  );
}
