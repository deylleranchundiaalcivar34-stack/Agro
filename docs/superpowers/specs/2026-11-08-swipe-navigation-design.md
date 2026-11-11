# Agro+ Swipe Navigation Design

## Intent

Make switching between Agro+'s main mobile modules feel like turning a page: the neighboring module follows the finger while the person drags, then settles into place when released.

## Goals

- Support the main module order: Inicio, Comprar, Mapa, Chat.
- Dragging left follows the finger toward the next module; dragging right follows it toward the previous module.
- Reuse GoRouter's `StatefulNavigationShell` and its branch Navigators so each module keeps its navigator, route stack, and view state.
- Keep the bottom navigation as a direct way to select modules and synchronize it with the page position.
- Keep the producer `+` action as a publish action, not a page.
- Keep scroll-based bottom-bar visibility.

## Non-goals

- Replacing the GoRouter branch system with a second navigation source.
- Swiping into profile, product details, product forms, or chat rooms.
- Changing login, startup, welcome, splash, or module business logic.

## Approaches considered

1. **Animate after the finger is released.** Rejected because the content does not track the drag and the user reported that it felt delayed.
2. **Replace app navigation with an independent `PageView`.** Rejected because GoRouter must remain the source of truth for branch routes and must preserve each branch's navigator state.
3. **Use `PageView` as GoRouter's `StatefulShellRoute.navigatorContainerBuilder`.** Selected. GoRouter 14.8.1 includes this supported container pattern. It lets the page follow the finger while `onPageChanged` selects a GoRouter branch; the bottom bar selects a GoRouter branch and animates the controller to it.

## Interaction rules

- The page follows horizontal finger movement continuously; on release it settles to the adjacent page when the drag crosses the page threshold, otherwise returns to the current page.
- The main order is Inicio, Comprar, Mapa, Chat; swipes never wrap at either end.
- Enable user-driven paging only on those four root destinations, excluding Mapa and all nested routes. Use the bottom bar to leave Mapa or a nested route.
- On Mapa, horizontal drags stay available for map panning. The bottom bar can still select another module and programmatically move the page container.
- Bottom-bar taps and swipes stay synchronized with `StatefulNavigationShell.currentIndex`.
- Keep the producer center `+` button unchanged.
- Bottom-bar taps use a short 160 ms transition; direct finger drags are controlled by the finger and do not add a post-release delay.
- Respect reduced-motion preferences for programmatic movement; direct touch tracking remains spatially tied to the finger.

## Constraints

- The project uses GoRouter 14.8.1 and a `StatefulShellRoute` with four main branches; profile is outside those branches.
- Keep all branch Navigators supplied by `navigatorContainerBuilder` in the `PageView` children.
- Preserve bottom-bar accessibility, selected state, and scroll visibility behavior.
- Preserve map pan and zoom behavior by disabling PageView user scrolling on Mapa.
