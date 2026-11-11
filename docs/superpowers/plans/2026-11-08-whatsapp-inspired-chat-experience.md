# WhatsApp-Inspired Chat Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Agro+ chat a fast, personal WhatsApp-inspired feel without changing the wider app design or exposing private account data.

**Architecture:** Keep the existing GoRouter persistent shell and Supabase message persistence. Add a separate opt-in public contact profile, use a private Supabase Realtime channel for ephemeral typing events, and keep a small in-memory message cache keyed by chat. Reuse the current Cloudinary unsigned image flow only for bounded public avatars, storing only the HTTPS result URL.

**Tech Stack:** Flutter/Dart, GoRouter, Supabase Flutter/Postgres RLS/Realtime, existing Cloudinary upload preset, existing image picker and cached image support.

**Spec:** `docs/superpowers/specs/2026-11-08-whatsapp-inspired-chat-experience.md`

## Global Constraints

- Preserve the user's existing working tree and build on current files; do not reset/revert unrelated changes.
- Keep welcome, splash, home, catalog, map, colors, and global navigation appearance unchanged.
- Keep `usuarios` private. Never expose email, private account name, or phone unless the owner explicitly publishes it.
- Realtime typing must be private to the chat's buyer and product owner; do not write typing events to `mensajes`.
- Use the current Cloudinary configuration without secrets in the mobile app. Do not change Cloudinary account settings or hosted Supabase schema during implementation without a separate review of the required setup.
- Do not add Firebase/FCM, status features, read receipts, reputation, or durable local message storage.

## Review Focus

- A participant cannot listen or send typing events for a conversation they do not belong to.
- A missing public profile, missing image, broken image URL, or disabled phone does not reveal private account data and does not break the chat.
- Opening/returning to a room does not show a blocking reload or lose current messages/draft state.
- Disconnect, route exit, app pause, sign-out, and participant changes unsubscribe from the correct Realtime channel and clear typing state.
- The existing Cloudinary preset is suitable for profile images; if it is not, stop at a documented configuration requirement instead of embedding a secret.

## File Map

- `lib/core/router/app_router.dart` and `lib/features/main/presentation/views/main_navigation_view.dart`: preserve shell identity and define stable chat list/room header behavior.
- `lib/features/chat/data/models/chat_conversation.dart`, `chat_message.dart`, and `lib/features/chat/data/repositories/chat_repository.dart`: participant display data, message cache, and scoped typing channel lifecycle.
- `lib/features/chat/presentation/views/chat_list_view.dart`, `chat_room_view.dart`, and focused chat widgets: list identities, room header/contact panel, message avatar/bubble grouping, typing state, first-load and empty states.
- `lib/features/auth/data/repositories/profile_repository.dart`, `lib/features/profile/presentation/views/profile_data_view.dart`, and focused profile widgets: owner controls for public display name, avatar, optional WhatsApp number, and visibility toggle.
- `lib/features/products/data/services/product_storage_service.dart`: reuse and constrain the existing Cloudinary upload flow for avatars without exposing secrets.
- New focused contact-profile data model/repository/widget files under `lib/features/profile/` or `lib/features/chat/` according to ownership; avoid adding unrelated responsibility to the navigation shell.
- New Supabase migration from `supabase migration new` for the public contact table, constraints, grants, RLS policies, and Realtime authorization.

## Implementation Tasks

### Task 1 — Add the opt-in public contact profile schema and repository

**Files:** new Supabase migration; new profile contact model and repository.

- [ ] Inspect current `usuarios`, chat/product relationships, existing role/participant policies, and migration conventions before defining SQL.
- [ ] Create a migration with a `perfiles_contacto_publicos` row keyed by user ID. Include public display name, nullable avatar URL, nullable phone, explicit phone visibility, and timestamps; set length/URL/phone constraints, including a check that the phone is null whenever visibility is off.
- [ ] Enable RLS and grant only authenticated reads of published rows. Restrict writes/deletes to the owner. Keep the phone absent from normal query projections unless visibility is enabled.
- [ ] Add model/repository functions for fetching a participant's public fields and saving/deleting the signed-in user's profile.
- [ ] Review the local SQL and RLS policy behavior for owner writes, authenticated reads of public fields, and continued isolation of private account fields.

### Task 2 — Configure public identity and optional profile image/contact

**Files:** `profile_data_view.dart`, new focused public-contact editor/avatar widgets, `product_storage_service.dart`, app dependencies only if existing picker/cache APIs are insufficient.

- [ ] Add a compact “Perfil público para chats” section in “Mis datos” for display name and optional photo.
- [ ] Add an opt-in phone field with a clear “Mostrar como WhatsApp” switch disabled by default; explain briefly that enabled numbers are visible to authenticated Agro+ users and clear the stored public number when switched off.
- [ ] Reuse `ProductStorageService` for validated, compressed square images and existing Cloudinary preset. Keep avatar size small; accept only JPG/PNG/WebP and HTTPS URLs; no secret key/signature in client code.
- [ ] Save public contact fields separately from `usuarios` and map location; preserve form values on upload/save failure and offer initials as fallback.
- [ ] Verify Android/iOS picker permission requirements and web compatibility before adding any platform configuration.

### Task 3 — Stabilize shell and load rooms progressively

**Files:** `main_navigation_view.dart`, `app_router.dart`, `chat_room_view.dart`, `chat_repository.dart`, new in-memory chat cache if warranted.

- [ ] Trace list-to-room/back navigation and preserve `MainNavigationView`/branch state; only change room-specific title content when the route changes.
- [ ] Keep a back affordance and conversation header in the existing shell; avoid a second freshly-built global header and avoid displaying the bottom module bar underneath an open room.
- [ ] Subscribe/start room data without setting `_loading = true` over already-rendered messages. Use inline first-load skeleton only when no cached messages exist.
- [ ] Add a bounded in-memory cache for recent messages per chat ID. Hydrate immediately on room reopen, then reconcile/dedupe/order server updates; clear on sign-out and do not persist messages to disk.
- [ ] Ensure route exit, retry, and changed room ID cancel old listeners and do not allow stale responses to overwrite the newly opened room.
- [ ] Verify deep-link/initial room open, room-to-room switch, back navigation, and reconnect behavior manually.

### Task 4 — Render participant identities and message avatars

**Files:** `chat_conversation.dart`, `chat_message.dart`, `chat_repository.dart`, `chat_list_view.dart`, `chat_room_view.dart`, new focused avatar/bubble/contact panel widgets.

- [ ] Batch-load only public contact records for the participants in the visible chat list; do not query `usuarios` for other users.
- [ ] Use configured display name in list/header/contact panel. For users who have not configured one, use existing public alias if available, otherwise a neutral “Usuario de Agro+” fallback rather than “Productor.”
- [ ] Show a small avatar next to incoming and outgoing message groups with initials and failed-image fallbacks; keep bubbles in Agro+ colors and preserve readable contrast.
- [ ] Make the header open contact details showing public display name/photo and the product context. Show WhatsApp number and open WhatsApp only when `whatsapp_visible` is true and a valid number exists.
- [ ] Keep product identity visible as context without replacing the participant's actual name.
- [ ] Verify buyer↔producer and producer↔buyer conversations and missing/disabled profile field cases.

### Task 5 — Add secure ephemeral typing indicator

**Files:** chat repository or a focused Realtime typing service; `chat_room_view.dart`; new Supabase migration policies if required.

- [ ] Use current Supabase Flutter Realtime APIs from the official docs; use a private channel topic scoped to the chat and a minimal typing payload.
- [ ] Add narrow authorization policies that validate the authenticated user is the chat buyer or the product owner for that exact chat. Avoid a policy that grants all authenticated users access to all `realtime.messages`.
- [ ] Debounce typing events; stop on send, focus loss, room exit, app pause, sign-out, and inactivity timeout. Treat disconnect as not typing.
- [ ] Display a lightweight “está escribiendo…” subtitle/indicator only for the other participant and only while fresh events are received.
- [ ] Verify with two authorized sessions and one unrelated session that events are visible to the two participants only and expire after pause/disconnect.

### Task 6 — Polish and verify the complete chat flow

**Files:** focused chat widgets and relevant tests only.

- [ ] Keep motion subtle and short; respect reduced-motion settings and the existing app motion policy.
- [ ] Verify first open, return to cached room, send/receive, empty room, offline/reconnect, disabled/missing avatar, hidden/published phone, producer and buyer roles, and cleanup on route exit.
- [ ] Inspect the final diff for unrelated navigation/theme edits and walk through the chat flows on Android and web; prepare iOS settings without claiming an iOS device run.
- [ ] Review generated migration and RLS with the user before any hosted Supabase application. Report Cloudinary preset changes as a separate manual setup if required.

## Rollout Boundary

Implementation may add local migration files and app code after the user approves this plan. Do not apply the migration to hosted Supabase or alter Cloudinary settings until the exact SQL/configuration has been reviewed and the user explicitly requests that deployment step. Before relying on private typing channels, confirm Supabase Realtime's “Allow public access” setting is disabled; review any existing public-channel dependencies before changing it.
