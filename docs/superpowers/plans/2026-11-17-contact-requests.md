# Product Contact Requests Implementation Plan

> **For agentic workers:** Use the executing-plans skill to implement this plan task by task. Steps use checkbox syntax for tracking.

**Goal:** Replace the invisible product-interest action with a traceable contact request that the producer can accept or reject before a chat is created.

**Architecture:** Store contact requests separately from orders and legacy pre-sale interest records. Supabase RLS limits each request to its buyer and the product owner; an invoker RPC accepts/rejects the request and creates the chat atomically. Database triggers create in-app notifications. Flutter provides an editable inquiry form and a Solicitudes section alongside existing Chats.

**Tech Stack:** Flutter/Dart, Supabase Postgres/PostgREST/RLS, existing GoRouter and Material 3 UI.

**Spec:** Approved conversational design in the current Agro+ Codex thread, 2026-11-17.

## Global Constraints

- Preserve unrelated user edits already present in the worktree.
- Do not add payment processing or represent a contact request as an order.
- Keep existing chat records and legacy `intereses_preventa` data intact.
- Use existing Agro+ colors and responsive list patterns.
- Run the requested Windows debug launch after implementation.

## Review Focus

- A buyer cannot request their own product or a hidden/out-of-stock product.
- Only the product owner can accept or reject a pending request.
- Duplicate acceptance cannot create duplicate chats or notifications.
- Requests remain visible and clearly pending to the buyer; chats remain distinct from orders.
- Empty, loading, error, and rejected states remain understandable on Windows and narrow layouts.

---

### Task 1: Contact request database and notifications

**Files:** Create a Supabase migration; update the checked-in migration folder.

- [x] Create `solicitudes_contacto` with buyer, product, quantity, editable initial message, status, timestamps, and optional chat relation.
- [x] Add authenticated RLS policies for buyer creation, participant reads, and producer responses; add an invoker RPC that atomically changes status and creates/reuses the conversation on acceptance.
- [x] Add notification reference columns and narrowly scoped triggers for new request and producer response events.
- [x] Verify schema, policies, RPC, and notification trigger with read-only SQL queries.

### Task 2: Buyer inquiry form and repository

**Files:** Create contact request model/repository; update product detail and map contact entry points; add focused Dart tests.

- [x] Write failing tests for request parsing and generated editable inquiry text.
- [x] Replace the “Registrar interés” action with “Consultar al productor”; capture quantity and prefilled editable message and persist a request.
- [x] Keep the old pre-sale interest repository data untouched; do not create an order here.
- [x] Run the focused tests.

### Task 3: Requests inbox and producer response

**Files:** Update chat list view and add request inbox widgets/repository integrations; update notification model/navigation if necessary; add focused UI tests.

- [x] Write failing tests for pending request presentation and producer actions.
- [x] Add a Solicitudes section for buyer and producer; show product, requested quantity, message, and status.
- [x] Let only the producer accept or reject; acceptance opens the resulting chat, rejection leaves the request visible with its status.
- [x] Show in-app notifications with request context and refresh behavior.
- [x] Run focused tests and static analysis.

### Task 4: Windows visual verification

**Files:** No source changes unless the requested launch exposes a regression.

- [x] Run `flutter run -d windows --debug` using the existing project environment.
- [x] Confirm the Windows target builds and opens; report any environment limitation precisely.
