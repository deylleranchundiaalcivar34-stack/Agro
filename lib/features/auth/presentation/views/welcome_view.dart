import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/widgets/agro_brand_background.dart';

class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> with WidgetsBindingObserver {
  static const _autoAdvanceInterval = Duration(seconds: 5);
  static const _phraseTransitionDuration = Duration(milliseconds: 260);

  static const _messages = [
    ('Publica tus cosechas y conecta con compradores.', Icons.spa_outlined),
    ('Explora productos de productores agricolas.', Icons.storefront_outlined),
    (
      'Descubre zonas publicas y conversa por chat.',
      Icons.location_on_outlined,
    ),
  ];

  final PageController _pageController = PageController();
  int _pageIndex = 0;
  Timer? _autoAdvanceTimer;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool _isPhrasePointerDown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleAutoAdvance();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _scheduleAutoAdvance();
    } else {
      _autoAdvanceTimer?.cancel();
      _autoAdvanceTimer = null;
    }
  }

  void _scheduleAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
    if (!mounted ||
        _isPhrasePointerDown ||
        _lifecycleState != AppLifecycleState.resumed ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _autoAdvanceTimer = Timer(_autoAdvanceInterval, _advanceAutomatically);
  }

  void _pauseAutoAdvanceForTouch() {
    _isPhrasePointerDown = true;
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
  }

  void _resumeAutoAdvanceAfterTouch() {
    _isPhrasePointerDown = false;
    _scheduleAutoAdvance();
  }

  void _advanceAutomatically() {
    if (!mounted ||
        _lifecycleState != AppLifecycleState.resumed ||
        MediaQuery.disableAnimationsOf(context) ||
        !_pageController.hasClients) {
      _scheduleAutoAdvance();
      return;
    }

    final nextPage = (_pageIndex + 1) % _messages.length;
    _pageController.animateToPage(
      nextPage,
      duration: _phraseTransitionDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    if (_pageIndex != index) setState(() => _pageIndex = index);
    _scheduleAutoAdvance();
  }

  void _goToPage(int index) {
    _scheduleAutoAdvance();
    if (!_pageController.hasClients || index == _pageIndex) return;

    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(index);
      return;
    }

    _pageController.animateToPage(
      index,
      duration: _phraseTransitionDuration,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final phraseHeight = 196.0 * (1 + (textScale - 1).clamp(0, 1.5) * 2);

    return Scaffold(
      body: AgroBrandBackground(
        backgroundKey: const ValueKey('welcome-background'),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight > 32
                      ? constraints.maxHeight - 32
                      : 0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BrandHeader(),
                        const SizedBox(height: 28),
                        SizedBox(
                          height: phraseHeight,
                          child: Listener(
                            onPointerDown: (_) => _pauseAutoAdvanceForTouch(),
                            onPointerUp: (_) => _resumeAutoAdvanceAfterTouch(),
                            onPointerCancel: (_) =>
                                _resumeAutoAdvanceAfterTouch(),
                            child: PageView.builder(
                              key: const ValueKey('welcome-phrases'),
                              controller: _pageController,
                              itemCount: _messages.length,
                              onPageChanged: _onPageChanged,
                              itemBuilder: (context, index) {
                                final (message, icon) = _messages[index];
                                return _WelcomePhrase(
                                  message: message,
                                  icon: icon,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _messages.length,
                            (index) => _PageIndicator(
                              index: index,
                              selected: index == _pageIndex,
                              reduceMotion: reduceMotion,
                              onTap: () => _goToPage(index),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => context.push(AppRoutes.login),
                                style: _welcomeButtonStyle(
                                  context,
                                  background: AppColors.surface,
                                ),
                                child: const Text(
                                  'Iniciar sesion',
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () =>
                                    context.push(AppRoutes.register),
                                style: _welcomeButtonStyle(
                                  context,
                                  background: AppColors.primarySurface,
                                ),
                                child: const Text(
                                  'Crear cuenta',
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () =>
                              context.push('${AppRoutes.login}?mode=admin'),
                          icon: const Icon(Icons.admin_panel_settings_outlined),
                          label: const Text('Acceso administrativo'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: AppColors.surface,
                            textStyle: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _welcomeButtonStyle(
    BuildContext context, {
    required Color background,
  }) => FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(58),
    backgroundColor: background,
    foregroundColor: AppColors.primaryDark,
    textStyle: Theme.of(context).textTheme.titleSmall
        ?.copyWith(fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 360;
      final logo = Container(
        width: 84,
        height: 84,
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/logotipo_oficial.png',
            semanticLabel: 'Logo de Agro+',
            fit: BoxFit.cover,
            cacheWidth: 168,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
      final brand = Column(
        crossAxisAlignment: compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            'Agro+',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.surface,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
            ),
          ),
          Text(
            'Del campo a tu mano',
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.surface.withValues(alpha: .88)),
          ),
        ],
      );

      if (compact) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [logo, const SizedBox(height: 12), brand],
        );
      }

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          logo,
          const SizedBox(width: 14),
          Flexible(child: brand),
        ],
      );
    },
  );
}

class _WelcomePhrase extends StatelessWidget {
  const _WelcomePhrase({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface.withValues(alpha: .14),
        ),
        child: Icon(icon, color: AppColors.primarySurface, size: 30),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.surface,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ),
    ],
  );
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.index,
    required this.selected,
    required this.reduceMotion,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Frase ${index + 1} de ${_WelcomeViewState._messages.length}',
    child: InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            width: selected ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: selected ? 1 : .45),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    ),
  );
}
