import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/constants/app_routes.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/profile_selection_viewmodel.dart';

class ProfileSelectionView extends StatelessWidget {
  const ProfileSelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.read<AuthViewModel>();

    return ChangeNotifierProvider(
      create: (_) => ProfileSelectionViewModel(authViewModel: authViewModel),
      child: const _ProfileSelectionContent(),
    );
  }
}

class _ProfileSelectionContent extends StatelessWidget {
  const _ProfileSelectionContent();

  Future<void> _handleContinue(
    BuildContext context,
    ProfileSelectionViewModel viewModel,
  ) async {
    final success = await viewModel.confirmRoleSelection();
    if (!context.mounted) return;

    if (success) {
      context.go(AppRoutes.home);
    } else if (viewModel.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  viewModel.errorMessage!,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProfileSelectionViewModel>();

    final options = [
      _ProfileOptionData(
        role: UserRole.producer,
        title: 'Productor / Vendedor',
        description: 'Publica cosechas y gestiona la venta de tus productos agricolas directo al mercado.',
        icon: Icons.agriculture_rounded,
      ),
      _ProfileOptionData(
        role: UserRole.buyer,
        title: 'Comprador',
        description: 'Explora ofertas agricolas y conecta con productores cercanos para abastecimiento agil.',
        icon: Icons.shopping_basket_rounded,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: _buildSquircleLogo()),
                  const SizedBox(height: 20),

                  Text(
                    'Bienvenido a Agro+',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.6,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Selecciona tu tipo de perfil para continuar',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 32),

                  ...List.generate(options.length, (index) {
                    final option = options[index];
                    final isSelected = viewModel.selectedRole == option.role;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ProfileSelectableCard(
                        data: option,
                        isSelected: isSelected,
                        onTap: () => viewModel.selectRole(option.role),
                      ),
                    );
                  }),

                  const SizedBox(height: 26),

                  _buildContinueButton(context, viewModel),

                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Conexion protegida y validada por cooperativas',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSquircleLogo() {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Image.asset(
        'assets/images/logotipo_oficial.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.eco_rounded, size: 42, color: AppColors.primary),
      ),
    );
  }

  Widget _buildContinueButton(
    BuildContext context,
    ProfileSelectionViewModel viewModel,
  ) {
    final canContinue = viewModel.hasSelection && !viewModel.isLoading;

    return AnimatedOpacity(
      duration: AppDurations.resolve(context, AppDurations.stateChange),
      opacity: canContinue ? 1.0 : 0.5,
      child: _PressableFeedback(
        enabled: canContinue,
        onTap: canContinue ? () => _handleContinue(context, viewModel) : null,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(100),
            boxShadow: canContinue
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.32),
                      offset: const Offset(0, 6),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: viewModel.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continuar',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ProfileOptionData {
  final UserRole role;
  final String title;
  final String description;
  final IconData icon;

  const _ProfileOptionData({
    required this.role,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _ProfileSelectableCard extends StatefulWidget {
  final _ProfileOptionData data;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProfileSelectableCard({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ProfileSelectableCard> createState() => _ProfileSelectableCardState();
}

class _ProfileSelectableCardState extends State<_ProfileSelectableCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: AppDurations.resolve(context, AppDurations.tapFeedback),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: AppDurations.resolve(context, AppDurations.stateChange),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primarySurface
                  : AppColors.primarySurface.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: isSelected ? 1.8 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : AppColors.primarySurface,
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    widget.data.icon,
                    size: 23,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.data.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.data.description,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AnimatedContainer(
                    duration: AppDurations.resolve(
                      context,
                      AppDurations.stateChange,
                    ),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFFCFD8DC),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: isSelected
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PressableFeedback extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  const _PressableFeedback({
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  @override
  State<_PressableFeedback> createState() => _PressableFeedbackState();
}

class _PressableFeedbackState extends State<_PressableFeedback> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.onTap == null) {
      return widget.child;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedOpacity(
          opacity: _isPressed ? 0.70 : 1.0,
          duration: AppDurations.resolve(context, AppDurations.tapFeedback),
          curve: Curves.easeInOut,
          child: AnimatedScale(
            scale: _isPressed ? 0.98 : 1.0,
            duration: AppDurations.resolve(context, AppDurations.tapFeedback),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
