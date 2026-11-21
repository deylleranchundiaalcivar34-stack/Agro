# Unified user profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace duplicated account/chat profile controls with one profile form and reuse the saved avatar throughout Agro+.

**Architecture:** Keep names and farm/business in `usuarios`, keep the phone in a new private RLS-protected table, and keep only the opted-in public phone projection plus avatar in `perfiles_contacto_publicos`. Load the public avatar into `UserProfile` so shared profile widgets can render it consistently.

**Tech Stack:** Flutter, Dart, Provider, Supabase Flutter/PostgREST, Cloudinary unsigned image upload, PostgreSQL RLS migrations.

**Spec:** `docs/superpowers/specs/2026-11-18-unified-user-profile-design.md`

## Global Constraints

- Use the existing Agro+ green Material 3 styles and mobile layout.
- Keep the email visible and read-only.
- Use one name source: first name + last name, including chat display name.
- Use a fixed `+593` prefix and accept exactly nine local mobile digits beginning with `9`; do not accept a leading `0`.
- The phone is optional and private by default; copy it into the public chat profile only after explicit opt-in.
- Do not add a country selector, Google sign-in, or extra personal fields.
- Preserve existing Cloudinary avatar URLs and existing account/chat records.
- Do not add or run tests in this task; format the changed Dart files and inspect the final diff.

## Review Focus

- A saved avatar remains visible after sign-out/sign-in and appears in all own-profile avatar locations; otherwise initials remain the fallback.
- A phone is saved without sharing and is not returned by public chat profile reads.
- Turning sharing on exposes the number in normalized E.164 form; turning it off removes only the public projection and keeps the private number.
- Ecuador input accepts `912345685`, rejects `0912345685`, and stores `+593912345685`.
- Saving names updates chat display names without a second editable name field; the producer farm field is optional and hidden for other roles.

---

### Task 1: Add private phone storage with self-only access

**Files:**
- Create: `supabase/migrations/20261118135349_unified_profile_private_phone.sql`

**Interfaces:**
- Produces table `public.perfiles_contacto_privados` with `id_usuario`, nullable `telefono_celular`, and timestamps.
- RLS permits authenticated users to select/insert/update/delete only their own row.

- [x] Create the table referencing `public.usuarios(id_usuario)` with cascade deletion and an Ecuador mobile check (`+5939` followed by eight digits).
- [x] Enable RLS, grant CRUD to `authenticated`, and add self-only policies comparing `id_usuario` with `auth.uid()`.
- [x] Keep `perfiles_contacto_publicos.telefono_whatsapp` null while `whatsapp_visible` is false, satisfying its existing constraint.
- [x] Review the SQL to confirm the private phone is not readable through the public chat table; backfill existing opted-in Ecuador numbers into the private table.

### Task 2: Add profile data repositories and canonical avatar state

**Files:**
- Create: `lib/features/profile/data/repositories/private_contact_profile_repository.dart`
- Modify: `lib/features/auth/data/models/user_profile.dart`
- Modify: `lib/features/auth/data/repositories/profile_repository.dart`
- Modify: `lib/features/auth/presentation/viewmodels/auth_viewmodel.dart`
- Modify: `lib/features/profile/data/repositories/public_contact_profile_repository.dart`

**Interfaces:**
- `PrivateContactProfileRepository.getMine() -> Future<String?>` returns the current user's private E.164 phone.
- `PrivateContactProfileRepository.saveMine({required String? phone}) -> Future<void>` upserts or clears the current user's phone.
- `UserProfile.avatarUrl` carries the canonical public avatar URL; `copyWith` preserves it across account updates.
- `AuthViewModel.updateAvatarUrl(String? value)` updates the in-memory own-profile avatar after a successful profile save.

- [x] Load `avatar_url` for the authenticated user while hydrating `UserProfile`, and preserve it when names/role are updated; avatar lookup failure does not block sign-in.
- [x] Validate and normalize the private phone in one repository; represent an empty optional value as null.
- [x] Keep `PublicContactProfileRepository.saveMine` synchronized with the user's full name, avatar URL, and sharing choice; pass a phone only when sharing is enabled.
- [x] Ensure the public model masks phone data when `whatsapp_visible` is false, matching the existing schema and privacy behavior.

### Task 3: Replace two profile forms with one identity form

**Files:**
- Modify: `lib/features/profile/presentation/views/profile_data_view.dart`
- Delete if unused after refactor: `lib/features/profile/presentation/widgets/public_chat_profile_section.dart`
- Reuse: `lib/features/profile/presentation/widgets/public_profile_avatar.dart`
- Reuse: `lib/features/products/data/services/product_storage_service.dart`

**Interfaces:**
- The screen owns one form with account fields, photo, optional mobile, and a separate public-sharing opt-in.
- One save action persists account fields, the private phone, and the public profile projection; feedback distinguishes partial success.

- [x] Load account, public avatar/sharing, and private phone data without exposing the private phone to another user's profile query.
- [x] Show one circular photo preview and a manual Cloudinary upload action.
- [x] Keep names and surnames as the only editable display-name fields; derive the chat name from their trimmed combination.
- [x] Show “Nombre de finca o negocio” only for producers and keep it optional; show email read-only.
- [x] Add “Celular (opcional)” with fixed `+593` prefix, input for nine digits starting in `9`, no country picker, and no leading zero.
- [x] Add a default-off option worded as permission to share the number for WhatsApp contact; turning it off preserves the private field value.
- [x] Remove the duplicate chat-name field and second save button.
- [x] Report when account data saved but public identity synchronization failed, instead of implying a full rollback.
- [x] If the new private table migration is not present, show a clear recoverable save/load error rather than crashing the screen.

### Task 4: Reuse the avatar in own-profile UI

**Files:**
- Modify: `lib/features/profile/presentation/widgets/profile_avatar_action.dart`
- Modify: `lib/features/profile/presentation/widgets/account_navigation_drawer.dart`
- Review and modify only identity avatars if applicable: `lib/features/products/presentation/views/product_detail_view.dart`, `lib/features/profile/presentation/views/public_producer_profile_view.dart`
- Reuse: `lib/features/profile/presentation/widgets/public_profile_avatar.dart`

**Interfaces:**
- Own-profile avatar widgets read `auth.profile?.avatarUrl` and `auth.userInitial` from `AuthViewModel`.
- Product/map/category icons remain their existing domain icons.

- [x] Replace initials-only own-profile circles with `PublicProfileAvatar` while preserving tap targets, sizes, and semantics.
- [x] Inspect product detail and producer profile circles; use public avatars only where the circle represents a person, not a map marker or category icon.
- [x] Confirm initial fallback remains visible for accounts without a photo or while loading an image.

### Task 5: Format and review the change

**Files:**
- All Dart files modified by Tasks 2–4.
- Review: migration and design/implementation plan.

- [x] Run `dart format` on changed Dart files.
- [x] Inspect `git diff --check` and the complete task diff for whitespace, unrelated changes, and accidental removal of existing behavior.
- [x] Do not run or add tests in this task, per the active developer instruction.
- [x] Apply the matching Supabase migration to the connected Agro project; it is available before the app saves private phone data.
