# Agro+ Baseline and Startup Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a repeatable performance baseline on the user's Android device and reduce only a measured startup bottleneck while preserving the approved splash and welcome.

**Architecture:** Use Flutter Profile builds and DevTools to measure startup and module flows. Keep the brand screen's current minimum display time; distinguish this intentional wait from Supabase/auth initialization and first interaction.

**Tech Stack:** Flutter Profile, Flutter DevTools, adb, Flutter tests, Supabase Flutter.

**Spec:** `docs/superpowers/specs/2026-11-08-agro-performance-design.md`

## Global Constraints

- Preserve the current splash and welcome appearance and three-second brand minimum.
- Do not print `.env`, Supabase keys, access tokens, or private user content.
- Make startup/auth changes only when the profile trace identifies them as a bottleneck.
- Prevent protected routes from appearing before auth/session resolution.

## Review Focus

- Cold launch and warm launch: distinguish Flutter first frame, auth initialization, brand minimum, and interactive route.
- Expired or absent session: route to the correct unauthenticated flow without a protected-screen flash.
- Supabase unavailable: retain the existing retry/error behavior and allow a retry after failure.
- Email recovery deep link during startup: do not lose the link while bootstrap is pending.
- Low-end Android: profile a release-like Profile build, never infer speed from debug-only timing.

---

### Task 1: Record startup baseline and module scenarios

**Files:**
- Create: `docs/performance/2026-11-08-baseline.md`
- Create only if startup behavior is changed: `test/startup_bootstrap_test.dart`
- Reference: `lib/main.dart`, `lib/app.dart`, `lib/features/splash/splash_view.dart`

**Interfaces:**
- Target device: connected Android model `21061119AG`, Android 13; confirm actual refresh rate and Flutter version at execution time.
- Flow labels: cold start, warm start, login, welcome, home, catalog, product detail, map, chat room, profile.

- [ ] **Step 1: Build Profile APK** — run `flutter build apk --profile --no-pub`; expected: `build/app/outputs/flutter-apk/app-profile.apk` exists.
- [ ] **Step 2: Install/run the Profile build** — run `adb install -r build/app/outputs/flutter-apk/app-profile.apk`, then `flutter run --profile -d 105d60eb0506`; expected: no debug instrumentation affects the timings.
- [ ] **Step 3: Trace startup segments in DevTools** — capture process start, first frame, `Supabase.initialize`, `AuthViewModel.initialLoad`, 3-second minimum, route-ready; record at least 3 cold and 3 warm runs.
- [ ] **Step 4: Capture module baseline** — record UI/raster frame over-budget counts, memory peak, data requests and image bytes while performing catalog scroll/search, map pan, chat scroll/send, and profile open.
- [ ] **Step 5: Write target and guardrail per reproduced issue** — no arbitrary target before the first run; use the same device/network and document exact steps.

### Task 2: Change startup/auth only if measurement justifies it

**Files:**
- Conditional: `lib/main.dart`, `lib/app.dart`, `lib/features/auth/presentation/viewmodels/auth_viewmodel.dart`
- Test: `test/startup_performance_policy_test.dart`, plus a focused startup widget/unit test if needed.

**Interfaces:**
- Preserve `AuthViewModel.initialLoad` semantics or introduce a documented bootstrap state consumed by the router; never infer authenticated state from an unfinished load.
- Preserve App Links processing and cleanup of the `StreamSubscription`.

- [ ] **Step 1: Pin the regression case with a failing test** — reproduce the measured startup delay or routing race with a fake delayed/failing auth initializer; assert no protected route is shown early.
- [ ] **Step 2: Verify RED** — run `flutter test --no-pub test/startup_performance_policy_test.dart test/startup_bootstrap_test.dart`; expected: the new assertion fails on current behavior.
- [ ] **Step 3: Apply a minimal bootstrap change** — isolate only the blocking work shown in trace; do not shorten the brand minimum or move protected data into unauthenticated screens.
- [ ] **Step 4: Verify GREEN and static analysis** — run `flutter test --no-pub test/startup_performance_policy_test.dart test/startup_bootstrap_test.dart` and `flutter analyze --no-pub`; expected: pass.
- [ ] **Step 5: Re-run Profile launch measurements** — compare the same 3 cold and 3 warm launches; expected: target from Task 1 improves without auth/deep-link regressions.
