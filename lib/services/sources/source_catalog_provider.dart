import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/sources.dart';
import 'source_catalog_service.dart';

final sourceRegistryProvider = Provider<SourceRegistry>((ref) {
  return SourceRegistry([IzibSourceConnector(), AknigaSourceConnector()]);
});

final sourceCatalogServiceProvider = Provider<SourceCatalogService>((ref) {
  return SourceCatalogService(registry: ref.watch(sourceRegistryProvider));
});
