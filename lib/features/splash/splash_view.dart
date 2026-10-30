import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../auth/presentation/viewmodels/auth_viewmodel.dart';

/// Brand sequence displayed after native launch and before login/home.
class SplashView extends StatefulWidget {
  const SplashView({super.key});
  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  bool _brandGreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 140));
      if (mounted) setState(() => _brandGreen = true);
    });
    _finishSplash();
  }

  Future<void> _finishSplash() async {
    await Future<void>.delayed(const Duration(milliseconds: 2300));
    if (!mounted) return;
    final auth = context.read<AuthViewModel>();
    context.go(auth.isAuthenticated ? AppRoutes.home : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _brandGreen
              ? const [AppColors.primary, AppColors.primaryDark]
              : const [AppColors.surface, AppColors.surface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/logotipo_oficial.png',
                      width: 112,
                      height: 112,
                      fit: BoxFit.contain,
                      cacheWidth: 224,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                )
                .animate()
                .fadeIn(duration: 380.ms, curve: Curves.easeOutCubic)
                .scale(
                  begin: const Offset(.88, .88),
                  end: const Offset(1, 1),
                  duration: 380.ms,
                  curve: Curves.easeOutCubic,
                ),
            const SizedBox(height: 20),
            Text(
                  'Agro+',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.surface,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                )
                .animate(delay: 420.ms)
                .fadeIn(duration: 300.ms)
                .slideY(begin: .08, end: 0),
            const SizedBox(height: 10),
            Text(
                  AppStrings.appTagline,
                  style: GoogleFonts.inter(
                    color: AppColors.surface.withValues(alpha: .92),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                )
                .animate(delay: 580.ms)
                .fadeIn(duration: 280.ms)
                .slideY(begin: .06, end: 0),
            const Spacer(flex: 2),
            SizedBox(
              width: 152,
              child: Column(
                children: [
                  Text(
                    'Cargando…',
                    style: GoogleFonts.inter(
                      color: AppColors.surface.withValues(alpha: .86),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: const LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: AppColors.primaryLight,
                      valueColor: AlwaysStoppedAnimation(AppColors.surface),
                    ),
                  ),
                ],
              ),
            ).animate(delay: 820.ms).fadeIn(duration: 240.ms),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  );
}
