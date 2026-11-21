# Agro+ email authentication routes

## Intent

Give email confirmation and password recovery distinct, branded destinations on the existing Vercel deployment, so users see the correct next step after opening each email.

## Goals

- Use `/auth/confirm` for signup confirmation and `/auth/reset-password` for password recovery.
- Preserve the existing Android deep link `io.supabase.agro://auth/callback`.
- Keep the existing recovery logic while bringing its page into the Agro+ visual style.
- Leave SMTP credentials and Supabase Dashboard changes to the project owner.

## Non-goals

- No new domain, payment provider, Supabase project, or authentication provider.
- No changes to SMTP credentials or remote Supabase/Vercel settings.

## Approaches

- Keep both flows at the Vercel root and infer the action from URL state: smallest change, but retains the confusing shared destination.
- Add two sibling paths on the existing domain: selected because each email flow gets its own page while reusing the current Vercel deployment and Supabase project.
- Create a separate confirmation domain: rejected because it adds DNS/deployment work without improving the flow.

## Design

Flutter web signup redirects to the confirmation path; native builds continue using the existing app deep link. The recovery screen remains the same static app, served at its new path through a Vercel rewrite. A dedicated confirmation page handles Supabase callback errors, token-hash verification, and successful callbacks. Both pages use a shared lightweight stylesheet and Agro+ logo. A setup note lists the exact redirect URLs and environment variable names for manual dashboard configuration.

## Constraints

- Do not modify SMTP settings or expose any Supabase secret key.
- Only the public Supabase URL and anon key may be used by the browser page.
- Keep the current recovery token validation and password-strength checks.
- Preserve unrelated working-tree changes.
