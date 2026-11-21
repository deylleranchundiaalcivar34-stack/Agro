# Email Authentication Routes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate Agro+ signup confirmation and password recovery into distinct branded Vercel routes.

**Architecture:** Flutter supplies the correct redirect URL for each flow; Vercel maps two clean paths to static pages. The existing recovery behavior stays in its current JavaScript flow and the new confirmation page handles successful and failed Supabase callbacks.

**Tech Stack:** Flutter/Dart, static HTML/CSS/JavaScript, Supabase Auth, Vercel rewrites.

**Spec:** `docs/superpowers/specs/2026-11-18-email-auth-routes-design.md`

## Global Constraints

- Keep native signup redirects on `io.supabase.agro://auth/callback`.
- Do not change SMTP credentials or remote dashboard configuration.
- Never place a Supabase service-role or secret key in browser code.
- Preserve unrelated working-tree changes.

## Review Focus

- Signup on native builds still uses the app callback URI.
- Web signup returns to `/auth/confirm`.
- Recovery links return to `/auth/reset-password` and retain the current token handling.
- Invalid, expired, or absent confirmation callbacks do not show a false success state.
- Rewritten routes load scripts, styles, logo, and `/api/config` from absolute deployment paths.

---

### Task 1: Route Auth emails from Flutter

**Files:** `lib/core/app_constants.dart`, `lib/features/auth/presentation/viewmodels/auth_viewmodel.dart`

- [x] Add named Vercel URLs for email confirmation and password recovery.
- [x] Set web signup to the confirmation URL and preserve the existing native callback.
- [x] Point the Flutter recovery entry point to `/auth/reset-password`.

### Task 2: Restyle the recovery page without changing its auth behavior

**Files:** `vercel-reset-password/index.html`, `vercel-reset-password/app.js`, `vercel-reset-password/auth.css`, `vercel-reset-password/assets/agro-logo.png`

- [x] Replace utility-CDN styling with shared responsive Agro+ CSS and semantic classes.
- [x] Keep all existing recovery states and validation; use absolute paths for assets and modules.
- [x] Redirect reset email callbacks to `/auth/reset-password`.

### Task 3: Add signup confirmation route

**Files:** `vercel-reset-password/auth/confirm.html`, `vercel-reset-password/auth-confirm.js`, `vercel-reset-password/vercel.json`

- [x] Add branded loading, success, expired/invalid, and missing-link states.
- [x] Handle token-hash confirmation through Supabase Auth and successful confirmation callbacks.
- [x] Rewrite `/auth/confirm` and `/auth/reset-password` to their static page targets.

### Task 4: Document manual dashboard setup and validate the patch

**Files:** `vercel-reset-password/README.md`

- [x] Document the Vercel environment variable names, Supabase redirect allowlist URLs, and SMTP/template work the owner must complete.
- [x] Run `node --check` on the JavaScript modules and `git diff --check`; do not run or add tests unless requested. Also ran `dart analyze` on the two touched Dart files and parsed `vercel.json`.
