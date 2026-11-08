# Agro+ Performance Program Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve responsiveness and data efficiency across Agro+ without changing its features, approved visual identity, or security rules.

**Architecture:** Measure the current Android experience first, then implement separate, testable workstreams for startup, marketplace/images, map, chat, shared screens, and motion. Keep Flutter, Provider, GoRouter, Supabase, Cloudinary, and OpenStreetMap; make no blanket architecture rewrite.

**Tech Stack:** Flutter/Dart, Flutter DevTools, Supabase Flutter/Postgres/Realtime, Cloudinary URL transforms when compatible, flutter_map, flutter_test, adb.

**Spec:** `docs/superpowers/specs/2026-11-08-agro-performance-design.md`

## Subplans

Execute in this order. Each subplan has its own files, tests, and acceptance checks. Data/query work is gated by current row counts and Profile evidence:

1. `docs/superpowers/plans/2026-11-08-agro-performance-baseline-startup.md`
2. `docs/superpowers/plans/2026-11-08-agro-performance-motion-shared-ui.md`
3. `docs/superpowers/plans/2026-11-08-agro-performance-products-images-home.md`
4. `docs/superpowers/plans/2026-11-08-agro-performance-map.md`
5. `docs/superpowers/plans/2026-11-08-agro-performance-chat.md`

## Global Constraints

- Preserve all existing user-visible product, buyer, producer, auth, map, chat, and profile behavior.
- Preserve the approved splash and welcome appearance and the current three-second minimum brand time.
- Keep Supabase as the backend; never put service-role or Cloudinary secrets in Flutter or logs.
- Preserve RLS, voluntary approximate producer locations, message access rules, and OpenStreetMap attribution and usage policy.
- Add no dependency or external service without evidence from profiling and separate approval.
- Fix one measured bottleneck at a time; record before/after values on the same device and flow.
- Respect `MediaQuery.disableAnimations`; do not add entrance or infinite animations to long lists.
- Inspect schema limits and indexes before choosing page sizes or proposing SQL migrations.

## Review Focus

- Slow or unavailable network: every screen retains a useful loading, retry, empty, and error state.
- Large product/message histories: pagination preserves ordering and provides a path to older results.
- Realtime event races: no lost or duplicate messages when initial history and live events overlap.
- Map pan/zoom and permission denied: gestures remain map gestures and public approximate locations remain voluntary.
- Small/low-memory device and reduced-motion preference: no unnecessary image decoding or off-screen animation.

---

### Task 1: Establish reproducible performance baseline

**Files:**
- Create: `docs/performance/2026-11-08-baseline.md` (measurements only; no credentials or personal chat content)
- Reference: `lib/main.dart`, `test/startup_performance_policy_test.dart`

**Interfaces:**
- Uses the connected Android device (model reported by Android: `21061119AG`, Android 13), Flutter Profile builds, and DevTools Timeline/Memory/Network inspection.
- Produces cold/warm startup, home, catalog scroll/search, product detail/image, map open/pan, chat open/send/scroll, and profile observations. Each result includes build mode, device, network condition, steps, and timestamp.

- [ ] **Step 1: Capture baseline build and device state** — run `flutter build apk --profile --no-pub`; record Flutter version, device refresh rate, free storage, and network condition in the baseline report.
- [ ] **Step 2: Measure the startup segments** — record process launch to first branded frame, Supabase/auth initialization duration, the existing three-second brand minimum, and first interactive screen separately. Do not change the splash or welcome.
- [ ] **Step 3: Profile the module flows** — record slow UI/raster frames, peak memory, image requests/bytes, Supabase requests, and perceived wait for the six named flows. Do not capture secrets or chat contents.
- [ ] **Step 4: Set targets from measured data** — for each selected bottleneck, write one quantitative target and a guardrail (such as no additional query, no missing results, or no lost message) before touching that module.
- [ ] **Step 5: Run the existing startup policy check** — `flutter test --no-pub test/startup_performance_policy_test.dart`; expected: the app does not force the prohibited 3.2-second delay.
- [ ] **Step 6: Produce the baseline deliverable** — list the first two bottlenecks by user impact and evidence; if profiling does not reproduce a slowdown, do not optimize that path speculatively.

### Task 2: Tune startup only when the baseline identifies blocking work

**Files:**
- Modify only if justified: `lib/main.dart`, `lib/features/auth/presentation/viewmodels/auth_viewmodel.dart`, `test/startup_performance_policy_test.dart`, and focused startup tests.

**Interfaces:**
- Preserve startup error/retry behavior and the current visible minimum brand time.
- Any auth initialization split must expose an explicit state that prevents a protected route from flashing before session/profile resolution.

- [ ] **Step 1: Add a failing test for the measured startup issue** — assert the selected bootstrap state and that protected navigation waits for auth resolution; expected: it fails against the existing behavior if that behavior caused the measured delay.
- [ ] **Step 2: Run the focused startup test** — `flutter test --no-pub test/startup_performance_policy_test.dart test/startup_bootstrap_test.dart`; expected: the new assertion fails for the reproduced condition.
- [ ] **Step 3: Implement only the measured startup change** — keep `SplashView`, welcome layout, and the three-second brand minimum unchanged; avoid loading unrelated module data during bootstrap.
- [ ] **Step 4: Verify startup tests and analyzer** — run `flutter test --no-pub test/startup_performance_policy_test.dart test/startup_bootstrap_test.dart` and `flutter analyze --no-pub`; expected: pass with no new analyzer issues.
- [ ] **Step 5: Re-profile cold and warm launch** — record before/after and confirm auth routing, recovery deep links, and retry after initialization failure.

### Task 3: Execute motion cleanup before conditional data work

**Files:**
- Shared UI/motion: `docs/superpowers/plans/2026-11-08-agro-performance-motion-shared-ui.md`
- Products/Home/images: `docs/superpowers/plans/2026-11-08-agro-performance-products-images-home.md`
- Map: `docs/superpowers/plans/2026-11-08-agro-performance-map.md`
- Chat: `docs/superpowers/plans/2026-11-08-agro-performance-chat.md`

**Interfaces:** Each module plan produces its own tested, reviewable improvement and before/after measurement.

- [ ] **Step 1: Complete shared UI/motion plan** — keep the approved splash and welcome untouched.
- [ ] **Step 2: Re-evaluate products/images/home plan against measured rows and bytes** — defer paging/transforms without measurable benefit; preserve the plan for growth.
- [ ] **Step 3: Re-evaluate map plan against measured locations/products and map frames** — defer query changes if current workload is immaterial; keep OSM policy unchanged.
- [ ] **Step 4: Re-evaluate chat plan against seeded history and Realtime performance** — do not replace the working stream without enough messages to prove a safe merge.

### Task 4: Full regression and performance comparison

**Files:**
- Modify: `docs/performance/2026-11-08-baseline.md` (append results)
- Verify: tests named in each subplan and full project test/analyzer commands.

**Interfaces:** Consumes all subplan outputs and the original baseline; produces a final comparison and a list of known environment/test limitations.

- [ ] **Step 1: Run all focused module tests** — run each command specified in its subplan; expected: each module's relevant tests pass.
- [ ] **Step 2: Run whole-project analysis and tests** — `flutter analyze --no-pub` and `flutter test --no-pub`; report existing baseline failures distinctly from regressions.
- [ ] **Step 3: Repeat the same real-device flows** — use the same build mode, device, steps, and network condition as Task 1; update before/after metrics.
- [ ] **Step 4: Verify functional guardrails** — login/recovery/biometric lock, buyer and producer navigation, search/filter/detail, create/edit product, map permission/pan, chat send/history/reconnect, and profile pages. Run `flutter build web --no-pub` if the web target remains configured; run iOS Profile/build and device flows on macOS when available (this Windows session cannot produce an iOS build).
- [ ] **Step 5: Complete only if the measured targets are met** — if a target is missed, report the remaining bottleneck and propose a narrow follow-up plan; do not hide it with animation or longer loading.
