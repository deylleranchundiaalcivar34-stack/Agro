# Mobile-first, role-aware navigation — short design

## Intent

Make Agro+'s shared navigation more minimal and mobile-first while keeping the same visual composition at every window size and showing only actions that fit the signed-in role. Use the existing Material 3 theme, green palette, routes, and logo.

## Goals

- Keep one fixed, horizontal bottom navigation at every size with the four existing destinations: Inicio, Comprar/Catálogo, Mapa, Chat. Producer publishing remains a prominent action. Do not replace it with a rail or sidebar on wide windows.
- Adapt only its geometry to available width: use the available width on phones and center it with a sensible maximum width on wide windows, keeping the same order, icon/label treatment, and selected state.
- Use a compact, left-aligned Agro+ brand in the shared top bar. The profile action opens the same lightweight account drawer at every size; constrain its width to the viewport on phones and a comfortable fixed maximum on wide windows without changing its content hierarchy.
- Use outlined, legible icons; neutral inactive states; a restrained green selected state; short transitions that respect reduced-motion settings.
- Use the account drawer as the only account hub; do not keep a separate Profile dashboard with duplicate shortcuts.
- Make the drawer identity header open Mis datos. Push account destinations so Back returns to the module that launched the drawer.
- Keep `/profile` as a compatibility redirect to `/profile/data`; account destinations are independent routes, not children of a Profile dashboard.
- Account subpages use the same compact Agro+ app bar, surface/background colors, typography, and spacing as the main modules. The public-zone editor must use that shared frame too.
- Keep account-page navigation snappy with a short 150 ms transition that respects reduced-motion settings; keep the existing data loading behavior and show clear loading/error states.
- Use the same surface-colored, logo-led app bar on authenticated product detail/form and public producer pages. Chat rooms retain the other participant's avatar and name but use the same light app-bar palette.
- Main module changes use the existing 180 ms branch motion; standard detail routes use a restrained 180 ms transition. Keep splash, welcome, and authentication screens on their own brand treatments.

## Role mapping

- **Comprador:** Inicio, Comprar, Mapa, Chat; account links for pedidos, favoritos, datos, notificaciones, seguridad, ayuda, and cerrar sesión.
- **Productor:** same core modules plus Publicar; account links also include Mis publicaciones and Mi zona pública.
- **Administrador:** keep only the destinations and account actions that already exist. Do not invent an admin dashboard or admin-only destinations in this change. Hide buyer-specific links unless current route authorization supports them.

## Approaches considered

1. **One mobile-first composition (selected):** keep the horizontal bottom bar and account drawer at all sizes; adjust only spacing and maximum width. This preserves the mobile-first design in the Windows preview too.
2. **Different navigation by width:** use bottom navigation on phones and a side rail on tablets/desktop. This uses wide layouts efficiently but changes the composition between devices, which the user does not want.
3. **Hide navigation while scrolling:** gains temporary space but repeats the flicker and layout shift already removed.

## Implementation calls

- Use width-aware sizing for margins, constraints, and icon spacing only; do not switch navigation components at breakpoints. Keep labels legible and tap targets at least 48 px.
- Keep scrolling behavior and fixed bottom navigation from the previous change. Do not add blur, large shadows, new dependencies, or per-item entrance animations.
- Keep the account drawer lightweight and role-aware. Do not duplicate its options on another screen.
- Keep the same screen layout on every device size and use the established Agro+ color and type tokens; simplify account-only decoration that clashes with the restrained main modules.
- Preserve shell branch state when changing main modules, and avoid default route transitions longer than the app's own motion settings.
- Scope is the shared navigation, top bar, account drawer, and role visibility. No new backend behavior or routes.

## Acceptance

At phone, tablet, and wide window sizes, navigation should retain the same horizontal composition and fit without clipping; the account drawer should retain the same structure; role-specific entries should be correct; current module selection, refresh, account data access, publish, and existing routes should continue to work; authenticated module/detail pages share the Agro+ header palette and appropriate content identity; main, detail, and account transitions use short reduced-motion-aware durations; the bottom bar stays visible while scrolling; returning from an account destination restores its source module without an intermediate Profile dashboard; welcome/login/splash remain visually independent.
