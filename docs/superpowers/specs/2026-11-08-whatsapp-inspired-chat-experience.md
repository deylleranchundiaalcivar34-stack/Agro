# Agro+ chat experience refresh

## Intent

Make Agro+ conversations feel immediate, personal, and easy to understand, borrowing familiar chat patterns from WhatsApp while keeping Agro+'s visual identity and marketplace purpose. The experience should make it clear who is on the other side, show who sent each message, indicate when the other participant is typing, and avoid making a returning user wait through a full-page reload.

## Current state

- Chat list and room are nested under the persistent navigation shell in `lib/core/router/app_router.dart`.
- `MainNavigationView` hides the main app bar on nested routes. The room then loads its own app bar, and `ChatRoomView` starts with a full-screen spinner while it fetches the conversation and starts the messages stream.
- The room shows the product name and a producer alias. `ChatRepository` gets that alias from `ubicaciones_productores_publicas`; when the producer has not published a map area, the room can fall back to the generic label “Productor.”
- Each `ChatMessage` has a sender ID but no sender display profile or avatar.
- `usuarios` contains account data and is not suitable for public profile reads. The voluntarily published location table is authenticated-readable, but profile contact information should not depend on a user publishing a map location.
- Product images already use an unsigned Cloudinary upload preset in `ProductStorageService`; no public profile photo/contact fields currently exist.

## Goals

- Keep the chat navigation shell stable while opening a room. Avoid a flash/reload of the global header; transition the header content to the active conversation without resetting the room unnecessarily.
- Show the other participant's public display name and optional profile photo in the conversation header. A tap opens a compact contact/profile panel with the product being discussed, public display name, photo, and an optional WhatsApp phone number only if that user explicitly chose to publish it.
- Show a small sender avatar beside incoming and outgoing messages, with initials when no photo is published.
- Show a short-lived “está escribiendo…” indicator while the other participant is composing, using Supabase Realtime and without saving typing events in `mensajes`.
- Reopen a conversation quickly: reuse messages already in memory, render cached content immediately, then reconcile with the latest server state. First-time loads use a compact skeleton/inline progress treatment rather than replacing the entire screen.
- Preserve current message persistence, participant access, app green palette, product context, and accessible controls.
- Let users configure a public display name and optionally publish a profile picture and WhatsApp contact number. The number is off by default and must be explicitly enabled.

## Non-goals

- No WhatsApp account linking, message forwarding, calls, groups, statuses, channels, read receipts, or end-to-end encryption claim.
- No Firebase or FCM migration; typing and chat updates continue to use Supabase.
- No public exposure of account email, private legal name, exact private location, or unpublished phone data.
- No redesign of welcome, splash, catalog, map, or global navigation visuals beyond keeping the shell stable around chat routes.
- No ratings/reputation changes in this project; those need verified completed orders and a separate design.

## Approaches considered

1. **UI-only polish:** adjust bubbles and titles using existing aliases. This is quick but cannot show real participant photos/contact settings, does not fix the missing-name fallback, and cannot safely implement typing.
2. **Add fields to the public-location row:** simple migration, but ties a chat identity to publishing a map location and makes phone/photo sharing too easy to couple to a different privacy choice.
3. **Separate opt-in public contact profile (recommended):** add a small authenticated-read profile record independent of map publication, with owner-only writes and explicit phone visibility. Keep existing location rows for map behavior. This adds a migration and user settings, but provides the clearest privacy boundary and solves the generic “Productor” label.

## Proposed design

Use approach 3. Create an opt-in public contact profile keyed to `usuarios.id_usuario`, containing a public display name, optional HTTPS avatar URL, optional phone number, and an explicit `whatsapp_visible` flag. Authenticated users may read only published contact profiles; each user may insert/update/delete only their own row. When WhatsApp visibility is off, the stored public phone field must be null (enforced by a database constraint), so a broad query cannot reveal a hidden number. The app never falls back to another user's private email or private account fields. Existing public map alias may seed the display name only through the user's own explicit save flow; it does not automatically expose private name data.

Reuse the currently configured Cloudinary upload path for square, compressed profile images if the existing unsigned preset supports the required image limits and foldering. Store only the resulting HTTPS URL in Supabase. No Cloudinary secret or Supabase service key may enter the Flutter client. If the upload preset needs a policy change, do not silently change the Cloudinary account; report that as an external setup requirement.

Use a private Supabase Realtime channel scoped to the conversation for an ephemeral typing event. Authorization must check that `auth.uid()` is either the chat buyer or the producer of that chat's product. The client debounces typing events, sends an inactive event after sending or losing focus, and expires stale indicators. Messages continue to be stored in `mensajes` and use the existing conversation access rules.

Keep the chat list/room under a persistent shell. The shell header should remain mounted through list-to-room navigation; in a room, its title area becomes the participant identity and typing state, and tapping it opens contact details. Keep the room route's back affordance and avoid showing the full main-tab header underneath it. Cache a modest recent-message window in process memory by chat ID; render it before network refresh, clear it on sign-out, and do not add durable local message storage in this change.

## Visual direction

- Familiar chat spacing and rounded message bubbles, but use Agro+ green/surface colors and current typography.
- Incoming and outgoing bubbles remain easy to distinguish with text contrast meeting the app theme.
- Show a small avatar at the outer edge of each message group; do not repeat it on every adjacent message from the same sender unless needed for clarity.
- Header contains back, avatar, public name, typing/short context line, and a contact-info action.
- Empty state, offline state, first-load skeleton, reconnect, and send failure remain calm and inline; no repeated blocking spinner or heavy entrance animation.

## Privacy and security requirements

- Public profile data is opt-in and separate from `usuarios` and map location publication.
- Phone number is blank/off by default. If disabled, remove it from the public record; if enabled, label it as public and provide an explicit hide control.
- The profile table is in an exposed schema only with RLS enabled and narrowly scoped policies. No `service_role` key, secret upload signature, or private email may be sent to the app.
- Typing events are ephemeral and private to the two participants. Presence/typing must be cleared or expire after disconnect.
- Validate and bound the display name, phone input, image MIME/size, and URL scheme.

## Acceptance criteria

- Opening a room from the chat list does not flash/rebuild the global shell header and does not replace returning messages with a full-screen spinner.
- The room header and contact panel show the configured public name; if unset, a safe neutral fallback is used and no private account fields are exposed.
- A photo appears in the header/contact panel and at incoming/outgoing message groups when available; initials render when absent or the image fails.
- Phone/WhatsApp actions appear only when the participant explicitly published and enabled the number; otherwise no number or action is rendered.
- Typing appears for the other participant in real time, clears after send/inactivity/disconnect, and cannot be observed by non-participants.
- Existing chat send/receive and access rules remain intact; chat changes do not alter other module designs.

## Scope boundary

This design includes a local Supabase migration and client code. Reviewing the migration and RLS locally is part of implementation; applying schema changes to the hosted Supabase project remains a separate, explicit deployment step after the user has reviewed the SQL and rollout notes. Before typing channels can be treated as private in production, verify that Supabase Realtime's “Allow public access” setting is disabled, as required by the current private-channel authorization guide. Do not change that hosted setting as part of this local implementation.
