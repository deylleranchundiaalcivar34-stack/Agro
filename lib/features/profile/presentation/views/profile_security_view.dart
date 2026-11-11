import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../auth/presentation/widgets/password_rules.dart';
import '../../data/services/local_biometric_lock.dart';
import '../widgets/profile_subpage.dart';

class ProfileSecurityView extends StatefulWidget {
  const ProfileSecurityView({super.key});

  @override
  State<ProfileSecurityView> createState() => _ProfileSecurityViewState();
}

class _ProfileSecurityViewState extends State<ProfileSecurityView> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _updatingBiometrics = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final lock = context.watch<LocalBiometricLock>();
    final userId = auth.currentUser?.id;
    return ProfileSubpage(
      title: 'Seguridad',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Card(
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: AppColors.divider.withValues(alpha: .7)),
            ),
            child: SwitchListTile.adaptive(
              value: userId != null && lock.userId == userId && lock.enabled,
              onChanged: _updatingBiometrics || userId == null
                  ? null
                  : (enabled) => _setBiometricLock(userId, enabled),
              activeThumbColor: AppColors.primary,
              secondary: const Icon(
                Icons.fingerprint_rounded,
                color: AppColors.primary,
                size: 28,
              ),
              title: const Text(
                'Desbloqueo biometrico',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Agro+ pedira la seguridad del celular cuando vuelvas a la app.',
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Cambiar contrasena',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _currentPassword,
                  obscureText: _obscureCurrent,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Contrasena actual',
                    suffixIcon: IconButton(
                      tooltip: _obscureCurrent
                          ? 'Mostrar contrasena'
                          : 'Ocultar contrasena',
                      onPressed: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Escribe tu contrasena actual.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _newPassword,
                  obscureText: _obscureNew,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Nueva contrasena',
                    suffixIcon: IconButton(
                      tooltip: _obscureNew
                          ? 'Mostrar contrasena'
                          : 'Ocultar contrasena',
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => PasswordRules.from(value ?? '').isStrong
                      ? null
                      : 'Completa todos los requisitos de la contrasena.',
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PasswordRulesView(password: _newPassword.text),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmPassword,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contrasena nueva',
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirm
                          ? 'Mostrar contrasena'
                          : 'Ocultar contrasena',
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => value != _newPassword.text
                      ? 'Las contrasenas no coinciden.'
                      : null,
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _saving ? null : _changePassword,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.surface,
                          ),
                        )
                      : const Icon(Icons.key_rounded),
                  label: Text(
                    _saving ? 'Actualizando' : 'Actualizar contrasena',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await context.read<AuthViewModel>().changePassword(
      currentPassword: _currentPassword.text,
      newPassword: _newPassword.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Tu contrasena se actualizo. Sigues dentro de Agro+.'
              : context.read<AuthViewModel>().errorMessage ??
                    'No se pudo actualizar la contrasena.',
        ),
      ),
    );
    if (ok) {
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      setState(() {});
    }
  }

  Future<void> _setBiometricLock(String userId, bool enabled) async {
    setState(() => _updatingBiometrics = true);
    final service = context.read<LocalBiometricLock>();
    if (enabled) {
      final result = await service.enableForUser(userId);
      if (!mounted) return;
      final message = switch (result) {
        BiometricSetupResult.enabled => 'Bloqueo del celular activado.',
        BiometricSetupResult.unavailable =>
          'Configura una huella, rostro o PIN en tu celular primero.',
        BiometricSetupResult.canceled => 'No se activo el bloqueo.',
        BiometricSetupResult.failed => 'No se pudo activar la seguridad local.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } else {
      await service.disableForUser(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bloqueo del celular desactivado.')),
        );
      }
    }
    if (mounted) setState(() => _updatingBiometrics = false);
  }
}
