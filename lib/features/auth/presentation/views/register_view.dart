import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../viewmodels/auth_viewmodel.dart';

/// Vista de registro con selección de rol (Productor / Comprador).
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = context.read<AuthViewModel>();
    final success = await viewModel.signUp(
      email: _emailController.text,
      password: _passwordController.text,
      fullName: _nameController.text,
      role: viewModel.selectedRole,
    );

    if (!mounted) return;

    if (success) {
      // Si la sesión ya está activa → Home. Si no → Confirmar email.
      if (viewModel.isAuthenticated) {
        context.go(AppRoutes.home);
      } else {
        _showConfirmationDialog();
      }
    } else {
      _showErrorSnackbar(viewModel.errorMessage ?? AppStrings.genericError);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mark_email_read, color: AppColors.primary),
            SizedBox(width: 8),
            Text('¡Cuenta creada!'),
          ],
        ),
        content: const Text(
          'Te enviamos un correo de confirmación. '
          'Por favor revisa tu bandeja de entrada y activa tu cuenta antes de iniciar sesión.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go(AppRoutes.login);
            },
            child: const Text('Ir al Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => context.go(AppRoutes.login),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Título ──
                Text(
                  'Crea tu cuenta',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Únete a la comunidad agrícola',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),

                // ── Nombre completo ──
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: AppStrings.fullName,
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? AppStrings.fieldRequired
                      : null,
                ),
                const SizedBox(height: 16),

                // ── Email ──
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: AppStrings.email,
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return AppStrings.fieldRequired;
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                      return AppStrings.emailInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Contraseña ──
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: AppStrings.password,
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return AppStrings.fieldRequired;
                    if (v.length < 6) return AppStrings.passwordMin;
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Confirmar contraseña ──
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: AppStrings.confirmPassword,
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return AppStrings.fieldRequired;
                    if (v != _passwordController.text) {
                      return AppStrings.passwordsNoMatch;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ── Selección de rol ──
                Text(
                  AppStrings.selectRole,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                Consumer<AuthViewModel>(
                  builder: (context, viewModel, _) {
                    return Row(
                      children: [
                        _RoleChip(
                          label: AppStrings.roleProducer,
                          icon: Icons.agriculture,
                          role: UserRole.producer,
                          selectedRole: viewModel.selectedRole,
                          onTap: () => viewModel.setRole(UserRole.producer),
                        ),
                        const SizedBox(width: 12),
                        _RoleChip(
                          label: AppStrings.roleBuyer,
                          icon: Icons.shopping_basket_outlined,
                          role: UserRole.buyer,
                          selectedRole: viewModel.selectedRole,
                          onTap: () => viewModel.setRole(UserRole.buyer),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),

                // ── Botón registrar ──
                Consumer<AuthViewModel>(
                  builder: (context, viewModel, _) {
                    return ElevatedButton(
                      onPressed: viewModel.isLoading ? null : _handleRegister,
                      child: viewModel.isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(AppStrings.register),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // ── Ya tengo cuenta ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      AppStrings.alreadyAccount,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.login),
                      child: const Text(AppStrings.login),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Widget auxiliar: chip de selección de rol
// -----------------------------------------------------------------------------
class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final UserRole role;
  final UserRole selectedRole;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.role,
    required this.selectedRole,
    required this.onTap,
  });

  bool get _isSelected => role == selectedRole;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color:
                _isSelected ? AppColors.primary : AppColors.primarySurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isSelected
                  ? AppColors.primary
                  : AppColors.divider,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: _isSelected ? Colors.white : AppColors.primary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _isSelected ? Colors.white : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

