import 'source_models.dart';

/// Central production trust policies. Persisted metadata may identify a source,
/// but it cannot supply or widen that source's host scopes.
abstract final class BuiltInSourcePolicies {
  static const _policies = <String, SourceMediaPolicy>{
    'izib': SourceMediaPolicy(
      metadataHosts: {'izib.uk', 'api.izib.uk'},
      mediaHosts: {'izib.uk', 'audioknigi.xyz'},
      coverHosts: {'izib.uk'},
    ),
    'akniga': SourceMediaPolicy(
      metadataHosts: {'akniga.org', 'www.akniga.org'},
      mediaHosts: {'akniga.org', 'akniga.club', 'audioknigi.xyz'},
      coverHosts: {'akniga.org', 'www.akniga.org'},
    ),
    'yakniga': SourceMediaPolicy(
      metadataHosts: {'yakniga.org', 'www.yakniga.org'},
      mediaHosts: {'yakniga.org', 'www.yakniga.org'},
      coverHosts: {'yakniga.org', 'www.yakniga.org'},
    ),
    'knigavuhe': SourceMediaPolicy(
      metadataHosts: {'knigavuhe.org', 'www.knigavuhe.org'},
      mediaHosts: {'knigavuhe.org', 'www.knigavuhe.org', 'litres.ru'},
      coverHosts: {'knigavuhe.org', 'www.knigavuhe.org'},
    ),
    'knigoblud': SourceMediaPolicy(
      metadataHosts: {'knigoblud.club', 'www.knigoblud.club'},
      mediaHosts: {'audioknigi.xyz', 'litres.ru'},
      coverHosts: {'knigoblud.club', 'www.knigoblud.club', 'audioknigi.xyz'},
    ),
    'baza_knig': SourceMediaPolicy(
      metadataHosts: {'baza-knig.top', 'www.baza-knig.top'},
      mediaHosts: {'abooka.casa', 'archive.org'},
      coverHosts: {'baza-knig.top', 'www.baza-knig.top'},
    ),
  };

  static SourceMediaPolicy? byId(String sourceId) => _policies[sourceId];
}
