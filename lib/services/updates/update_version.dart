bool isRemoteVersionNewer({
  required String currentVersion,
  required String currentBuild,
  required String? remoteVersion,
  required int? remoteBuild,
}) {
  if (remoteVersion == null || remoteVersion.trim().isEmpty) {
    return false;
  }

  final versionCompare = _compareSemver(remoteVersion, currentVersion);
  if (versionCompare > 0) {
    return true;
  }
  if (versionCompare < 0) {
    return false;
  }

  if (remoteBuild == null) {
    return false;
  }
  return remoteBuild > (int.tryParse(currentBuild) ?? 0);
}

int _compareSemver(String left, String right) {
  final leftParts = _semverParts(left);
  final rightParts = _semverParts(right);
  for (var index = 0; index < 3; index += 1) {
    final diff = leftParts[index].compareTo(rightParts[index]);
    if (diff != 0) {
      return diff;
    }
  }
  return 0;
}

List<int> _semverParts(String value) {
  final publicVersion = value.split('+').first.split('-').first;
  final parts = publicVersion.split('.');
  return [
    for (var index = 0; index < 3; index += 1)
      if (index < parts.length) int.tryParse(parts[index]) ?? 0 else 0,
  ];
}
