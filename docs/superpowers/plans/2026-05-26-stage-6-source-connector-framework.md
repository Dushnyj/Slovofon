# Stage 6 SourceConnector Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the source connector framework required by stage 6: connector contract, registry, capabilities, health model, shared parser helpers, media validators, and a local mock connector for integration tests.

**Architecture:** Source logic lives under `lib/sources/` and imports domain/audio models, never UI widgets. `SourceRegistry` is the single entry point for enabled connectors and aggregates partial search failures without hiding successful results. Media validation is connector-policy based and blocks arbitrary network URLs before playback/download layers can use them.

**Tech Stack:** Dart, Flutter test, existing domain models in `lib/domain/models/`, existing `AudioMediaSource` in `lib/services/audio/audio_state.dart`.

---

### Task 1: Source Contracts And Registry Tests

**Files:**
- Create: `test/sources/source_registry_test.dart`
- Create: `lib/sources/source_connector.dart`
- Create: `lib/sources/source_registry.dart`
- Create: `lib/sources/source_models.dart`
- Create: `lib/sources/sources.dart`

- [x] **Step 1: Write the failing registry tests**

Create tests that import `package:slovofon/sources/sources.dart` and assert:

```dart
test('rejects duplicate connector ids', () {
  final connector = _FakeSourceConnector(id: 'yakniga');

  expect(
    () => SourceRegistry([connector, connector]),
    throwsA(isA<ArgumentError>()),
  );
});

test('search aggregates enabled source results and failures', () async {
  final ok = _FakeSourceConnector(id: 'yakniga', results: [
    const BookSearchResult(
      ref: SourceBookRef(sourceId: 'yakniga', sourceBookId: 'book-1'),
      sourceName: 'Yakniga',
      title: 'Metro 2033',
    ),
  ]);
  final failing = _FakeSourceConnector(
    id: 'izib',
    failure: const SourceException(
      sourceId: 'izib',
      kind: SourceErrorKind.network,
      message: 'offline',
    ),
  );

  final response = await SourceRegistry([ok, failing]).search(
    const SearchRequest(query: 'metro'),
  );

  expect(response.results.single.sourceId, 'yakniga');
  expect(response.failures.single.sourceId, 'izib');
  expect(response.hasPartialFailures, isTrue);
});
```

- [x] **Step 2: Run the tests to verify RED**

Run:

```powershell
flutter test test/sources/source_registry_test.dart
```

Expected: FAIL because `package:slovofon/sources/sources.dart` does not exist.

- [x] **Step 3: Implement the minimal framework API**

Add immutable models for `SearchRequest`, `BookSearchResult`, `SourceBookRef`, `SourceCapabilities`, `SourceHealth`, `ResolvedMedia`, `SourceException`, `SourceSearchResponse`; add `SourceConnector` interface and `SourceRegistry` duplicate-id/search aggregation behavior.

- [x] **Step 4: Verify GREEN**

Run:

```powershell
flutter test test/sources/source_registry_test.dart
```

Expected: PASS.

### Task 2: Media Validation

**Files:**
- Create: `test/sources/source_media_validator_test.dart`
- Create: `lib/sources/source_media_validator.dart`
- Modify: `lib/sources/sources.dart`

- [x] **Step 1: Write the failing validator tests**

Tests must verify that URL media is allowed only when the URL host is in the connector policy, URLs with credentials are rejected, non-HTTP URL schemes are rejected, and mock/local media requires `allowLocalMedia: true`.

- [x] **Step 2: Run validator tests to verify RED**

Run:

```powershell
flutter test test/sources/source_media_validator_test.dart
```

Expected: FAIL because `SourceMediaValidator` is missing.

- [x] **Step 3: Implement validator**

Implement `SourceMediaPolicy` and `SourceMediaValidator.validateResolvedMedia(policy, resolvedMedia, purpose)`.

- [x] **Step 4: Verify GREEN**

Run:

```powershell
flutter test test/sources/source_media_validator_test.dart
```

Expected: PASS.

### Task 3: Parser Helpers

**Files:**
- Create: `test/sources/source_parser_helpers_test.dart`
- Create: `lib/sources/source_parser_helpers.dart`
- Modify: `lib/sources/sources.dart`

- [x] **Step 1: Write the failing helper tests**

Tests must cover whitespace normalization, Russian/English title normalization, integer/year parsing from noisy labels, duration parsing from labels like `1 ч 05 мин 09 сек`, and safe URI resolution against a base URL.

- [x] **Step 2: Run parser tests to verify RED**

Run:

```powershell
flutter test test/sources/source_parser_helpers_test.dart
```

Expected: FAIL because `SourceParserHelpers` is missing.

- [x] **Step 3: Implement helper methods**

Implement pure static methods with deterministic behavior and no network access.

- [x] **Step 4: Verify GREEN**

Run:

```powershell
flutter test test/sources/source_parser_helpers_test.dart
```

Expected: PASS.

### Task 4: Mock Connector

**Files:**
- Create: `test/sources/mock_source_connector_test.dart`
- Create: `lib/sources/mock/mock_source_connector.dart`
- Modify: `lib/sources/sources.dart`

- [x] **Step 1: Write the failing mock connector tests**

Tests must verify that mock search reads existing stage 3 books, details return a `BookVersionDetails`, chapters map to domain `Chapter`, audio tracks map to `AudioTrack`, and media resolution returns the stage 4 fixture asset.

- [x] **Step 2: Run mock connector tests to verify RED**

Run:

```powershell
flutter test test/sources/mock_source_connector_test.dart
```

Expected: FAIL because `MockSourceConnector` is missing.

- [x] **Step 3: Implement mock connector**

Map `stage3MockBooks` to the source framework without adding network behavior.

- [x] **Step 4: Verify GREEN**

Run:

```powershell
flutter test test/sources/mock_source_connector_test.dart
```

Expected: PASS.

### Task 5: Documentation And Full Verification

**Files:**
- Modify: `docs/SOURCES.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/SLOVOFON_TECHNICAL_SPEC_RU.md`
- Modify: `CHANGELOG.md`

- [x] **Step 1: Update docs**

Document where the framework lives, what registry/validator guarantee, and that real source connectors start after Stage 6.

- [x] **Step 2: Format and analyze**

Run:

```powershell
./tools/slovofon.ps1 format
./tools/slovofon.ps1 analyze
```

Expected: no analyzer issues.

- [x] **Step 3: Run all tests**

Run:

```powershell
./tools/slovofon.ps1 test
```

Expected: all tests pass.
