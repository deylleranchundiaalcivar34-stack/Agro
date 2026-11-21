# Agro+ email authentication pages

Set `vercel-reset-password` as the Vercel project's root directory; it contains the confirmation and password recovery pages.

## Vercel environment variables

Set these values in the Vercel project settings for each environment that should serve the pages:

- `SUPABASE_URL`: the public URL of the Agro+ Supabase project.
- `SUPABASE_ANON_KEY`: the project's public anon/publishable key. Do not use a service-role or secret key here.

The `/api/config` function exposes only those public client settings to the static pages.

## Supabase Auth URL allowlist

In **Authentication → URL Configuration → Redirect URLs**, allow:

- `https://agroplus-recuperar.vercel.app/auth/confirm`
- `https://agroplus-recuperar.vercel.app/auth/reset-password`
- `io.supabase.agro://auth/callback`

The confirmation and reset destinations are passed separately by the Flutter client. Keep the mobile callback for Android builds.

## SMTP and email templates

Configure SMTP and the email content in the Supabase Dashboard. Keep the confirmation template's Supabase verification link (`{{ .ConfirmationURL }}`) so Supabase validates the one-time token before redirecting to the requested route. The recovery template should also link to `{{ .ConfirmationURL }}`; the Flutter recovery page requests `/auth/reset-password` as its return destination. Avoid hard-coding the Vercel root into either template because the client supplies the route for each flow.

If you choose to build a custom confirmation link with `{{ .TokenHash }}`, use `{{ .RedirectTo }}?token_hash={{ .TokenHash }}&type=signup`. The page can verify that token hash using the public Supabase client key.

The Vercel domain and the project Supabase URL must match the current deployment. SMTP credentials are not stored in this repository.
