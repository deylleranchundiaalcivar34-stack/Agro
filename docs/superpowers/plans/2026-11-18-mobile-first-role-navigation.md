# Mobile-first role-aware navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Agro+ one minimal, role-aware navigation design that keeps the same horizontal composition on phones, tablets, and desktop windows.

**Architecture:** Keep the shared `MainNavigationView` as the owner of the fixed bottom navigation and compact left-aligned app bar. Add one account drawer opened by the profile action, reuse existing GoRouter destinations, and filter account actions by `AuthViewModel.selectedRole`. Responsive sizing may constrain width and spacing but must not switch to a side rail or desktop-specific navigation.

**Tech Stack:** Flutter Material 3, GoRouter, Provider, existing `AuthViewModel`, existing Agro+ assets and colors. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-11-18-role-adaptive-navigation-design.md`

## Global Constraints

- Keep one fixed horizontal bottom navigation at every window size.
- Keep four primary destinations: Inicio, Comprar/Catálogo, Mapa, Chat; producers also get Publicar.
- Keep the account drawer as the single account hub with the same hierarchy across sizes; constrain its width to the viewport.
- Producer-only account entries are Mis publicaciones and Mi zona pública.
- Do not create admin-only destinations or routes; hide buyer-only shortcuts from administrators.
- Keep tap targets at least 48 px; use the existing green palette, outlined icons, and reduced-motion-aware short transitions.
- Do not add blur, large shadows, new dependencies, or per-item entrance animations.

## Review Focus

- Narrow width and increased text scale: bottom destinations stay legible and do not overflow (Task 1).
- Producer-only actions: buyers and admins do not see publish, publications, or public-zone actions (Tasks 1–2).
- Administrator role: no buyer-only order/favorite shortcuts or invented admin route appear (Tasks 1–2).
- Drawer navigation: selecting an entry closes the drawer, reaches its route, and Back restores the source module without an intermediate Profile dashboard (Task 2).
- Scroll and branch navigation: bottom bar remains visible while scrolling, and horizontal page swipes do not change module (Task 1).

---

### Task 1: Lock down the mobile-first navigation behavior

**Files:**
- Modify: `test/main_navigation_view_test.dart`

**Interfaces:**
- Consumes: current `MainNavigationView`, `AnimatedBranchContainer`, and `AuthViewModel` test harness.
- Produces: regression coverage for fixed navigation, tap-based module changes, compact/wide sizing, and role-specific destinations.

- [x] **Step 1: Update the failing navigation tests**

Replace obsolete tests that expect the bar to hide on scroll or branches to follow horizontal swipes. Add assertions that the bar stays visible during vertical scrolling, swipes do not change branches, tab taps still change branches, and the same `NavigationBar` composition renders at narrow and wide test widths. Add role assertions for buyer, producer, and admin, including producer's Publicar action.

- [x] **Step 2: Run the focused test to verify expected failures**

Run: `flutter test test/main_navigation_view_test.dart`
Expected: failures expose the current centered green app bar, missing role-specific checks, or stale navigation assumptions addressed by the feature.

### Task 2: Make the role-aware account drawer the single account hub

**Files:**
- Create: `lib/features/profile/presentation/widgets/account_navigation_drawer.dart`
- Modify: `lib/features/profile/presentation/widgets/profile_avatar_action.dart`
- Delete: `lib/features/profile/presentation/views/profile_view.dart`
- Modify: `lib/core/router/app_router.dart`
- Test: `test/account_navigation_drawer_test.dart`

**Interfaces:**
- Consumes: `AuthViewModel`, `AppRoutes`, existing sign-out confirmation behavior, and the parent `Scaffold` end drawer.
- Produces: `AccountNavigationDrawer`, the single role-aware list of existing account destinations and sign-out action. Its identity header opens Mis datos. Destinations are pushed as independent routes so Back restores the source module; `/profile` redirects to `/profile/data` for compatibility.

- [x] **Step 1: Add drawer tests for each role**

Assert buyer sees pedidos/favoritos but no producer-only entries; producer sees pedidos/favoritos plus Mis publicaciones and Mi zona pública; admin sees common account actions without buyer or producer shortcuts. Assert identity and role are visible, there is no duplicate “Mi perfil” entry, the identity header opens Mis datos, and Back restores the source module.

- [x] **Step 2: Run the drawer test to verify it fails**

Run: `flutter test test/account_navigation_drawer_test.dart`
Expected: FAIL because the new widget and profile-triggered drawer do not yet exist.

- [x] **Step 3: Implement the account drawer and profile action**

Create a lightweight Material `Drawer` with identity/role header, outlined list icons, dividers for account and help/session actions, and links using existing routes. The widget receives its `UserRole` from Provider. Update `ProfileAvatarAction` to open the parent Scaffold's end drawer. Preserve the existing sign-out confirmation flow. Filter order/favorite entries to buyer and producer; add producer's publication and public-location links only for producer.

- [x] **Step 4: Remove the duplicate profile dashboard**

Delete the separate Profile dashboard. Make its legacy `/profile` route redirect directly to Mis datos, and flatten account destination routes so they no longer retain a Profile parent when returning.

- [x] **Step 5: Run the drawer test**

Run: `flutter test test/account_navigation_drawer_test.dart`
Expected: PASS for buyer, producer, and admin visibility plus drawer navigation.

### Task 3: Polish the shared app bar and fixed bottom bar

**Files:**
- Modify: `lib/features/main/presentation/views/main_navigation_view.dart`
- Modify: `lib/core/theme/app_theme.dart` only if a reusable navigation theme override is needed.
- Test: `test/main_navigation_view_test.dart`

**Interfaces:**
- Consumes: `AccountNavigationDrawer` from Task 2, `assets/images/logotipo_oficial.png`, `AppColors`, and existing shell routes.
- Produces: a left-aligned logo mark with Agro+ title, compact surface-colored app bar, restrained refresh/profile actions, and one width-constrained horizontal bottom bar for all devices.

- [x] **Step 1: Implement the single visual composition**

Place the square logo mark and module title in a left-aligned row. Use a light surface app bar with dark text and green accents. Keep refresh at the right and connect the profile action to `endDrawer`. Keep the bottom bar fixed, minimal, width-constrained and centered on wide windows, full-width on phones, with neutral inactive icons and a soft green selected indicator. Keep producer's central publish action and role-specific destination labels.

- [x] **Step 2: Verify focused navigation tests**

Run: `flutter test test/main_navigation_view_test.dart test/account_navigation_drawer_test.dart`
Expected: PASS with no overflow exceptions at 240/320/360 px, increased text scaling, and wide window constraints.

- [x] **Step 3: Analyze changed Dart files**

Run: `flutter analyze lib/features/main/presentation/views/main_navigation_view.dart lib/features/profile/presentation/widgets/account_navigation_drawer.dart lib/features/profile/presentation/widgets/profile_avatar_action.dart lib/features/profile/presentation/widgets/profile_subpage.dart`
Expected: `No issues found!`.

- [x] **Step 4: Build and inspect on connected Android phone**

Run: `flutter run -d 105d60eb0506`
Expected: app launches on Android 13; visually inspect same bottom bar, left-aligned brand, drawer width/content, buyer/producer role visibility, and no clipped labels or overflow. If no authenticated role is active, inspect the available role selection flow and report limits.

- [x] **Step 5: Build Windows preview**

Run: `flutter build windows`
Expected: Windows debug/release target compiles with the same horizontal navigation composition; no responsive switch to a side rail occurs.

### Task 4: Unify and speed up account subpages

**Files:**
- Modify: `lib/features/profile/presentation/widgets/profile_subpage.dart`
- Modify: `lib/features/map/presentation/views/public_location_edit_view.dart`
- Modify: `lib/features/favorites/presentation/views/favorites_view.dart`
- Modify: `lib/features/profile/presentation/views/profile_support_view.dart`
- Modify: `lib/core/constants/app_durations.dart`
- Modify: `lib/core/router/app_router.dart`
- Test: `test/profile_subpage_test.dart`
- Test: `test/auth_router_test.dart`

**Interfaces:**
- Consumes: existing Agro+ logo, `AppColors`, app text theme, `AppDurations.resolve`, and existing account routes.
- Produces: one shared branded frame for every drawer destination, with an explicit back action; short reduced-motion-aware route transitions; quieter favorites decoration consistent with the main modules.

- [x] Add regression tests for the shared logo/back/title treatment and account transition duration; confirm they fail before implementation.
- [x] Apply the shared frame to the public-zone editor and existing `ProfileSubpage` views.
- [x] Route account destinations through the short transition and simplify the favorites header decoration.
- [x] Run account, navigation, route, and full test suites; analyze changed files and build both Android and Windows previews.

**Verification note:** The focused account, navigation, router, and public-location tests pass; `flutter analyze` reports no issues; Android hot reload and the Windows build succeed. The full suite reports 3 unrelated failures: the product-interest lifecycle test lacks a `FavoritesViewModel` provider, the product-quantity test expects a missing `Preventa` label, and the repository-wide ASCII source-text policy finds accented strings in other existing files.

### Task 5: Audit transitions and shared styling across all authenticated modules

**Files:**
- Create: `lib/core/widgets/agro_page_app_bar.dart`
- Modify: `lib/features/main/presentation/views/main_navigation_view.dart`
- Modify: authenticated product/detail/profile screens with their own app bars
- Modify: `lib/features/chat/presentation/views/chat_room_view.dart` and `lib/features/chat/presentation/views/chat_list_view.dart` route handling
- Modify: `lib/core/constants/app_durations.dart` and `lib/core/router/app_router.dart`
- Test: `test/agro_page_app_bar_test.dart` and `test/auth_router_test.dart`

**Interfaces:**
- Consumes: existing logo, green/surface palette, route stack, reduced-motion preference, stateful shell branch preservation.
- Produces: one shared light, logo-led header for authenticated pages; compact conversation header on the same surface; 180 ms general route motion, 150 ms account motion, 180 ms branch motion; no default 450 ms push for a navigable secondary module route.

- [ ] Add failing regression checks for shared internal headers and chat-request route motion.
- [ ] Apply the shared header to authenticated module/detail pages while leaving splash and auth screens independent.
- [ ] Replace remaining long/default navigable route transitions with the shared short motion and correct chat-request route classification.
- [ ] Verify module/tab state, targeted route tests, full suite status, analyzer, and both platform builds.
