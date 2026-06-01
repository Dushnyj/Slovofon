import '../../sources/sources.dart';

const slovofonDeepLinkScheme = 'slovofon';
const slovofonBookDeepLinkHost = 'book';

Uri slovofonBookDeepLink({
  required String sourceId,
  required String sourceBookId,
}) {
  return Uri(
    scheme: slovofonDeepLinkScheme,
    host: slovofonBookDeepLinkHost,
    queryParameters: {'source': sourceId, 'book': sourceBookId},
  );
}

String sourceBookLocation(SourceBookRef ref) {
  return '/source-book/${Uri.encodeComponent(ref.sourceId)}/'
      '${Uri.encodeComponent(ref.sourceBookId)}';
}

String? sourceBookLocationFromDeepLink(Uri uri) {
  final isSlovofonBookLink =
      uri.scheme == slovofonDeepLinkScheme &&
      uri.host == slovofonBookDeepLinkHost;
  final isRouterBookLink = uri.path == '/book';
  if (!isSlovofonBookLink && !isRouterBookLink) {
    return null;
  }

  final sourceId = uri.queryParameters['source']?.trim();
  final sourceBookId = uri.queryParameters['book']?.trim();
  if (sourceId == null ||
      sourceId.isEmpty ||
      sourceBookId == null ||
      sourceBookId.isEmpty) {
    return null;
  }

  return sourceBookLocation(
    SourceBookRef(sourceId: sourceId, sourceBookId: sourceBookId),
  );
}
