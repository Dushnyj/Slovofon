import 'dart:io';

import 'source_models.dart';
import 'source_response_reader.dart';
import 'source_search_cancellation.dart';

/// Enforced both by clients (including injected transports) and before every
/// native HTTP request, including redirects. Book IDs must not select a host.
class SourceMetadataPolicy {
  const SourceMetadataPolicy({required this.sourceId, required this.hosts});

  final String sourceId;
  final Set<String> hosts;

  Uri validate(Uri uri) {
    if ((uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.userInfo.isNotEmpty ||
        !SourceMediaPolicy(metadataHosts: hosts).allowsMetadataHost(uri.host)) {
      throw SourceException(
        sourceId: sourceId,
        kind: SourceErrorKind.parser,
        message: 'Metadata URL is not allowed for this source.',
      );
    }
    return uri;
  }

  Uri bookUri(Uri baseUri, SourceBookRef ref) {
    final id = Uri.tryParse(ref.sourceBookId);
    if (id == null || (!id.hasScheme && id.hasAuthority)) {
      throw SourceException(
        sourceId: sourceId,
        kind: SourceErrorKind.parser,
        message: 'Source book reference is invalid.',
      );
    }
    // Validate both representations: an optional sourceUri must not hide an
    // unsafe ID that would be used later when restoring the same book.
    validate(baseUri.resolveUri(id));
    return validate(ref.sourceUri ?? baseUri.resolveUri(id));
  }
}

class SourceMetadataResponse {
  const SourceMetadataResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

class SourceMetadataTransport {
  SourceMetadataTransport({
    required this.policy,
    required this.timeout,
    this.maxResponseBytes = 8 * 1024 * 1024,
    HttpClient Function()? httpClientFactory,
    DateTime Function()? clock,
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new,
       _clock = clock ?? DateTime.now;

  final SourceMetadataPolicy policy;
  final Duration timeout;
  final int maxResponseBytes;
  final HttpClient Function() _httpClientFactory;
  final DateTime Function() _clock;
  final _cookies = <(String, String, String), _MetadataCookie>{};

  Future<SourceMetadataResponse> send(
    Uri uri, {
    String method = 'GET',
    required Map<String, String> headers,
    List<int> bodyBytes = const [],
  }) async {
    final cancellation = SourceSearchCancellation.current;
    cancellation?.throwIfCancelled();
    var currentUri = policy.validate(uri);
    var currentMethod = method;
    var currentBody = bodyBytes;
    final client = _httpClientFactory()..connectionTimeout = timeout;
    final unlink = cancellation?.addListener(() => client.close(force: true));
    try {
      for (var redirects = 0; ; redirects++) {
        cancellation?.throwIfCancelled();
        policy.validate(currentUri);
        final request = await client
            .openUrl(currentMethod, currentUri)
            .timeout(timeout);
        request.followRedirects = false;
        for (final entry in headers.entries) {
          if (currentMethod == 'GET' &&
              method != 'GET' &&
              (entry.key.toLowerCase() == 'content-type' ||
                  entry.key.toLowerCase() == 'content-length')) {
            continue;
          }
          request.headers.set(entry.key, entry.value);
        }
        request.cookies.addAll(_cookiesFor(currentUri));
        if (currentBody.isNotEmpty) {
          request.contentLength = currentBody.length;
          request.add(currentBody);
        }
        final response = await request.close().timeout(timeout);
        _storeCookies(currentUri, response.cookies);
        final location = response.headers.value(HttpHeaders.locationHeader);
        final canRedirect =
            const {301, 302, 303, 307, 308}.contains(response.statusCode) &&
            (currentMethod == 'GET' || response.statusCode == 303);
        if (canRedirect && location != null) {
          if (redirects >= 5) {
            throw SourceException(
              sourceId: policy.sourceId,
              kind: SourceErrorKind.network,
              message: 'Metadata request exceeded the redirect limit.',
            );
          }
          // Check before issuing the next request, not after following it.
          currentUri = policy.validate(currentUri.resolve(location));
          await response.drain<void>().timeout(timeout);
          if (response.statusCode == 303) {
            currentMethod = 'GET';
            currentBody = const [];
          }
          continue;
        }
        final body = await readSourceResponseBody(
          response,
          sourceId: policy.sourceId,
          maxBytes: maxResponseBytes,
        ).timeout(timeout);
        return SourceMetadataResponse(response.statusCode, body);
      }
    } finally {
      unlink?.call();
      client.close(force: true);
    }
  }

  List<Cookie> _cookiesFor(Uri uri) {
    final now = _clock().toUtc();
    _cookies.removeWhere((_, cookie) => cookie.isExpired(now));
    final host = _normalizeHost(uri.host);
    final path = uri.path.isEmpty ? '/' : uri.path;
    final matching = _cookies.values.where((cookie) {
      return (cookie.hostOnly
              ? host == cookie.domain
              : _domainMatches(host, cookie.domain)) &&
          (!cookie.secure || uri.scheme == 'https') &&
          _matchesCookiePath(path, cookie.path);
    }).toList()..sort((a, b) => b.path.length.compareTo(a.path.length));
    return [for (final cookie in matching) Cookie(cookie.name, cookie.value)];
  }

  static bool _matchesCookiePath(String path, String scope) {
    return path == scope ||
        (path.startsWith(scope) &&
            (scope.endsWith('/') ||
                path.substring(scope.length).startsWith('/')));
  }

  void _storeCookies(Uri uri, List<Cookie> cookies) {
    final now = _clock().toUtc();
    final issuingHost = _normalizeHost(uri.host);
    for (final cookie in cookies) {
      final hostOnly = cookie.domain == null || cookie.domain!.isEmpty;
      final domain = hostOnly
          ? issuingHost
          : cookie.domain!.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
      // An alias may set a parent-domain session, but cannot plant cookies for
      // a sibling, an unrelated host, or a parent outside the source policy.
      if (!_domainMatches(issuingHost, domain) ||
          !SourceMediaPolicy(
            metadataHosts: policy.hosts,
          ).allowsMetadataHost(domain) ||
          domain.endsWith('.')) {
        continue;
      }
      final path = cookie.path?.startsWith('/') == true
          ? cookie.path!
          : _defaultCookiePath(uri.path);
      final key = (domain, path, cookie.name);
      // Max-Age takes precedence over Expires, including deletion.
      final maxAge = cookie.maxAge;
      final expiresAt = maxAge == null
          ? cookie.expires
          : now.add(Duration(seconds: maxAge));
      if (expiresAt != null && !expiresAt.isAfter(now)) {
        _cookies.remove(key);
        continue;
      }
      _cookies[key] = _MetadataCookie(
        name: cookie.name,
        value: cookie.value,
        domain: domain,
        hostOnly: hostOnly,
        path: path,
        secure: cookie.secure,
        expiresAt: expiresAt,
      );
    }
  }

  static String _normalizeHost(String host) =>
      host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');

  static bool _domainMatches(String host, String domain) =>
      host == domain ||
      (InternetAddress.tryParse(host) == null && host.endsWith('.$domain'));

  static String _defaultCookiePath(String path) {
    final lastSlash = path.lastIndexOf('/');
    return !path.startsWith('/') || lastSlash <= 0
        ? '/'
        : path.substring(0, lastSlash);
  }
}

class _MetadataCookie {
  const _MetadataCookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.hostOnly,
    required this.path,
    required this.secure,
    required this.expiresAt,
  });

  final String name;
  final String value;
  final String domain;
  final bool hostOnly;
  final String path;
  final bool secure;
  final DateTime? expiresAt;

  bool isExpired(DateTime now) => expiresAt != null && !expiresAt!.isAfter(now);
}
