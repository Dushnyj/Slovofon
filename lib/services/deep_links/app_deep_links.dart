import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'slovofon_deep_link.dart';

abstract interface class AppDeepLinkSource {
  Future<Uri?> getInitialLink();

  Stream<Uri> get links;
}

class NoopAppDeepLinkSource implements AppDeepLinkSource {
  const NoopAppDeepLinkSource();

  @override
  Future<Uri?> getInitialLink() async {
    return null;
  }

  @override
  Stream<Uri> get links => const Stream.empty();
}

class PluginAppDeepLinkSource implements AppDeepLinkSource {
  factory PluginAppDeepLinkSource({AppLinks? appLinks}) {
    final legacy = _PluginDeepLinkSource(appLinks ?? AppLinks());
    return PluginAppDeepLinkSource._(
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
          ? WindowsActivationDeepLinkSource(fallback: legacy)
          : legacy,
    );
  }

  PluginAppDeepLinkSource._(this._source);

  final AppDeepLinkSource _source;

  @override
  Future<Uri?> getInitialLink() => _source.getInitialLink();

  @override
  Stream<Uri> get links => _source.links;
}

class _PluginDeepLinkSource implements AppDeepLinkSource {
  _PluginDeepLinkSource(this._appLinks);

  final AppLinks _appLinks;

  @override
  Future<Uri?> getInitialLink() {
    return _appLinks.getInitialLink();
  }

  @override
  Stream<Uri> get links => _appLinks.uriLinkStream;
}

/// Windows keeps repeated-launch arguments in the native owner until this
/// listener is ready. Only validated book links become navigation events;
/// arbitrary command-line arguments are never executed or logged.
class WindowsActivationDeepLinkSource implements AppDeepLinkSource {
  WindowsActivationDeepLinkSource({
    AppDeepLinkSource fallback = const NoopAppDeepLinkSource(),
    MethodChannel channel = const MethodChannel(
      'com.slovofon.app/windows_activation',
    ),
  }) : _fallback = fallback,
       _channel = channel {
    _controller = StreamController<Uri>(onListen: _listen, onCancel: _cancel);
  }

  final AppDeepLinkSource _fallback;
  final MethodChannel _channel;
  late final StreamController<Uri> _controller;
  StreamSubscription<Uri>? _fallbackSubscription;
  bool _active = false;
  bool _draining = false;
  bool _drainAgain = false;

  @override
  Future<Uri?> getInitialLink() async {
    try {
      final arguments = await _channel.invokeMethod<Object?>(
        'getInitialArguments',
      );
      return _bookLink(arguments);
    } on MissingPluginException {
      // Allows older runners, development harnesses and plugin tests to keep
      // the original initial-link behavior while upgrading the native runner.
      return _fallback.getInitialLink();
    }
  }

  @override
  Stream<Uri> get links => _controller.stream;

  static Uri? _bookLink(Object? arguments) {
    // Preserve the existing app_links CLI contract: one URI argument.
    if (arguments is! List || arguments.length != 1) return null;
    final value = arguments.single;
    if (value is! String || value.length > 65536 || value.contains('\u0000')) {
      return null;
    }
    try {
      final uri = Uri.tryParse(value);
      if (uri == null || sourceBookLocationFromDeepLink(uri) == null) {
        return null;
      }
      return uri;
    } on FormatException {
      return null;
    }
  }

  void _listen() {
    _active = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'activationAvailable') throw MissingPluginException();
      if (_active) unawaited(_drain());
    });
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_draining) {
      _drainAgain = true;
      return;
    }
    _draining = true;
    try {
      do {
        _drainAgain = false;
        final batches = await _channel.invokeMethod<Object?>(
          'takePendingActivations',
        );
        if (!_active) return;
        if (batches is List) {
          for (final arguments in batches.take(32)) {
            final link = _bookLink(arguments);
            if (link != null) _controller.add(link);
          }
        }
      } while (_active && _drainAgain);
    } on MissingPluginException {
      if (_active) {
        _fallbackSubscription ??= _fallback.links.listen(
          _controller.add,
          onError: _controller.addError,
        );
      }
    } catch (_) {
      // Do not expose raw URI/arguments in diagnostic logs. A future shortcut
      // notification retries the pending native queue after a bridge failure.
    } finally {
      _draining = false;
    }
  }

  Future<void> _cancel() async {
    _active = false;
    _channel.setMethodCallHandler(null);
    // Send stop before the first await: a replacement source can subscribe in
    // this same turn, and must not be disabled by this old listener afterward.
    final stopped = _stopNativeListening();
    await _fallbackSubscription?.cancel();
    await stopped;
  }

  Future<void> _stopNativeListening() async {
    try {
      await _channel.invokeMethod<void>('stopListening');
    } on MissingPluginException {
      // Older runner has no activation bridge.
    } on PlatformException {
      // The native HWND may already be shutting down.
    }
  }
}
