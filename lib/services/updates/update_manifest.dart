enum UpdateAssetPlatform { android, androidTv, windows, unknown }

enum UpdateAssetKind { apk, aab, installer, msi, portable, msix, unknown }

/// Normalized in-memory release metadata used by the UI and update service.
/// The production client reads GitHub Releases, not a server JSON manifest.
class UpdateManifest {
  const UpdateManifest({
    required this.schema,
    required this.app,
    required this.channel,
    required this.status,
    required this.version,
    required this.build,
    required this.publishedAt,
    required this.mandatory,
    required this.releaseUrl,
    required this.releaseNotes,
    required this.assets,
  });

  factory UpdateManifest.fromJson(Map<String, Object?> json) {
    return UpdateManifest(
      schema: _intValue(json['schema']) ?? 1,
      app: _stringValue(json['app']) ?? 'slovofon',
      channel: _stringValue(json['channel']) ?? 'stable',
      status: _stringValue(json['status']) ?? 'no_release',
      version: _stringValue(json['version']),
      build: _intValue(json['build']),
      publishedAt: _dateValue(json['published_at']),
      mandatory: _boolValue(json['mandatory']) ?? false,
      releaseUrl: _stringValue(json['release_url']),
      releaseNotes: _stringValue(json['release_notes']),
      assets: [
        for (final raw in (json['assets'] as List<Object?>? ?? const []))
          if (raw is Map) UpdateAsset.fromJson(Map<String, Object?>.from(raw)),
      ],
    );
  }

  final int schema;
  final String app;
  final String channel;
  final String status;
  final String? version;
  final int? build;
  final DateTime? publishedAt;
  final bool mandatory;
  final String? releaseUrl;
  final String? releaseNotes;
  final List<UpdateAsset> assets;

  // A release may exist without an installer for this runtime. The service
  // distinguishes that unsupported case from an up-to-date application.
  bool get isAvailable => status == 'available' && version != null;
}

class UpdateAsset {
  const UpdateAsset({
    required this.platform,
    required this.arch,
    required this.kind,
    required this.url,
    required this.fileName,
    required this.sha256,
    required this.size,
  });

  factory UpdateAsset.fromJson(Map<String, Object?> json) {
    return UpdateAsset(
      platform: _assetPlatform(_stringValue(json['platform'])),
      arch: _stringValue(json['arch']) ?? 'unknown',
      kind: _assetKind(_stringValue(json['kind'])),
      url: Uri.parse(_stringValue(json['url']) ?? ''),
      fileName: _stringValue(json['file_name']) ?? '',
      sha256: (_stringValue(json['sha256']) ?? '').toLowerCase(),
      size: _intValue(json['size']) ?? 0,
    );
  }

  final UpdateAssetPlatform platform;
  final String arch;
  final UpdateAssetKind kind;
  final Uri url;
  final String fileName;
  final String sha256;
  final int size;

  bool get hasValidChecksum => RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256);
}

UpdateAssetPlatform _assetPlatform(String? value) {
  return switch (value) {
    'android' => UpdateAssetPlatform.android,
    'android_tv' => UpdateAssetPlatform.androidTv,
    'windows' => UpdateAssetPlatform.windows,
    _ => UpdateAssetPlatform.unknown,
  };
}

UpdateAssetKind _assetKind(String? value) {
  return switch (value) {
    'apk' => UpdateAssetKind.apk,
    'aab' => UpdateAssetKind.aab,
    'installer' => UpdateAssetKind.installer,
    'msi' => UpdateAssetKind.msi,
    'portable' => UpdateAssetKind.portable,
    'msix' => UpdateAssetKind.msix,
    _ => UpdateAssetKind.unknown,
  };
}

String? _stringValue(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString();
  return text.isEmpty ? null : text;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

bool? _boolValue(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return switch (value.toLowerCase()) {
      'true' || '1' || 'yes' => true,
      'false' || '0' || 'no' => false,
      _ => null,
    };
  }
  return null;
}

DateTime? _dateValue(Object? value) {
  final text = _stringValue(value);
  if (text == null) {
    return null;
  }
  return DateTime.tryParse(text);
}
