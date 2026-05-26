# sources

`SourceConnector` interfaces and concrete source adapters belong here.

UI must not call audiobook sources directly. Screens should go through feature state, use cases, repositories, and services.

Stage 6 framework entry point: `sources.dart`.

Current framework pieces:

- `SourceConnector` contract;
- `SourceRegistry`;
- `SourceCapabilities` and `SourceHealth`;
- `SourceMediaPolicy` and `SourceMediaValidator`;
- shared `SourceParserHelpers`;
- local `MockSourceConnector` for tests without network access;
- real `IzibSourceConnector` with GraphQL, runtime SIGN generation, mapper, media allowlist validation, and fixture-based tests.
