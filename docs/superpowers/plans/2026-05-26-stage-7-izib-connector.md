# Stage 7 Izib Connector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the first real source connector, Izib, using the Stage 6 `SourceConnector` framework.

**Architecture:** Izib code lives in `lib/sources/izib/` and stays independent from UI. The connector uses a small injected GraphQL transport so tests run without live network access. SIGN is generated per request inside the Izib client, never stored, returned, or logged.

**Tech Stack:** Dart, Flutter test, `dart:io` `HttpClient` for runtime transport, `package:crypto` for SHA-256, existing `SourceConnector` models.

---

### Task 1: Izib Signing And GraphQL Client

**Files:**
- Create: `test/sources/izib/izib_graphql_client_test.dart`
- Create: `lib/sources/izib/izib_signer.dart`
- Create: `lib/sources/izib/izib_graphql_client.dart`
- Modify: `pubspec.yaml`

- [x] **Step 1: Write failing tests**

Cover deterministic `graphqlBody`, package key generation, per-body SIGN generation, POST headers, GraphQL error mapping, and no exposure of SIGN in exception messages.

- [x] **Step 2: Run tests and confirm RED**

Run `flutter test test/sources/izib/izib_graphql_client_test.dart`.

- [x] **Step 3: Implement minimal signer/client**

Add `crypto` as a direct dependency, implement canonical body JSON, SIGN generation, injected transport, default `dart:io` transport, and safe `SourceException` mapping.

- [x] **Step 4: Verify GREEN**

Run `flutter test test/sources/izib/izib_graphql_client_test.dart`.

### Task 2: Izib Mapper

**Files:**
- Create: `test/sources/izib/izib_mapper_test.dart`
- Create: `lib/sources/izib/izib_mapper.dart`
- Create: `test/sources/izib/fixtures/izib_search_response.json`
- Create: `test/sources/izib/fixtures/izib_book_response.json`

- [x] **Step 1: Write failing mapper tests**

Cover search result mapping, details mapping, chapters, tracks, access flags, duration, cover URL resolution, rating, and raw media refs.

- [x] **Step 2: Run tests and confirm RED**

Run `flutter test test/sources/izib/izib_mapper_test.dart`.

- [x] **Step 3: Implement mapper**

Map GraphQL book/files data to `BookSearchResult`, `BookVersionDetails`, `Chapter`, and `AudioTrack` using existing domain models.

- [x] **Step 4: Verify GREEN**

Run `flutter test test/sources/izib/izib_mapper_test.dart`.

### Task 3: Izib SourceConnector

**Files:**
- Create: `test/sources/izib/izib_source_connector_test.dart`
- Create: `lib/sources/izib/izib_source_connector.dart`
- Modify: `lib/sources/sources.dart`

- [x] **Step 1: Write failing connector tests**

Cover connector capabilities, search, details, chapters, tracks, resolveMedia with allowlist validation, health success, and health API failure.

- [x] **Step 2: Run tests and confirm RED**

Run `flutter test test/sources/izib/izib_source_connector_test.dart`.

- [x] **Step 3: Implement connector**

Use `IzibGraphQlClient` and `IzibMapper`; do not perform network access from UI; keep media validation based on `SourceMediaPolicy`.

- [x] **Step 4: Verify GREEN**

Run `flutter test test/sources/izib/izib_source_connector_test.dart`.

### Task 4: Documentation, Verification, Commit

**Files:**
- Modify: `docs/SOURCES.md`
- Modify: `docs/SLOVOFON_TECHNICAL_SPEC_RU.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `CHANGELOG.md`

- [x] **Step 1: Update docs**

Record that Stage 7 implements Izib as the first real source and note no SIGN logging/storage.

- [x] **Step 2: Run full verification**

Run:

```powershell
flutter pub get
./tools/slovofon.ps1 format
./tools/slovofon.ps1 analyze
./tools/slovofon.ps1 test
```

- [x] **Step 3: Commit**

Commit roadmap corrections together with Stage 7 work:

```powershell
git commit -m "feat(sources): add Izib connector"
```
