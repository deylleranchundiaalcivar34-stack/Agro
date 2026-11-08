# Agro+ Welcome Interaction Refresh — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Replace the welcome card and automatic slogans with a full-green, manually swipeable welcome screen and horizontal login/register actions.

**Architecture:** Keep the change inside `WelcomeView` and its existing widget test file. Use Flutter `PageView` for manual horizontal paging, existing `AppColors` and routes, and a scrollable vertical layout for compact screens.

**Tech Stack:** Flutter/Dart, Material 3, GoRouter; no new dependencies.

**Spec:** `docs/superpowers/specs/2026-11-07-marketplace-welcome-design.md`

## Global Constraints

- Keep the approved welcome route, auth guards, MFA, and registration behavior.
- Use the existing `AppColors` and logo; do not add a white content card or automatic phrase timer.
- Keep the design usable on narrow screens and with larger text.

## Review Focus

1. Manual swipe and page indicators remain usable → `test/welcome_view_test.dart`.
2. Login and registration stay side by side without overflow on compact widths → `test/welcome_view_test.dart`.
3. The green background, clear actions, and absence of a white hero card remain consistent → `test/welcome_view_test.dart`.

---

### Task 1: Refresh welcome layout and phrase controls

**Files:**
- Modify: `lib/features/auth/presentation/views/welcome_view.dart`
- Modify: `test/welcome_view_test.dart` (update existing expectations for the changed interaction)

**Interfaces:**
- Consume: existing routes, `AppColors`, and `assets/images/logotipo_oficial.png`.
- Produce: `WelcomeView` with three manually swipeable phrases, tappable page indicators, horizontal login/register buttons, and administrative link below.

- [x] Remove the automatic timer and card-based hero; implement the approved full-green layout and manual `PageView`.
- [x] Point **Iniciar sesión** directly to `AppRoutes.login`; preserve registration and admin destinations.
- [x] Update obsolete existing widget-test expectations for automatic rotation and card color; preserve routing and compact-layout coverage. (Suite not run per instruction; swipe could not be injected by this Android device.)
- [x] Format the changed Dart files and inspect the diff; build/install the profile app on the connected Android device for visual review. (`flutter analyze` reported no issues; screenshot confirms layout; Android denies ADB swipe input.)
