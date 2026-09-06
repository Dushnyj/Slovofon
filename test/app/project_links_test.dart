import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/project_links.dart';

void main() {
  test('project links use only public HTTPS endpoints', () {
    final links = [
      ProjectLinks.githubRepository,
      ProjectLinks.githubReleases,
      ProjectLinks.githubLatestRelease,
      ProjectLinks.telegramSupportBot,
      ProjectLinks.telegramChannel,
      ProjectLinks.telegramChat,
      ProjectLinks.site,
      ProjectLinks.api,
    ];

    for (final link in links) {
      expect(link, startsWith('https://'));
      expect(
        Uri.parse(link).host,
        isNot(matches(RegExp(r'^\d+\.\d+\.\d+\.\d+$'))),
      );
    }
    expect(
      ProjectLinks.githubLatestRelease,
      'https://api.github.com/repos/Dushnyj/Slovofon/releases/latest',
    );
    expect(
      ProjectLinks.githubReleases,
      'https://github.com/Dushnyj/Slovofon/releases',
    );
  });
}
