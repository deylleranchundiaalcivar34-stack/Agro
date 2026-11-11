# Agro+ Finger-Tracked Module Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the four main Agro+ modules follow horizontal finger drags and settle to the matching GoRouter branch while preserving the bottom bar, map gestures, nested routes, and branch state.

**Architecture:** Use GoRouter 14.8.1's supported custom `StatefulShellRoute.navigatorContainerBuilder` pattern with a `PageController` and `PageView` whose children are the supplied branch Navigators. `onPageChanged` selects the GoRouter branch; bottom-bar selection animates the controller to the selected page. An inherited scope from `MainNavigationView` disables user paging on Mapa and nested routes.

**Tech Stack:** Flutter, Dart, GoRouter 14.8.1, Flutter widget tests.

**Spec:** `docs/superpowers/specs/2026-11-08-swipe-navigation-design.md`

## Global Constraints

- Main swipe destinations are Inicio, Comprar, Mapa, Chat in branch order 0–3; profile is outside this shell.
- Keep all branch Navigators as direct PageView children.
- Disable user-driven paging on Mapa and on nested routes; programmatic bottom-bar navigation still works.
- The bottom navigation and producer `+` action remain intact.
- No new dependencies; respect reduced-motion preferences for programmatic changes.

## Review Focus

- While the pointer is down, PageController progress must track the drag; test fractional progress before release.
- A sub-threshold drag returns to the current branch; test cancellation/settling.
- Swiping at either end must not wrap; test both bounds.
- A nested detail/form/chat route must not respond; test representative nested paths.
- A horizontal drag on Mapa must not page away; test map route remains selected.
- Bottom-bar selection must animate to and stay synchronized with the selected branch.
- Branch state must survive leaving and returning; test a changed scroll position.

---

### Task 1: Add failing interaction tests

**Files:**
- Modify: `test/main_navigation_view_test.dart`

**Interfaces:**
- Uses the existing test `GoRouter` and `MainNavigationView` harness.
- Update the test route to four shell branches and move profile routes outside the shell, matching production.

- [ ] **Step 1: Test continuous movement**: begin a horizontal pointer gesture on Inicio, move partway, and assert `PageController.page` is fractional while the route remains Inicio; move past half-page and assert it follows to Comprar before release; release and assert the route/page settle at Comprar.
- [ ] **Step 2: Test reverse movement, vertical drag, short drag, both boundaries, nested routes, and Mapa paging disabled.**
- [ ] **Step 3: Test bottom-bar synchronization and branch scroll-state preservation.**
- [ ] **Step 4: Run** `flutter test --no-pub test/main_navigation_view_test.dart` and verify the new continuous-progress assertion fails before implementation.

### Task 2: Build the interactive GoRouter branch container

**Files:**
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/main/presentation/views/main_navigation_view.dart`

**Interfaces:**
- `StatefulShellRoute.navigatorContainerBuilder(BuildContext, StatefulNavigationShell, List<Widget>)` supplies all branch Navigators.
- `AnimatedBranchContainer` receives `navigationShell` and `children`; it owns a `PageController(initialPage: navigationShell.currentIndex)` and synchronizes page changes through `navigationShell.goBranch(index)`.
- Add a `ModulePageSwipeScope` around the shell child so the container can determine whether user paging is enabled for the current route.

- [ ] **Step 1: Replace** the custom slide/opacity stack with a stateful PageView branch container; keep the supplied Navigator children in branch order.
- [ ] **Step 2: On page changes**, call `navigationShell.goBranch(index)` only when the page differs from the current branch.
- [ ] **Step 3: On external branch selection**, animate the controller to that branch over 160 ms (or zero duration with reduced motion) without interrupting an active finger drag on the same page.
- [ ] **Step 4: Dispose** the PageController when the container is removed.

### Task 3: Scope paging and preserve navigation controls

**Files:**
- Modify: `lib/features/main/presentation/views/main_navigation_view.dart`
- Modify: `lib/core/router/app_router.dart`
- Test: `test/main_navigation_view_test.dart`

- [ ] **Step 1: Wrap** `StatefulNavigationShell` with `ModulePageSwipeScope`, enabling user paging only on main root destinations and not on Mapa.
- [ ] **Step 2: Keep** bottom navigation branch taps on the existing `goBranch` path; verify controller synchronization when selecting any of the four destinations.
- [ ] **Step 3: Keep** the producer `+` action unchanged and outside the PageView destinations.
- [ ] **Step 4: Remove** the manual one-time `GestureDetector` module-switch logic; PageView now owns continuous touch tracking.

### Task 4: Verify regressions

**Files:**
- Modify if needed: `test/main_navigation_view_test.dart`

- [ ] **Step 1: Run** `flutter test --no-pub test/main_navigation_view_test.dart`; expect navigation, interactive progress, reduced-motion, map, bounds, and state-retention tests to pass.
- [ ] **Step 2: Run** `flutter analyze --no-pub`; expect no analyzer errors.
- [ ] **Step 3: Check on Android by cable**: hold and drag on Inicio and Comprar and confirm the page tracks the finger before release; verify bottom-bar taps synchronize; enter Mapa and pan without changing modules; use the bottom bar to leave Mapa; verify a detail/form route does not page away; repeat with producer account and confirm the `+` still publishes.
