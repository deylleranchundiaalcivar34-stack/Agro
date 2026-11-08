# Agro+ Map Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce map data processing and rendering cost while preserving voluntary approximate locations, permissions, OpenStreetMap attribution, and natural pan/zoom.

**Architecture:** Keep the map-specific view and repositories; load public locations first, fetch published products only for producer IDs with public zones, and group products once by producer. Add viewport-based querying or marker clustering only if profiling and schema support justify them.

**Tech Stack:** Flutter, `flutter_map`, Geolocator, `latlong2`, Supabase PostgREST, Flutter tests, OpenStreetMap tiles.

**Spec:** `docs/superpowers/specs/2026-11-08-agro-performance-design.md`

## Global Constraints

- Only producers who voluntarily publish an approximate zone appear.
- Do not request device location until the user chooses the location action.
- Horizontal/vertical map gestures remain owned by the map and do not switch app modules.
- Preserve OSM attribution; do not add offline or unlimited caching for the public tile server.
- RLS and public visibility policy remain unchanged; any SQL/index change needs a separate reviewed migration.

## Review Focus

- No public locations or empty producer ID set: do not issue a broad products query.
- Many locations/products: grouping and distance filtering remain bounded and correct.
- Permission denied/service off: useful message remains and public producer browsing still works.
- Pan/zoom/drag marker: no repeated Supabase loads or module navigation.
- OSM unavailable/slow: map controls and producer list/selection remain usable.

---

### Task 1: Establish map-specific profile and data contract

**Files:**
- Modify: `lib/features/map/presentation/views/map_view.dart` only if required for debug instrumentation
- Test: `test/map_view_test.dart`

**Interfaces:**
- Inputs remain `PublicLocationRepository.listPublished()` and a new targeted product query from `ProductsRepository`.
- Output is the same visible `ProducerMapEntry` list and current privacy contract.

**Readiness gate:** The live database currently has 1 public location and 8 products. Do not add targeted queries, viewport filters, clustering, or SQL until map profiling or growth shows the present work is material. Record the map frame/request evidence first.

- [ ] **Step 1: Measure map baseline** — record query count/rows, load time, marker build duration, frame over-budget count and memory for cold map open and pan/zoom.
- [ ] **Step 2: Add failing transformation tests** — cover zero locations, many products per producer, products with no zone, unavailable/zero-quantity product, and unchanged radius result.
- [ ] **Step 3: Verify RED** — run `flutter test --no-pub test/map_view_test.dart`; expected: new single-pass grouping assertion fails or profiling confirms the tested hot path.

### Task 2: Fetch only map-relevant products and group in one pass

**Files:**
- Modify: `lib/features/products/data/repositories/products_repository.dart`, `lib/features/map/presentation/views/map_view.dart`
- Test: `test/map_view_test.dart`, `test/product_catalogue_test.dart`

**Interfaces:**
- Add `Future<List<AgriculturalProduct>> getPublishedProductsForProducers(Set<String> producerIds)`; an empty set returns an empty list without network access.
- Keep the query's explicit product/photo fields, publication and quantity checks, and apply chunking if the verified PostgREST parameter/row limits require it.
- Replace `ProducerMapEntry.fromData` repeated filtering with a producer-ID grouping pass; preserve its result contract.

- [ ] **Step 1: Add repository HTTP tests** — assert producer IDs are filtered in the request, empty input makes zero requests, visibility filter remains true, and optional-unit fallback preserves producer IDs.
- [ ] **Step 2: Verify RED** — run `flutter test --no-pub test/map_view_test.dart test/product_catalogue_test.dart`; expected: the new targeted-query assertions fail.
- [ ] **Step 3: Implement targeted query and grouping** — load locations, derive producer IDs, query matching products, group once by `producerId`, and retain existing visible/radius filters.
- [ ] **Step 4: Verify GREEN** — rerun both focused test files and `flutter analyze --no-pub`; expected: pass.
- [ ] **Step 5: Profile map again** — record before/after rows, first markers, memory and frames. Add viewport/radius server filtering only if this remaining measurement justifies it and schema supports safe privacy-preserving filtering.

### Task 3: Verify tile policy and gesture behavior

**Files:**
- Modify only if justified: `lib/features/map/presentation/views/map_view.dart`
- Test: `test/map_view_test.dart`, `test/main_navigation_view_test.dart`

**Interfaces:** Keep the current public OSM URL and attribution unless provider policy is reviewed and a supported alternative is approved.

- [ ] **Step 1: Check tile requests and attribution** — inspect user-agent, attribution, request volume, and policy compliance; do not implement persistent caching without provider permission.
- [ ] **Step 2: Verify no map-interaction regression** — run `flutter test --no-pub test/map_view_test.dart test/main_navigation_view_test.dart`; expected: pan/zoom and the map's non-paging rule pass.
- [ ] **Step 3: Repeat real-device test** — open map, deny location, pan/zoom, select a producer, leave and return; expected: no redundant full catalog fetch and no loss of public-zone behavior.
