import 'package:app_links/app_links.dart';

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
  PluginAppDeepLinkSource({AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> getInitialLink() {
    return _appLinks.getInitialLink();
  }

  @override
  Stream<Uri> get links => _appLinks.uriLinkStream;
}
