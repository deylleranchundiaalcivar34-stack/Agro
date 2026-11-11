import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../profile/presentation/widgets/profile_avatar_action.dart';
import '../../../profile/presentation/widgets/public_profile_avatar.dart';

typedef ModuleRefreshCallback = Future<void> Function();

class ModuleRefreshRegistry {
  final Map<String, ModuleRefreshCallback> _callbacks = {};

  void register(String module, ModuleRefreshCallback callback) {
    _callbacks[module] = callback;
  }

  void unregister(String module) => _callbacks.remove(module);

  Future<void> refresh(String module) async {
    await _callbacks[module]?.call();
  }
}

class ModuleRefreshScope extends InheritedWidget {
  const ModuleRefreshScope({
    super.key,
    required this.registry,
    required super.child,
  });

  final ModuleRefreshRegistry registry;

  static ModuleRefreshRegistry? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ModuleRefreshScope>()?.registry;

  @override
  bool updateShouldNotify(ModuleRefreshScope oldWidget) =>
      !identical(registry, oldWidget.registry);
}

class ChatRoomHeaderData {
  const ChatRoomHeaderData({
    required this.name,
    required this.initial,
    required this.subtitle,
    this.avatarUrl,
    this.onOpenContact,
  });

  final String name;
  final String initial;
  final String subtitle;
  final String? avatarUrl;
  final VoidCallback? onOpenContact;
}

class ChatRoomHeaderController extends ValueNotifier<ChatRoomHeaderData?> {
  ChatRoomHeaderController() : super(null);

  void show(ChatRoomHeaderData data) {
    value = data;
  }

  void clear() {
    if (value == null) return;
    value = null;
  }
}

class ChatRoomHeaderScope extends InheritedWidget {
  const ChatRoomHeaderScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final ChatRoomHeaderController controller;

  static ChatRoomHeaderController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ChatRoomHeaderScope>()?.controller;

  @override
  bool updateShouldNotify(ChatRoomHeaderScope oldWidget) =>
      !identical(controller, oldWidget.controller);
}

class MainNavigationView extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  final String locationPath;

  const MainNavigationView({
    super.key,
    required this.navigationShell,
    required this.locationPath,
  });

  @override
  State<MainNavigationView> createState() => _MainNavigationViewState();
}

class ModulePageSwipeScope extends InheritedWidget {
  const ModulePageSwipeScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  static bool enabledOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ModulePageSwipeScope>()
          ?.enabled ??
      false;

  @override
  bool updateShouldNotify(ModulePageSwipeScope oldWidget) =>
      enabled != oldWidget.enabled;
}

/// Presents GoRouter's persistent branch Navigators as finger-tracked pages.
class AnimatedBranchContainer extends StatefulWidget {
  const AnimatedBranchContainer({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  State<AnimatedBranchContainer> createState() =>
      _AnimatedBranchContainerState();
}

class _AnimatedBranchContainerState extends State<AnimatedBranchContainer> {
  late final PageController _pageController = PageController(
    initialPage: widget.navigationShell.currentIndex,
  );

  @override
  void didUpdateWidget(covariant AnimatedBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPageToBranch();
  }

  void _syncPageToBranch() {
    if (!_pageController.hasClients) return;

    final targetIndex = widget.navigationShell.currentIndex;
    final currentPage = _pageController.page;
    if (currentPage == null ||
        currentPage.round() == targetIndex ||
        (currentPage - targetIndex).abs() < 0.001) {
      return;
    }

    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(targetIndex);
      return;
    }

    _pageController.animateToPage(
      targetIndex,
      duration: AppDurations.resolve(context, AppDurations.stateChange),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    if (index != widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(index);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView(
    key: const Key('module-page-view'),
    controller: _pageController,
    physics: ModulePageSwipeScope.enabledOf(context)
        ? null
        : const NeverScrollableScrollPhysics(),
    onPageChanged: _onPageChanged,
    children: [
      for (var index = 0; index < widget.children.length; index++)
        TickerMode(
          key: Key('branch-ticker-mode-$index'),
          enabled: index == widget.navigationShell.currentIndex,
          child: widget.children[index],
        ),
    ],
  );
}

class _MainNavigationViewState extends State<MainNavigationView> {
  static const double _scrollThreshold = 24;
  final _refreshRegistry = ModuleRefreshRegistry();
  final _chatHeaderController = ChatRoomHeaderController();

  static const List<NavigationDestination> _buyerDestinations = [
    NavigationDestination(
      label: 'Inicio',
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
    ),
    NavigationDestination(
      label: 'Comprar',
      icon: Icon(Icons.grid_view_outlined),
      selectedIcon: Icon(Icons.grid_view_rounded),
    ),
    NavigationDestination(
      label: 'Mapa',
      icon: Icon(Icons.map_outlined),
      selectedIcon: Icon(Icons.map_rounded),
    ),
    NavigationDestination(
      label: 'Chat',
      icon: Icon(Icons.chat_bubble_outline_rounded),
      selectedIcon: Icon(Icons.chat_bubble_rounded),
    ),
  ];

  bool _isNavigationVisible = true;
  bool _metricsVisibilityScheduled = false;
  double? _lastScrollPixels;
  double _accumulatedScroll = 0;
  bool _isMainDestination(String location) => const {
    AppRoutes.home,
    AppRoutes.products,
    AppRoutes.map,
    AppRoutes.chatList,
  }.contains(location);

  bool _isChatRoomRoute(String location) =>
      location.startsWith('${AppRoutes.chatList}/');

  String _moduleTitle(String location) => switch (location) {
    AppRoutes.home => 'Agro+',
    AppRoutes.products => 'Preventa agricola',
    AppRoutes.map => 'Mapa de productores',
    AppRoutes.chatList => 'Mensajes Agro+',
    _ => 'Agro+',
  };

  Future<void> _refreshCurrentModule() async {
    final module = switch (widget.navigationShell.currentIndex) {
      0 => AppRoutes.home,
      1 => AppRoutes.products,
      2 => AppRoutes.map,
      3 => AppRoutes.chatList,
      _ => '',
    };
    await _refreshRegistry.refresh(module);
  }

  bool _handleScroll(ScrollNotification notification, bool isMainDestination) {
    if (!isMainDestination || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    final metrics = notification.metrics;
    final hasScrollableContent =
        metrics.maxScrollExtent > metrics.minScrollExtent + 1;
    final atTop = metrics.pixels <= metrics.minScrollExtent + 1;
    final atBottom = hasScrollableContent && metrics.extentAfter <= 1;

    if (notification is ScrollStartNotification) {
      _lastScrollPixels = notification.metrics.pixels;
      _accumulatedScroll = 0;
      if (atTop || !hasScrollableContent) {
        _setNavigationVisible(true);
      }
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      if (atTop || atBottom || !hasScrollableContent) {
        _accumulatedScroll = 0;
        _setNavigationVisible(true);
      }

      final pixels = notification.metrics.pixels;
      final previousPixels = _lastScrollPixels;
      _lastScrollPixels = pixels;
      if (atTop || atBottom || !hasScrollableContent) return false;
      if (previousPixels == null) return false;

      final delta = pixels - previousPixels;
      if (delta == 0) return false;

      if (_accumulatedScroll.sign != delta.sign) {
        _accumulatedScroll = delta;
      } else {
        _accumulatedScroll += delta;
      }

      if (_accumulatedScroll.abs() >= _scrollThreshold) {
        _setNavigationVisible(_accumulatedScroll < 0);
        _accumulatedScroll = 0;
      }
      return false;
    }

    if (notification is OverscrollNotification) {
      final pulledPastBottom =
          notification.overscroll > 0 && hasScrollableContent;
      if ((atBottom && notification.overscroll >= 0) || pulledPastBottom) {
        _lastScrollPixels = null;
        _accumulatedScroll = 0;
        _setNavigationVisible(true);
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      if (atBottom || !hasScrollableContent) {
        _setNavigationVisible(true);
      }
      _lastScrollPixels = null;
      _accumulatedScroll = 0;
    }
    return false;
  }

  void _setNavigationVisible(bool visible) {
    if (_isNavigationVisible == visible || !mounted) return;
    setState(() => _isNavigationVisible = visible);
  }

  bool _handleMetrics(ScrollMetricsNotification notification) {
    final metrics = notification.metrics;
    if (_isMainDestination(widget.locationPath) &&
        metrics.axis == Axis.vertical &&
        metrics.maxScrollExtent <= metrics.minScrollExtent + 1 &&
        !_isNavigationVisible &&
        !_metricsVisibilityScheduled) {
      _metricsVisibilityScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _metricsVisibilityScheduled = false;
        if (!mounted || !_isMainDestination(widget.locationPath)) return;
        _accumulatedScroll = 0;
        _lastScrollPixels = null;
        _setNavigationVisible(true);
      });
    }
    return false;
  }

  @override
  void didUpdateWidget(covariant MainNavigationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locationPath != widget.locationPath) {
      _chatHeaderController.clear();
      _isNavigationVisible = true;
      _lastScrollPixels = null;
      _accumulatedScroll = 0;
    }
  }

  @override
  void dispose() {
    _chatHeaderController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    _lastScrollPixels = null;
    _accumulatedScroll = 0;
    _setNavigationVisible(true);
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.locationPath;
    final isMainDestination = _isMainDestination(location);
    final isChatRoom = _isChatRoomRoute(location);
    final allowModulePaging =
        isMainDestination && widget.navigationShell.currentIndex != 2;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isMainDestination
          ? AppBar(
              key: const Key('persistent-module-app-bar'),
              title: Text(_moduleTitle(location)),
              actions: [
                const ProfileAvatarAction(),
                IconButton(
                  tooltip: 'Actualizar ${_moduleTitle(location)}',
                  onPressed: _refreshCurrentModule,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            )
          : isChatRoom
          ? _buildChatRoomAppBar(context)
          : null,
      body: NotificationListener<ScrollMetricsNotification>(
        onNotification: _handleMetrics,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) =>
              _handleScroll(notification, isMainDestination),
          child: ModulePageSwipeScope(
            enabled: allowModulePaging,
            child: ChatRoomHeaderScope(
              controller: _chatHeaderController,
              child: ModuleRefreshScope(
                registry: _refreshRegistry,
                child: widget.navigationShell,
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: isMainDestination
          ? _buildNavigationBar(context)
          : const SizedBox.shrink(),
    );
  }

  PreferredSizeWidget _buildChatRoomAppBar(BuildContext context) => AppBar(
    key: const Key('persistent-module-app-bar'),
    leading: IconButton(
      tooltip: 'Volver a conversaciones',
      onPressed: () => context.pop(),
      icon: const Icon(Icons.arrow_back_rounded),
    ),
    titleSpacing: 0,
    title: ValueListenableBuilder<ChatRoomHeaderData?>(
      valueListenable: _chatHeaderController,
      builder: (context, data, _) => InkWell(
        onTap: data?.onOpenContact,
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            PublicProfileAvatar(
              radius: 18,
              initial: data?.initial ?? 'A',
              imageUrl: data?.avatarUrl,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data?.name ?? 'Conversacion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    data?.subtitle ?? 'Mensajes Agro+',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: AppColors.surface),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      ValueListenableBuilder<ChatRoomHeaderData?>(
        valueListenable: _chatHeaderController,
        builder: (context, data, _) => IconButton(
          tooltip: 'Informacion del contacto',
          onPressed: data?.onOpenContact,
          icon: const Icon(Icons.info_outline_rounded),
        ),
      ),
    ],
  );

  Widget _buildNavigationBar(BuildContext context) {
    final role = context.watch<AuthViewModel>().selectedRole;
    final isProducer = role == UserRole.producer;
    final isMarketplaceUser = role == UserRole.buyer || isProducer;
    final Widget bar = isProducer
        ? _buildProducerNavigation(context)
        : NavigationBar(
            selectedIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: _onTabSelected,
            destinations: isMarketplaceUser
                ? _buyerDestinations
                : [
                    _buyerDestinations[0],
                    const NavigationDestination(
                      label: 'Catalogo',
                      icon: Icon(Icons.grid_view_outlined),
                      selectedIcon: Icon(Icons.grid_view_rounded),
                    ),
                    ..._buyerDestinations.skip(2),
                  ],
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primarySurface,
            elevation: 0,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          );
    return _withVisibilityAnimation(context, bar);
  }

  Widget _buildProducerNavigation(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              _producerDestination(
                context,
                branchIndex: 0,
                label: 'Inicio',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
              ),
              _producerDestination(
                context,
                branchIndex: 1,
                label: 'Comprar',
                icon: Icons.grid_view_outlined,
                selectedIcon: Icons.grid_view_rounded,
              ),
              Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    label: 'Publicar producto',
                    child: IconButton(
                      onPressed: () => context.go(AppRoutes.productCreate),
                      tooltip: 'Publicar producto',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor: AppColors.info,
                        foregroundColor: AppColors.surface,
                        shape: const CircleBorder(),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 30),
                    ),
                  ),
                ),
              ),
              _producerDestination(
                context,
                branchIndex: 2,
                label: 'Mapa',
                icon: Icons.map_outlined,
                selectedIcon: Icons.map_rounded,
              ),
              _producerDestination(
                context,
                branchIndex: 3,
                label: 'Chat',
                icon: Icons.chat_bubble_outline_rounded,
                selectedIcon: Icons.chat_bubble_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _producerDestination(
    BuildContext context, {
    required int branchIndex,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
  }) {
    final selected = widget.navigationShell.currentIndex == branchIndex;
    final theme = Theme.of(context);
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: () => _onTabSelected(branchIndex),
            child: SizedBox(
              height: 76,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: AppDurations.resolve(
                      context,
                      AppDurations.stateChange,
                    ),
                    width: 48,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primarySurface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      selected ? selectedIcon : icon,
                      color: selected
                          ? AppColors.primaryDark
                          : AppColors.textSecondary,
                      size: 23,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? AppColors.primaryDark
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 10,
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

  Widget _withVisibilityAnimation(BuildContext context, Widget bar) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);

    if (animationsDisabled) {
      return _isNavigationVisible ? bar : const SizedBox.shrink();
    }

    return AnimatedSize(
      key: const Key('navigation-bar-slot'),
      duration: AppDurations.resolve(context, AppDurations.routeTransition),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: ClipRect(
        child: Align(
          heightFactor: _isNavigationVisible ? 1 : 0,
          child: AnimatedOpacity(
            duration: AppDurations.resolve(context, AppDurations.stateChange),
            curve: Curves.easeOut,
            opacity: _isNavigationVisible ? 1 : 0,
            child: IgnorePointer(
              ignoring: !_isNavigationVisible,
              child: ExcludeSemantics(
                excluding: !_isNavigationVisible,
                child: bar,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
