import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../auth/presentation/viewmodels/auth_viewmodel.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key, this.autoNavigate = true});

  final bool autoNavigate;
  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    if (widget.autoNavigate) _finishSplash();
  }

  Future<void> _finishSplash() async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    final auth = context.read<AuthViewModel>();
    context.go(auth.isAuthenticated ? AppRoutes.home : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.primary,
    body: ColoredBox(
      color: AppColors.primary,
      child: SafeArea(
        child: SizedBox.expand(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RepaintBoundary(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/images/logotipo_oficial.png',
                                width: 96,
                                height: 96,
                                fit: BoxFit.contain,
                                cacheWidth: 192,
                                filterQuality: FilterQuality.low,
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 240.ms, curve: Curves.easeOut)
                          .scale(
                            begin: const Offset(.88, .88),
                            end: const Offset(1, 1),
                            duration: 240.ms,
                            curve: Curves.easeOut,
                          ),
                      const SizedBox(height: 20),
                      Text(
                        'Agro+',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.surface,
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ).animate(delay: 100.ms).fadeIn(duration: 200.ms),
                      const SizedBox(height: 10),
                      Text(
                        AppStrings.appTagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.surface.withValues(alpha: .92),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ).animate(delay: 180.ms).fadeIn(duration: 180.ms),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: SizedBox(
                    width: 152,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Cargando…',
                          style: TextStyle(
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
                            valueColor: AlwaysStoppedAnimation(
                              AppColors.surface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate(delay: 260.ms).fadeIn(duration: 160.ms),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
