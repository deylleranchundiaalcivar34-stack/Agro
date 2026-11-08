import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/password_rules.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});
  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _company = TextEditingController();
  int _step = 0;
  bool _showPassword = false;
  bool _showConfirmation = false;
  String _passwordValue = '';

  void _onPasswordChanged() {
    setState(() => _passwordValue = _password.text);
  }

  @override
  void dispose() {
    _password.removeListener(_onPasswordChanged);
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    _company.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _password.addListener(_onPasswordChanged);
  }

  bool _validateFirstStep() =>
      _name.text.trim().isNotEmpty && _validEmail(_email.text);

  void togglePasswordVisibility() {
    setState(() => _showPassword = !_showPassword);
  }

  void toggleConfirmationVisibility() {
    setState(() => _showConfirmation = !_showConfirmation);
  }

  void returnToIdentityStep() {
    setState(() => _step = 0);
  }

  Future<void> _next() async {
    if (!_validateFirstStep()) {
      _formKey.currentState!.validate();
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthViewModel>();
    final created = await auth.signUp(
      email: _email.text,
      password: _password.text,
      fullName: _name.text,
      role: auth.selectedRole,
      companyName: _company.text,
    );
    if (!mounted) return;
    if (created && auth.isAuthenticated) {
      context.go(AppRoutes.home);
    } else if (created) {
      _confirmationDialog();
    } else {
      _showError(auth.errorMessage ?? 'No se pudo crear la cuenta.');
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.error,
    ),
  );
  void _confirmationDialog() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Revisa tu correo'),
      content: const Text(
        'Enviamos un enlace para confirmar tu cuenta antes de ingresar.',
      ),
      actions: [
        TextButton(
          onPressed: () => context.go(AppRoutes.login),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.primary,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                _Header(
                  step: _step,
                  onBack: _step == 1
                      ? () => setState(() => _step = 0)
                      : () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AppRoutes.login);
                          }
                        },
                ),
                Transform.translate(
                  offset: const Offset(0, -14),
                  child: _FormSheet(
                    minHeight: constraints.maxHeight - 142,
                    child: Form(
                      key: _formKey,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(.04, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: _step == 0
                            ? _IdentityStep(key: const ValueKey(0), state: this)
                            : _SecurityStep(
                                key: const ValueKey(1),
                                state: this,
                              ),
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

class _Header extends StatelessWidget {
  const _Header({required this.step, required this.onBack});
  final int step;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 158,
    child: Stack(
      children: [
        Positioned(
          top: 4,
          left: 8,
          child: IconButton(
            tooltip: step == 0
                ? 'Volver al inicio de sesion'
                : 'Volver al paso anterior',
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.surface,
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step == 0 ? 'Crea tu cuenta' : 'Protege tu cuenta',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.surface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step == 0
                    ? 'Elige tu perfil y tus datos basicos.'
                    : 'Un ultimo paso y estaras listo.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.surface),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FormSheet extends StatelessWidget {
  const _FormSheet({required this.minHeight, required this.child});
  final double minHeight;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: BoxConstraints(minHeight: minHeight),
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: child,
      ),
    ),
  );
}

class _IdentityStep extends StatelessWidget {
  const _IdentityStep({super.key, required this.state});
  final _RegisterViewState state;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Progress(active: 0),
      const SizedBox(height: 20),
      Text(
        '¿Como usaras Agro+?',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        'Solo se muestran perfiles disponibles para registro publico.',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      Consumer<AuthViewModel>(
        builder: (context, auth, _) => Row(
          children: [
            Expanded(
              child: _RoleCard(
                role: UserRole.producer,
                selected: auth.selectedRole,
                icon: Icons.agriculture_outlined,
                title: 'Productor',
                subtitle: 'Publico mis lotes',
                onTap: () => auth.setRole(UserRole.producer),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RoleCard(
                role: UserRole.buyer,
                selected: auth.selectedRole,
                icon: Icons.shopping_basket_outlined,
                title: 'Comprador',
                subtitle: 'Encuentro preventas',
                onTap: () => auth.setRole(UserRole.buyer),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const _Label('Nombre completo'),
      const SizedBox(height: 6),
      TextFormField(
        controller: state._name,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        decoration: _field('Nombre y apellido', Icons.person_outline_rounded),
        validator: state._required,
      ),
      const SizedBox(height: 14),
      const _Label('Correo electronico'),
      const SizedBox(height: 6),
      TextFormField(
        controller: state._email,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        decoration: _field('ejemplo@agro.com', Icons.mail_outline_rounded),
        validator: state._emailValidator,
      ),
      const SizedBox(height: 24),
      FilledButton(onPressed: state._next, child: const Text('Continuar')),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => context.go(AppRoutes.login),
        child: const Text('Ya tengo una cuenta'),
      ),
    ],
  ).animate().fadeIn(duration: 220.ms).slideY(begin: .025, end: 0);
}

class _SecurityStep extends StatelessWidget {
  const _SecurityStep({super.key, required this.state});
  final _RegisterViewState state;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Progress(active: 1),
      const SizedBox(height: 20),
      Text(
        'Crea una contrasena',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        'Usa una contrasena fuerte para proteger tu cuenta.',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 20),
      const _Label('Contrasena'),
      const SizedBox(height: 6),
      TextFormField(
        controller: state._password,
        obscureText: !state._showPassword,
        textInputAction: TextInputAction.next,
        decoration: _passwordField(
          'Crea una contrasena segura',
          state._showPassword,
          state.togglePasswordVisibility,
        ),
        validator: state._passwordValidator,
      ),
      const SizedBox(height: 8),
      PasswordRulesView(password: state._passwordValue),
      const SizedBox(height: 14),
      const _Label('Confirmar contrasena'),
      const SizedBox(height: 6),
      TextFormField(
        controller: state._confirmation,
        obscureText: !state._showConfirmation,
        textInputAction: TextInputAction.next,
        decoration: _passwordField(
          'Repite tu contrasena',
          state._showConfirmation,
          state.toggleConfirmationVisibility,
        ),
        validator: (value) => value == state._password.text
            ? null
            : 'Las contrasenas no coinciden.',
      ),
      const SizedBox(height: 14),
      Consumer<AuthViewModel>(
        builder: (context, auth, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Label(
              auth.selectedRole == UserRole.producer
                  ? 'Finca o empresa (opcional)'
                  : 'Empresa o negocio (opcional)',
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: state._company,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => state._submit(),
              decoration: _field(
                'Ej. Finca La Esperanza',
                Icons.business_outlined,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Consumer<AuthViewModel>(
        builder: (context, auth, _) => FilledButton(
          onPressed: auth.isLoading ? null : state._submit,
          child: auth.isLoading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.surface,
                  ),
                )
              : const Text('Crear cuenta'),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: state.returnToIdentityStep,
        child: const Text('Volver'),
      ),
    ],
  ).animate().fadeIn(duration: 220.ms).slideY(begin: .025, end: 0);
}

class _Progress extends StatelessWidget {
  const _Progress({required this.active});
  final int active;
  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(
      2,
      (i) => Expanded(
        child: Container(
          height: 4,
          margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
          decoration: BoxDecoration(
            color: i <= active ? AppColors.primary : AppColors.divider,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    ),
  );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final UserRole role;
  final UserRole selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final active = role == selected;
    return Semantics(
      button: true,
      selected: active,
      label: 'Seleccionar $title',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 108,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? AppColors.primarySurface : AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.inputBorder,
              width: active ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: active ? AppColors.primaryDark : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
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

InputDecoration _field(String hint, IconData icon) => InputDecoration(
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
InputDecoration _passwordField(String hint, bool visible, VoidCallback onTap) =>
    _field(hint, Icons.lock_outline_rounded).copyWith(
      suffixIcon: IconButton(
        tooltip: visible ? 'Ocultar contrasena' : 'Mostrar contrasena',
        onPressed: onTap,
        icon: Icon(
          visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
    );

extension on _RegisterViewState {
  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Este campo es obligatorio.'
      : null;
  String? _emailValidator(String? value) =>
      _validEmail(value ?? '') ? null : 'Ingresa un correo valido.';
  String? _passwordValidator(String? value) =>
      PasswordRules.from(value ?? '').isStrong
      ? null
      : 'Completa todos los requisitos de la contrasena.';
}

bool _validEmail(String value) =>
    RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim());
