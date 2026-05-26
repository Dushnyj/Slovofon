import 'source_connector.dart';
import 'source_models.dart';

class SourceRegistry {
  SourceRegistry(
    List<SourceConnector> connectors, {
    Set<String>? enabledSourceIds,
  }) {
    final byId = <String, SourceConnector>{};
    for (final connector in connectors) {
      if (connector.id.trim().isEmpty) {
        throw ArgumentError.value(connector.id, 'id', 'Source id is empty.');
      }
      if (byId.containsKey(connector.id)) {
        throw ArgumentError.value(
          connector.id,
          'id',
          'Duplicate source connector id.',
        );
      }
      byId[connector.id] = connector;
    }

    _byId = Map.unmodifiable(byId);
    _connectors = List.unmodifiable(byId.values);
    _enabledSourceIds = Set.unmodifiable(enabledSourceIds ?? byId.keys);
  }

  late final List<SourceConnector> _connectors;
  late final Map<String, SourceConnector> _byId;
  late final Set<String> _enabledSourceIds;

  List<SourceConnector> get connectors => _connectors;

  List<SourceConnector> get enabledConnectors {
    return List.unmodifiable(
      _connectors.where(
        (connector) => _enabledSourceIds.contains(connector.id),
      ),
    );
  }

  Set<String> get enabledSourceIds => _enabledSourceIds;

  SourceConnector connectorById(String sourceId) {
    final connector = _byId[sourceId];
    if (connector == null) {
      throw SourceException(
        sourceId: sourceId,
        kind: SourceErrorKind.notFound,
        message: 'Source connector is not registered.',
      );
    }

    return connector;
  }

  Future<SourceSearchResponse> search(SearchRequest request) async {
    final results = <BookSearchResult>[];
    final failures = <SourceFailure>[];

    for (final connector in enabledConnectors) {
      if (!request.allowsSource(connector.id)) {
        continue;
      }
      if (!connector.capabilities.supportsSearch) {
        failures.add(
          SourceFailure(
            sourceId: connector.id,
            kind: SourceErrorKind.unsupported,
            message: 'Source does not support search.',
          ),
        );
        continue;
      }

      try {
        results.addAll(await connector.search(request));
      } on Object catch (error) {
        failures.add(SourceFailure.fromError(connector.id, error));
      }
    }

    return SourceSearchResponse(
      results: List.unmodifiable(results),
      failures: List.unmodifiable(failures),
    );
  }

  Future<List<SourceHealth>> checkHealth({Set<String>? sourceIds}) async {
    final health = <SourceHealth>[];

    for (final connector in enabledConnectors) {
      if (sourceIds != null && !sourceIds.contains(connector.id)) {
        continue;
      }

      try {
        health.add(await connector.checkHealth());
      } on Object catch (error) {
        final failure = SourceFailure.fromError(connector.id, error);
        health.add(
          SourceHealth(
            sourceId: failure.sourceId,
            status: SourceHealthStatus.unavailable,
            checkedAt: DateTime.now(),
            message: failure.message,
          ),
        );
      }
    }

    return List.unmodifiable(health);
  }

  Map<String, SourceCapabilities> capabilitiesBySourceId() {
    return Map.unmodifiable({
      for (final connector in _connectors) connector.id: connector.capabilities,
    });
  }
}
