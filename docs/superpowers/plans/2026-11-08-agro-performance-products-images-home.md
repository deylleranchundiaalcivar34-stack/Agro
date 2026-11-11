# Agro+ Marketplace, Images, and Home Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make marketplace and home data load in bounded pages and render correctly sized cached product images without changing buyer/producer workflows.

**Architecture:** Keep `ProductsViewModel` as the shared state owner. Add explicit, stable server-side pages in `ProductsRepository`, append/deduplicate pages in view state, and reuse the first page for home discovery. Transform Cloudinary URLs only when they match a verified Cloudinary delivery URL.

**Tech Stack:** Flutter/Dart, Supabase PostgREST, `cached_network_image`, Cloudinary image delivery, Flutter widget/repository tests.

**Spec:** `docs/superpowers/specs/2026-11-08-agro-performance-design.md`

## Global Constraints

- Keep product ownership, publication visibility, sort order, filters, relationships, and RLS behavior unchanged.
- Confirm Supabase row limits and relevant indexes before selecting page size; start at 20 only if baseline/query limits support it.
- Do not change Cloudinary account, preset, upload credentials, or provider; unknown/non-Cloudinary URLs remain unchanged.
- Home, catalog, product detail, publish, edit, and image fallback remain functional offline/under slow network.
- Avoid pulling the complete public catalog into the map; map-specific retrieval belongs to the map plan.

## Review Focus

- Search/category change during a pending page request: stale results do not append to the new filter.
- Duplicate products at page boundaries or concurrent refresh: one product appears once and ordering remains stable.
- Empty, failed, and final page: correct empty/error/retry/no-more state.
- Missing, malformed, or non-Cloudinary image URL: app keeps the existing placeholder/error state.
- Very large source image on a small screen: rendered/decode dimensions do not inflate memory unnecessarily.

---

### Task 1: Define bounded product pages

**Files:**
- Modify: `lib/features/products/data/repositories/products_repository.dart`
- Create: `lib/features/products/data/models/product_page.dart`
- Test: `test/product_catalogue_test.dart`

**Interfaces:**
- Add `Future<ProductPage<AgriculturalProduct>> getPublishedProductsPage({required int offset, required int limit, int? categoryId, String? searchQuery})`.
- `ProductPage<T>` exposes immutable `List<T> items`, `bool hasMore`, and nullable `int? nextOffset` (null when final); `hasMore` is computed from receiving `limit + 1` rows then trimming to `limit`.
- Preserve a non-paginated compatibility method only for callers explicitly requiring all data; remove its use from home/catalog after migration.

**Readiness gate:** The live table currently contains 8 products and 6 image rows. Do not implement pagination or URL transformations unless Profile traces show material transfer/decode delay, image sources exceed the display size enough to warrant resizing, or the catalog grows past a single proposed page. Record the evidence and mark the affected tasks deferred otherwise.

- [ ] **Step 1: Add failing repository tests** — assert `.range(offset, offset + limit)`/extra-row behavior, stable `created_at` then `id_producto` ordering, category/search server filtering, and optional-unit retry retaining page/filter parameters.
- [ ] **Step 2: Verify RED** — run `flutter test --no-pub test/product_catalogue_test.dart`; expected: new page assertions fail.
- [ ] **Step 3: Inspect schema constraints** — confirm the project row limit, category relationship filter syntax, and existing indexes from schema/query plans; if search requires a schema/index change, stop and propose it separately.
- [ ] **Step 4: Implement page model and repository query** — use the agreed 20-row page if supported, explicit columns, stable sort, and `limit + 1`; escape user search input for PostgREST patterns.
- [ ] **Step 5: Verify repository tests** — run `flutter test --no-pub test/product_catalogue_test.dart`; expected: all page, filter, relation, and compatibility assertions pass.

### Task 2: Accumulate pages safely in the shared view model

**Files:**
- Modify: `lib/features/products/presentation/viewmodels/products_viewmodel.dart`
- Test: `test/product_catalogue_test.dart`

**Interfaces:**
- Add `loadNextCataloguePage()` and expose `hasMoreProducts`/`isLoadingMore` separately from first-page `catalogueStatus`.
- A changed query/filter resets page state; only one next-page request runs at once; concurrent refresh invalidates older in-flight results.

- [ ] **Step 1: Add failing view-model tests** — cover first page, append, duplicate ID suppression, request coalescing, refresh reset, filter change during pending load, and end-of-results.
- [ ] **Step 2: Verify RED** — run the focused product catalogue tests; expected: the page-state assertions fail.
- [ ] **Step 3: Implement bounded state transitions** — preserve the existing private publication list separately from public results.
- [ ] **Step 4: Verify GREEN** — rerun `flutter test --no-pub test/product_catalogue_test.dart` and `flutter analyze --no-pub`.

### Task 3: Wire home and catalog to incremental results

**Files:**
- Modify: `lib/features/products/presentation/views/products_catalog_view.dart`, `lib/features/home/presentation/views/home_view.dart`, `lib/features/home/data/repositories/home_summary_repository.dart`
- Test: `test/product_catalogue_test.dart`, `test/home_viewmodel_test.dart`

**Interfaces:**
- Catalog reads page state from `ProductsViewModel`; home shows the first recent page and does not trigger a second complete product download.
- Keep current local buyer/producer visibility rules and category/search behavior across pages.

- [ ] **Step 1: Add failing widget tests** — verify next-page loading at list end, filter changes begin at page one, home uses bounded results, and producer does not see own products in discovery.
- [ ] **Step 2: Verify RED** — run `flutter test --no-pub test/product_catalogue_test.dart test/home_viewmodel_test.dart`; expected: the new incremental-loading assertions fail.
- [ ] **Step 3: Implement catalog paging UI** — request the next page once near the end, show a small footer loading/error retry, and preserve scroll position on refresh and return from detail.
- [ ] **Step 4: Implement home reuse** — consume first-page shared state and keep the separate summary counts behavior; avoid duplicate list reloads after normal rebuilds.
- [ ] **Step 5: Verify GREEN** — rerun the focused widget tests; expected: all paging/filter/navigation assertions pass.

### Task 4: Request appropriately sized cached images

**Files:**
- Create: `lib/features/products/data/services/product_image_url_service.dart`
- Create test: `test/product_image_url_service_test.dart`
- Modify: `lib/features/products/presentation/widgets/product_card.dart`, `lib/features/products/presentation/views/product_detail_view.dart`, `lib/features/products/presentation/views/product_edit_view.dart`
- Test: `test/product_photo_publication_test.dart`, `test/product_image_url_service_test.dart`.

**Interfaces:**
- `String forCard(String sourceUrl, {required int pixelWidth})` and `String forDetail(String sourceUrl, {required int pixelWidth})` return unchanged URLs unless the host/path is a verified Cloudinary image delivery URL.
- Use Cloudinary's documented width, quality-auto and format-auto transforms only after the existing URL format passes tests; no API secret is used for public delivery transformations.

- [ ] **Step 1: Add failing URL tests** — cover valid Cloudinary delivery URLs, existing transformations, query/fragment handling, and untouched external/malformed URLs.
- [ ] **Step 2: Verify RED** — run `flutter test --no-pub test/product_image_url_service_test.dart`; expected: transformation assertions fail.
- [ ] **Step 3: Implement URL sizing and cache decode bounds** — provide card/detail pixel widths from layout/device scale and keep existing placeholder/error behavior.
- [ ] **Step 4: Verify publication and display tests** — run `flutter test --no-pub test/product_photo_publication_test.dart test/product_image_url_service_test.dart`; expected: upload URL/preset remains unchanged and transformed display URLs are correct.
- [ ] **Step 5: Measure on device** — compare catalog bytes, decode memory and scroll frames against baseline, including a non-Cloudinary image URL.
