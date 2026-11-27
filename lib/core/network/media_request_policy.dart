/// Trust boundary shared by playback, downloading and cover transports.
/// Hosts are defined by a connector, never learned from a redirect or cache.
class MediaRequestPolicy {
  MediaRequestPolicy.allowedHosts(
    Iterable<String> hosts, {
    this.httpsOnly = false,
  }) : _hosts = Set.unmodifiable(hosts.map(_host)),
       _fixedOrigin = null;

  MediaRequestPolicy.sameOrigin(this._fixedOrigin)
    : _hosts = const {},
      httpsOnly = false;

  final Set<String> _hosts;
  final Uri? _fixedOrigin;
  final bool httpsOnly;

  static String _host(String host) =>
      host.trim().toLowerCase().replaceFirst(RegExp(r'\.+$'), '');

  static bool _sameOrigin(Uri left, Uri right) =>
      left.scheme == right.scheme &&
      _host(left.host) == _host(right.host) &&
      left.port == right.port;

  bool allows(Uri uri) {
    if ((uri.scheme != 'https' && (httpsOnly || uri.scheme != 'http')) ||
        uri.host.isEmpty ||
        uri.authority.contains('@') ||
        uri.hasFragment ||
        uri.port <= 0 ||
        uri.port > 65535) {
      return false;
    }
    if (_fixedOrigin case final fixed?) return _sameOrigin(fixed, uri);
    if (uri.port != (uri.scheme == 'https' ? 443 : 80)) return false;
    final host = _host(uri.host);
    return _hosts.any(
      (allowed) =>
          allowed.isNotEmpty && (host == allowed || host.endsWith('.$allowed')),
    );
  }

  Uri? resolveRedirect(Uri current, String? location) {
    final value = location?.trim();
    if (!allows(current) || value == null || value.isEmpty) return null;
    try {
      final next = current.resolve(value);
      if (current.scheme == 'https' && next.scheme != 'https') return null;
      return allows(next) ? next : null;
    } on FormatException {
      return null;
    }
  }

  Map<String, String> headersForHop(
    Uri initial,
    Uri destination,
    Map<String, String> headers,
  ) {
    if (!allows(destination)) return const {};
    return {
      for (final entry in headers.entries)
        if (!_managedHeaders.contains(entry.key.toLowerCase()) &&
            (_sameOrigin(initial, destination) ||
                _crossOriginHeaders.contains(entry.key.toLowerCase())))
          entry.key: entry.value,
    };
  }

  static const _managedHeaders = {
    'host',
    'connection',
    'proxy-authorization',
    'range',
    'accept-encoding',
    'content-length',
    'transfer-encoding',
    'upgrade',
  };
  static const _crossOriginHeaders = {
    'accept',
    'accept-language',
    'user-agent',
  };
}
