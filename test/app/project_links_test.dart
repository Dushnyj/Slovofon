import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/project_links.dart';

void main() {
  test('project links use only public HTTPS endpoints', () {
    final links = [
      ProjectLinks.githubRepository,
      ProjectLinks.telegramSupportBot,
      ProjectLinks.telegramChannel,
      ProjectLinks.telegramChat,
      ProjectLinks.site,
      ProjectLinks.api,
      ProjectLinks.updatesBase,
      ProjectLinks.updatesStableManifest,
      ProjectLinks.updatesBetaManifest,
    ];

    for (final link in links) {
      expect(link, startsWith('https://'));
      expect(
        Uri.parse(link).host,
        isNot(matches(RegExp(r'^\d+\.\d+\.\d+\.\d+$'))),
      );
    }
    expect(
      ProjectLinks.updatesStableManifest,
      'https://slovofon-updates.duckdns.org/v1/channels/stable/latest.json',
    );
    expect(
      ProjectLinks.updatesBetaManifest,
      'https://slovofon-updates.duckdns.org/v1/channels/beta/latest.json',
    );
  });
}
