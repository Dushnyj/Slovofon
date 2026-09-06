import 'package:path/path.dart' as path;

enum WindowsInstallKind { setup, msi, portable, unknown }

enum WindowsInstallScope { user, machine }

/// Read-only context for this running executable, not another installed copy.
class WindowsUpdateInstallation {
  const WindowsUpdateInstallation({
    required this.kind,
    this.scope,
    this.directory,
    this.systemDirectory,
    this.windowsDirectory,
  });

  const WindowsUpdateInstallation.unknown()
    : kind = WindowsInstallKind.unknown,
      scope = null,
      directory = null,
      systemDirectory = null,
      windowsDirectory = null;

  factory WindowsUpdateInstallation.fromPlatformValue(Object? value) {
    if (value is! Map) return const WindowsUpdateInstallation.unknown();
    final kind = switch (value['kind']) {
      'setup' => WindowsInstallKind.setup,
      'msi' => WindowsInstallKind.msi,
      'portable' => WindowsInstallKind.portable,
      _ => WindowsInstallKind.unknown,
    };
    final scope = switch (value['scope']) {
      'user' => WindowsInstallScope.user,
      'machine' => WindowsInstallScope.machine,
      _ => null,
    };
    final directory = _absoluteDirectory(value['directory']);
    if (kind == WindowsInstallKind.unknown ||
        directory == null ||
        (kind == WindowsInstallKind.setup && scope == null)) {
      return const WindowsUpdateInstallation.unknown();
    }
    return WindowsUpdateInstallation(
      kind: kind,
      scope: kind == WindowsInstallKind.setup ? scope : null,
      directory: directory,
      systemDirectory: _absoluteDirectory(value['systemDirectory']),
      windowsDirectory: _absoluteDirectory(value['windowsDirectory']),
    );
  }

  final WindowsInstallKind kind;
  final WindowsInstallScope? scope;
  final String? directory;
  final String? systemDirectory;
  final String? windowsDirectory;

  static String? _absoluteDirectory(Object? value) {
    if (value is! String ||
        !path.windows.isAbsolute(value) ||
        value.contains(RegExp(r'[\x00-\x1f"]'))) {
      return null;
    }
    return path.windows.normalize(value);
  }
}
