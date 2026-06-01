import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/sources.dart';
import 'source_catalog_service.dart';
import 'source_settings_store.dart';

List<SourceConnector> defaultSourceConnectors() {
  return [
    IzibSourceConnector(),
    AknigaSourceConnector(),
    YaknigaSourceConnector(),
    KnigavuheSourceConnector(),
    KnigobludSourceConnector(),
    BazaKnigSourceConnector(),
  ];
}

final sourceRegistryProvider = Provider<SourceRegistry>((ref) {
  final enabledSourceIds = ref.watch(
    sourceSettingsStoreProvider.select((store) => store.enabledSearchSourceIds),
  );
  return SourceRegistry(
    defaultSourceConnectors(),
    enabledSourceIds: enabledSourceIds,
  );
});

final sourceCatalogServiceProvider = Provider<SourceCatalogService>((ref) {
  return SourceCatalogService(registry: ref.watch(sourceRegistryProvider));
});
