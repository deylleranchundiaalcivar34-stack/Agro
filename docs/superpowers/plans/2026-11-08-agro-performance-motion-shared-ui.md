# Agro+ Shared UI and Motion Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce unnecessary widget rebuilds and repeated animation work across home, auth, profile, forms, and navigation while keeping interactions clear and quick.

**Architecture:** Profile first, then scope rebuilds to the smallest stateful section using existing Provider patterns. Define shared motion durations/curves, remove repeated entry effects from rebuilds and long lists, and respect reduced-motion settings.

**Tech Stack:** Flutter/Dart, Provider, GoRouter, `flutter_animate`, Flutter DevTools, widget tests.

**Spec:** `docs/superpowers/specs/2026-11-08-agro-performance-design.md`

## Global Constraints

- Do not change product/auth/profile features, route semantics, or forms/keyboard behavior.
- Leave splash and welcome visual/motion design and minimum brand time unchanged.
- Preserve finger-tracked module swipe, bottom bar and producer `+` action.
- Do not add global `RepaintBoundary` wrappers without measured repaint evidence.
- New shared timings are starting targets, adjusted only from Profile/device feel: tap feedback 100–140 ms; state changes 160–220 ms; route transitions no longer than the existing 250 ms unless swipe itself is finger-driven.
- Respect `MediaQuery.disableAnimations`; no repeating animation in long lists or off-screen routes.

## Review Focus

- A state update to one home section does not rebuild/animate the entire page.
- Frequent chat/form updates do not replay screen entrance animation.
- Reduced-motion preference removes nonessential animated movement without hiding state changes.
- Re-entering a module preserves navigation state and scroll position.
- Keyboard open/close and text entry remain responsive and retain current safe-area layout.

---

### Task 1: Profile rebuild and paint hot spots by screen

**Files:**
- Create: `docs/performance/2026-11-08-baseline.md` (append per-screen findings)
- Create test: `test/ui_rebuild_scope_test.dart`
- Inspect: `lib/features/home/presentation/views/home_view.dart`, auth views, product views, profile views, `lib/features/main/presentation/views/main_navigation_view.dart`

**Interfaces:** Consume Task 1 baseline in `2026-11-08-agro-performance-baseline-startup.md`; do not add state packages.

- [ ] **Step 1: Capture rebuild/paint profile** — use DevTools Performance/Rebuild Stats for home refresh, typing/search, form validation, profile update and route changes; annotate exact widget/operation and frequency.
- [ ] **Step 2: Select only proven rebuild hot spots** — list the provider state listened to, subtree rebuilt, and proposed narrow consumer boundary per hot spot.
- [ ] **Step 3: Add focused rebuild tests** — assert that changing one selected field does not rebuild an unrelated expensive section; use counters in test-only widgets, not production logging.
- [ ] **Step 4: Verify RED** — run the selected widget tests; expected: the unrelated-section counter increments under current broad subscriptions.

### Task 2: Narrow measured state rebuilds

**Files:**
- Modify only as evidenced: `lib/features/home/presentation/views/home_view.dart`, `lib/features/products/presentation/views/products_catalog_view.dart`, auth/profile view(s) selected in Task 1.
- Test: `test/ui_rebuild_scope_test.dart` and corresponding module tests.

**Interfaces:** Use existing `Provider`, `Consumer`, and `Selector`; state remains owned by current view models.

- [ ] **Step 1: Extract the smallest stable subview or Selector** — subscribe only to the exact value needed; avoid moving business logic into widgets.
- [ ] **Step 2: Verify targeted rebuild count** — run the affected test; expected: selected section updates and unrelated section count stays unchanged.
- [ ] **Step 3: Verify module behavior** — run home, catalog, authentication, and profile focused test files; expected: visible state and navigation remain correct.
- [ ] **Step 4: Re-profile** — confirm a measured reduction in build/paint time before retaining any structural extraction.

### Task 3: Consolidate motion and remove redundant effects

**Files:**
- Create: `lib/core/constants/app_durations.dart`
- Create test: `test/app_motion_policy_test.dart`
- Modify only after animation inventory: `lib/core/router/app_router.dart`, `lib/features/main/presentation/views/main_navigation_view.dart`, selected auth/product/home/profile views.
- Test: `test/main_navigation_view_test.dart`, `test/welcome_view_test.dart`, `test/app_motion_policy_test.dart`; splash/welcome should assert unchanged approved behavior.

**Interfaces:**
- Add `AppDurations.tapFeedback`, `AppDurations.stateChange`, `AppDurations.routeTransition` with values from the constraints section.
- One motion helper may wrap an interactive child only if repeated call sites share identical behavior; do not make a new general animation framework.

- [ ] **Step 1: Inventory animated call sites** — record animation trigger, duration, whether it repeats/restarts on rebuild, visible purpose, and reduced-motion behavior.
- [ ] **Step 2: Add failing motion tests** — in `test/app_motion_policy_test.dart`, assert tap/state transitions use shared durations, reduced-motion ends at target state without movement, and reopening pages does not replay list-wide entries.
- [ ] **Step 3: Verify RED** — run focused motion/navigation tests; expected: unbounded or duplicate motion assertions fail.
- [ ] **Step 4: Define shared duration constants and migrate by group** — route transitions, selected-state feedback, and one-time screen entrances; remove per-item stagger from long lists and infinite shimmer where it repeats beyond initial short loading.
- [ ] **Step 5: Preserve splash and welcome** — add/retain assertions that their current visual/motion contract is unchanged; no edits to their animation code in this task.
- [ ] **Step 6: Verify GREEN** — run `flutter test --no-pub test/main_navigation_view_test.dart test/welcome_view_test.dart test/app_motion_policy_test.dart test/ui_rebuild_scope_test.dart` plus the selected auth, product, and profile test files and `flutter analyze --no-pub`.
- [ ] **Step 7: Feel-test on device** — quickly switch tabs, drag between modules, type in forms, open/close details, and use reduced motion; retain only effects that remain responsive and communicate state.
