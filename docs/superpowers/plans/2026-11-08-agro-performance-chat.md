# Agro+ Chat Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep chat current in real time while bounding initial history, preventing duplicates/gaps, and preserving the reader's scroll position.

**Architecture:** Fetch the most recent message page with a deterministic `(fecha_hora_envio, id_mensaje)` order, then merge it with filtered insert events from a Realtime channel for the active chat. Deduplicate by message ID, load older pages on demand, and cancel Realtime when leaving the room.

**Tech Stack:** Flutter, `supabase_flutter` 2.18.x, Supabase Postgres Changes/Realtime, Flutter tests, `ListView.builder`.

**Spec:** `docs/superpowers/specs/2026-11-08-agro-performance-design.md`

## Global Constraints

- Preserve chat authorization through existing RLS and authenticated identities.
- Only subscribe to the active chat and unsubscribe on route disposal/chat ID change.
- Initial history is bounded; new events are neither lost nor duplicated during subscription setup.
- Keep current message length validation, send failure behavior, order and buyer/producer access.
- Do not add FCM or a new messaging provider as a performance fix.

## Review Focus

- Realtime insert arrives before initial query returns: final timeline contains it once.
- Same message appears in query and realtime: deduplicate by `id_mensaje`.
- Older page loads while a new message arrives: preserve order and both messages.
- User reads older messages: incoming message does not yank scroll to bottom.
- Room closes or reconnects: no orphan channel or duplicate listener.

## Readiness Gate

The live database currently has 0 chats and 0 messages, so there is no representative long conversation for a safe Realtime/pagination change. Keep the current implementation until a real/seeded chat has more than one page of history or Profile evidence shows message-history cost. When this gate opens, keep the test requirements below; do not deploy a migration or weaken RLS to create test data.

---

### Task 1: Add deterministic paginated chat history

**Files:**
- Modify: `lib/features/chat/data/repositories/chat_repository.dart`
- Create: `lib/features/chat/data/models/chat_message_page.dart`
- Test: `test/chat_repository_test.dart`

**Interfaces:**
- Add `Future<ChatMessagePage> recentMessages(String chatId, {int limit = 40})`.
- Add `Future<ChatMessagePage> olderMessages(String chatId, {required DateTime before, required String beforeId, int limit = 40})`.
- `ChatMessagePage` exposes immutable ascending `items`, `hasMore`, and the cursor for its oldest row. Query newest-first with `limit + 1`, then reverse to ascending for the timeline.

- [ ] **Step 1: Add failing repository request tests** — assert bounded newest query, stable tie-breaking by ID, older cursor boundary, and empty/final page behavior.
- [ ] **Step 2: Verify RED** — run `flutter test --no-pub test/chat_repository_test.dart`; expected: new page API assertions fail.
- [ ] **Step 3: Verify installed Realtime API** — use the pinned `supabase_flutter` docs/API for the exact Postgres Changes filter and subscription lifecycle before implementation.
- [ ] **Step 4: Implement paged query** — preserve selected columns and filter by `id_chat`; do not change RLS or expose another room.
- [ ] **Step 5: Verify GREEN** — rerun `flutter test --no-pub test/chat_repository_test.dart`; expected: page order/cursor tests pass.

### Task 2: Merge initial page with active-room Realtime events

**Files:**
- Modify: `lib/features/chat/data/repositories/chat_repository.dart`
- Create: `lib/features/chat/data/services/chat_message_timeline.dart`
- Test: `test/chat_repository_test.dart`

**Interfaces:**
- Add a filtered `watchNewMessages(String chatId)` stream for inserts to `public.mensajes` where `id_chat` matches.
- `ChatMessageTimeline` exposes `List<ChatMessage> items`; `void seedRecent(List<ChatMessage> page)`, `bool mergeLive(ChatMessage message)`, and `void prependOlder(List<ChatMessage> page)` deduplicate by ID and retain ascending order. `mergeLive` returns true only when the event was new.

- [ ] **Step 1: Add failing timeline tests** — cover event-before-query, overlap/dedup, equal timestamps, and older page plus new event.
- [ ] **Step 2: Verify RED** — run focused chat repository tests; expected: timeline race/dedup tests fail.
- [ ] **Step 3: Implement merge and subscription setup** — subscribe before/while fetching the initial page, buffer or merge early events, then reconcile by ID; handle channel status/error without surfacing secrets.
- [ ] **Step 4: Verify GREEN** — rerun repository tests; expected: every event appears once and in order.

### Task 3: Wire paged timeline into chat UI

**Files:**
- Modify: `lib/features/chat/presentation/views/chat_room_view.dart`, `lib/features/chat/presentation/views/chat_list_view.dart`
- Test: `test/chat_flow_test.dart`

**Interfaces:**
- Replace full-history stream state with the timeline service; `ChatRoomView` requests older pages when the user reaches the top and receives only active-room events.
- Scroll-to-bottom occurs only when already near the latest message or after the current user sends; older-history loads preserve the visual anchor.
- Add a bounded conversation list page if baseline confirms material cost; do not alter its buyer/producer labels.

- [ ] **Step 1: Add failing widget tests** — verify recent load, load-older, event arriving during paging, duplicate suppression, scroll-anchor preservation, send scroll behavior, and route disposal.
- [ ] **Step 2: Verify RED** — run `flutter test --no-pub test/chat_flow_test.dart`; expected: new pagination/live-update assertions fail.
- [ ] **Step 3: Implement UI state and lifecycle** — keep ListView.builder, gate requests to one at a time, cancel subscriptions in `dispose`, and retain current retry/send feedback.
- [ ] **Step 4: Verify GREEN and analyze** — rerun chat tests and `flutter analyze --no-pub`; expected: pass.
- [ ] **Step 5: Profile on device** — test both a short chat and long history with slow network, reconnect and background/foreground; verify no duplicate/lost messages or scroll jumps.
