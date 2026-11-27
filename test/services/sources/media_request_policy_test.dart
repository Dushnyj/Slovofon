import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/core/network/media_request_policy.dart';
import 'package:slovofon/services/sources/source_cover_repository.dart';

void main() {
  final policy = MediaRequestPolicy.allowedHosts({'media.example.test'});
  final initial = Uri.https('media.example.test', '/track');

  test(
    'configured CDN targets are accepted independently of redirect syntax',
    () {
      expect(policy.resolveRedirect(initial, '/track-v2')?.path, '/track-v2');
      expect(
        policy.resolveRedirect(initial, 'https://cdn.media.example.test/asset'),
        Uri.https('cdn.media.example.test', '/asset'),
      );
      expect(
        policy.resolveRedirect(
          initial,
          'https://unconfigured.example.test/asset',
        ),
        isNull,
      );
      expect(
        policy.resolveRedirect(initial, 'http://media.example.test/asset'),
        isNull,
      );
    },
  );

  test('origin-local headers are not forwarded to a different allowed CDN', () {
    final headers = {
      'Accept': 'audio/*',
      'Cookie': 'fixture=test',
      'Authorization': 'fixture',
      'Host': 'irrelevant.example.test',
    };
    expect(policy.headersForHop(initial, initial, headers), {
      'Accept': 'audio/*',
      'Cookie': 'fixture=test',
      'Authorization': 'fixture',
    });
    expect(
      policy.headersForHop(
        initial,
        Uri.https('cdn.media.example.test', '/asset'),
        headers,
      ),
      {'Accept': 'audio/*'},
    );
  });

  test(
    'cover handoff uses the selected source scope, never a generic fallback',
    () {
      final cover = Uri.https('s5.knigavuhe.org', '/cover.jpg');
      expect(SourceCoverRepository.policyFor('knigavuhe', cover), isNotNull);
      expect(SourceCoverRepository.policyFor('yakniga', cover), isNull);
      expect(SourceCoverRepository.policyFor(null, cover), isNull);
      expect(
        SourceCoverRepository.policyFor(
          'knigavuhe',
          cover.replace(scheme: 'http'),
        ),
        isNull,
      );
    },
  );
}
