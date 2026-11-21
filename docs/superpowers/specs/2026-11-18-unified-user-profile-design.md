# Agro+ unified user profile

## Intent

Give each account one profile form in **Mis datos** and reuse its identity consistently across the app. This removes the duplicate chat-name/photo/phone controls while keeping private account data separate from information a user chooses to share.

## Goals

- Reuse one uploaded circular avatar in the account menu, app-bar profile action, chat, and profile views, with initials as fallback.
- Use first and last name as the display name everywhere, including chat; remove the separately editable chat name.
- Keep the farm/business name optional and relevant to producers.
- Keep the login email visible and read-only.
- Add one optional Ecuador mobile number with a fixed `+593` prefix; accept exactly nine local digits beginning with `9` and omit the trunk `0`.
- Store the phone privately; expose it to other signed-in users only after explicit opt-in to WhatsApp contact.
- Keep one form and one clear save action while reporting partial failures across private and public profile persistence accurately.

## Non-goals

- Changing sign-in credentials or adding Google sign-in.
- Collecting birth date, gender, or exact private address.
- Changing public producer map-location privacy or product contact flows.

## Constraints

- Account fields live in `public.usuarios`; public chat identity lives in `public.perfiles_contacto_publicos` and is readable to authenticated users.
- The existing public table requires `telefono_whatsapp` to be null when `whatsapp_visible` is false. A private phone therefore needs a separate private profile table with self-only RLS; the public row should contain a phone only while sharing is enabled.
- The app already uploads profile photos through Cloudinary and chat avatars already consume the public profile avatar URL.
- The email is managed by Supabase Auth and must not be edited by directly updating `usuarios`.

## Approaches considered

1. Keep two profile forms and add a third phone field. This preserves separation but increases duplication, so it does not meet the request.
2. Use one identity form with a canonical avatar, names, optional producer farm/business, read-only email, and one private phone plus explicit sharing opt-in. Mirror only the opted-in phone into the public chat profile. **Selected** because it gives users one clear form and preserves privacy.
3. Put all profile data into the public chat table. This simplifies reads, but would expose a private phone because authenticated users can read that table, so it is rejected.

## Behavior

The user edits a single profile screen. The avatar URL is saved once as the public avatar source and is loaded into the authenticated profile state so every own-profile avatar uses it. First and last name form the chat display name automatically. A phone can be stored without being visible; the separate opt-in controls whether its public projection is written. Disabling sharing clears the public projection but preserves the privately stored phone. Email remains read-only.

## Implementation choices left to the builder

- Add a nullable, validated private-phone table through a Supabase migration with self-only select/insert/update/delete policies.
- Preserve existing public profile rows and avatar URLs during migration.
- Make save status explicit if private account save succeeds but public identity save fails, so retrying does not suggest all data was rolled back.
- Keep the design aligned with the existing Agro+ green Material 3 style and compact mobile layout.
