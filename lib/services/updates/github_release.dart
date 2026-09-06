import '../../app/project_links.dart';
import 'update_manifest.dart';

/// Public GitHub release metadata, not the former server-signed manifest.
class GitHubRelease {
  GitHubRelease._({
    required this.version,
    required this.publishedAt,
    required this.notes,
    required this.assets,
    required this.checksumAsset,
  });

  static const latestApiUrl = ProjectLinks.githubLatestRelease;
  static const repositoryUrl = ProjectLinks.githubRepository;
  static final _versionPattern = RegExp(
    r'^(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})$',
  );
  static final _digestPattern = RegExp(r'^sha256:([0-9a-fA-F]{64})$');

  final String version;
  final DateTime? publishedAt;
  final String? notes;
  final List<GitHubReleaseAsset> assets;
  final GitHubReleaseAsset? checksumAsset;

  String get tag => 'v$version';
  bool get needsChecksums => assets.any((asset) => asset.digest == null);

  factory GitHubRelease.fromJson(Map<String, Object?> json) {
    final tag = json['tag_name'];
    if (json['draft'] != false ||
        json['prerelease'] != false ||
        tag is! String ||
        !tag.startsWith('v') ||
        !_versionPattern.hasMatch(tag.substring(1))) {
      throw const FormatException(
        'Expected a stable vMAJOR.MINOR.PATCH release',
      );
    }
    final version = tag.substring(1);
    if (json['html_url'] != '$repositoryUrl/releases/tag/$tag') {
      throw const FormatException('Release repository or tag does not match');
    }
    final rawAssets = json['assets'];
    if (rawAssets is! List || rawAssets.length > 100) {
      throw const FormatException('Release assets are invalid');
    }
    final assets = <GitHubReleaseAsset>[];
    GitHubReleaseAsset? checksumAsset;
    final names = <String>{};
    for (final raw in rawAssets) {
      if (raw is! Map || raw['name'] is! String) {
        throw const FormatException('Release asset metadata is invalid');
      }
      final name = raw['name'] as String;
      if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(name) ||
          name.contains('..')) {
        throw const FormatException('Release asset filename is unsafe');
      }
      if (!names.add(name)) {
        throw const FormatException('Release contains duplicate asset names');
      }
      final kind = installerIdentity(name);
      if (name != 'SHA256SUMS.txt' && kind == null) continue;
      if (kind != null && kind.version != version) {
        throw const FormatException('Installer version differs from release');
      }
      final rawUrl = raw['browser_download_url'];
      final size = raw['size'];
      if (rawUrl is! String ||
          size is! int ||
          size <= 0 ||
          raw['state'] != 'uploaded') {
        throw const FormatException('Release asset URL or size is invalid');
      }
      // Check the wire representation before Uri removes dot segments or
      // canonicalizes percent escapes; metadata must use the exact asset URL.
      if (rawUrl != '$repositoryUrl/releases/download/v$version/$name') {
        throw const FormatException('Release asset URL is not canonical');
      }
      final uri = Uri.tryParse(rawUrl);
      if (uri == null) {
        throw const FormatException('Release asset URL is invalid');
      }
      validateAssetUrl(uri, name: name, version: version);
      String? digest;
      if (raw['digest'] != null) {
        final rawDigest = raw['digest'];
        final match = rawDigest is String
            ? _digestPattern.firstMatch(rawDigest)
            : null;
        if (match == null) {
          throw const FormatException('Release asset sha256 digest is invalid');
        }
        digest = match.group(1)!.toLowerCase();
      }
      final asset = GitHubReleaseAsset(name, uri, size, digest);
      if (name == 'SHA256SUMS.txt') {
        checksumAsset = asset;
      } else {
        assets.add(asset);
      }
    }
    final published = json['published_at'];
    final notes = json['body'];
    if ((published != null &&
            (published is! String || DateTime.tryParse(published) == null)) ||
        (notes != null && notes is! String)) {
      throw const FormatException('Release date or notes are invalid');
    }
    return GitHubRelease._(
      version: version,
      publishedAt: published == null
          ? null
          : DateTime.parse(published as String),
      notes: notes as String?,
      assets: List.unmodifiable(assets),
      checksumAsset: checksumAsset,
    );
  }

  UpdateManifest toManifest({Map<String, String> checksums = const {}}) {
    final converted = <UpdateAsset>[];
    for (final asset in assets) {
      final hash = asset.digest ?? checksums[asset.name];
      if (hash == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
        throw const FormatException('Installer has no known sha256 checksum');
      }
      final identity = installerIdentity(asset.name)!;
      converted.add(
        UpdateAsset(
          platform: identity.platform,
          arch: identity.arch,
          kind: identity.kind,
          url: asset.url,
          fileName: asset.name,
          sha256: hash,
          size: asset.size,
        ),
      );
    }
    return UpdateManifest(
      schema: 1,
      app: 'slovofon',
      channel: 'stable',
      status: 'available',
      version: version,
      build: null,
      publishedAt: publishedAt,
      mandatory: false,
      releaseUrl: '$repositoryUrl/releases/tag/$tag',
      releaseNotes: notes,
      assets: List.unmodifiable(converted),
    );
  }

  static GitHubInstallerIdentity? installerIdentity(String name) {
    final match = RegExp(
      r'^Slovofon-v([0-9.]+)-(android-universal-release\.apk|windows-x64-setup\.exe)$',
    ).firstMatch(name);
    if (match == null || !_versionPattern.hasMatch(match.group(1)!)) {
      return null;
    }
    final android = match.group(2) == 'android-universal-release.apk';
    return GitHubInstallerIdentity(
      match.group(1)!,
      android ? UpdateAssetPlatform.android : UpdateAssetPlatform.windows,
      android ? 'universal' : 'x64',
      android ? UpdateAssetKind.apk : UpdateAssetKind.installer,
    );
  }

  static void validateAssetUrl(
    Uri uri, {
    required String name,
    required String version,
  }) {
    final expected = '$repositoryUrl/releases/download/v$version/$name';
    if (!_versionPattern.hasMatch(version) ||
        (name != 'SHA256SUMS.txt' &&
            installerIdentity(name)?.version != version) ||
        uri.toString() != expected) {
      throw const FormatException('Asset URL is not bound to this release');
    }
  }

  static Map<String, String> parseChecksums(String text) {
    final result = <String, String>{};
    final lines = text
        .replaceFirst(RegExp('^\uFEFF'), '')
        .split(RegExp(r'\r?\n'));
    if (lines.length > 1000) throw const FormatException('Too many checksums');
    for (final line in lines) {
      if (line.isEmpty) continue;
      final match = RegExp(
        r'^([0-9a-fA-F]{64}) [ *]([A-Za-z0-9][A-Za-z0-9._-]*)$',
      ).firstMatch(line);
      if (match == null || match.group(2)!.contains('..')) {
        throw const FormatException('SHA256SUMS.txt contains an invalid entry');
      }
      if (result.containsKey(match.group(2))) {
        throw const FormatException(
          'SHA256SUMS.txt contains duplicate entries',
        );
      }
      result[match.group(2)!] = match.group(1)!.toLowerCase();
    }
    return result;
  }
}

class GitHubReleaseAsset {
  const GitHubReleaseAsset(this.name, this.url, this.size, this.digest);

  final String name;
  final Uri url;
  final int size;
  final String? digest;
}

class GitHubInstallerIdentity {
  const GitHubInstallerIdentity(
    this.version,
    this.platform,
    this.arch,
    this.kind,
  );

  final String version;
  final UpdateAssetPlatform platform;
  final String arch;
  final UpdateAssetKind kind;
}
