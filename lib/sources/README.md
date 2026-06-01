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
- real `IzibSourceConnector` with GraphQL, runtime SIGN generation, mapper, media allowlist validation, and fixture-based tests;
- real `AknigaSourceConnector` with HTML/ajax resolver, runtime security hash, media headers, and fixture-based tests;
- real `YaknigaSourceConnector` with public GraphQL search/details/chapters, direct media validation, and optional live smoke tests;
- real `KnigavuheSourceConnector` with HTML search/details, `BookPlayer` playlist parsing, direct media validation, and optional live smoke tests;
- real `KnigobludSourceConnector` with HTML search/details, `KB.playerInit` playlist parsing, direct media validation, and optional live smoke tests;
- real `BazaKnigSourceConnector` with HTML search/details, `Playerjs` playlist parsing, `abooka.casa` media validation, and optional live smoke tests.
