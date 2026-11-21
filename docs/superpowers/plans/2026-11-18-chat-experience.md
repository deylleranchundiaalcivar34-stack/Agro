# Chat Experience Implementation Plan

**Goal:** Make Agro+ conversations feel clear and reliable, with the latest messages anchored at the bottom, truthful read receipts, and private image attachments.

**Architecture:** Keep chronological message data in `ChatRepository`; render it in a reversed, bottom-anchored timeline. Store each participant's read cursor in `chats_lecturas`, and store image paths in a private Supabase Storage bucket with participant-scoped RLS.

**Tech Stack:** Flutter, Supabase Flutter v2, Postgres RLS, Supabase Storage, `image_picker`, `cached_network_image`, `flutter_animate`.

**Spec:** Approved chat proposal in the conversation dated 2026-11-18.

## Global Constraints

- Use Agro+ colors and typography; do not copy another messaging app's branding.
- Keep image uploads limited to JPG, PNG, and WebP, with a 5 MB client limit.
- Keep chat attachments in a private bucket readable only by chat participants.
- Show `Enviado` after database persistence and `Leído` only after the other participant's read cursor passes the message timestamp.
- Do not add emoji, sticker, or reaction controls.

## Review Focus

- A short conversation must remain anchored to its latest message above the composer.
- Incoming messages must not move a participant who is browsing older history.
- A read receipt must advance only while the recipient is active at the latest messages.
- Invalid or oversized files must not be uploaded.
- Non-participants must not read or upload chat attachments.

## Files

- `lib/features/chat/data/models/chat_message.dart`: message type and optional attachment metadata.
- `lib/features/chat/data/models/chat_conversation.dart`: latest message preview type.
- `lib/features/chat/data/repositories/chat_repository.dart`: private upload, signed image URLs, messages stream, and read cursor persistence.
- `lib/features/chat/presentation/views/chat_room_view.dart`: bottom-anchored timeline, image attachment, date labels, unread-new-message affordance, and read label.
- `lib/features/chat/presentation/views/chat_list_view.dart`: conversation cards and image preview.
- `supabase/migrations/*chat_read_receipts_and_images.sql`: message metadata, read cursor RLS, private bucket, and participant storage policies.

## Tasks

1. Add the read cursor and private image bucket schema with RLS and realtime publication.
2. Extend message persistence and model parsing for image attachments and signed reads.
3. Rework the conversation room composer, message timeline, date labels, image viewer, and read indicator.
4. Update conversation cards to present product context and image previews.
5. Run static analysis and verify the migrated schema's RLS, bucket privacy, columns, and publication.
