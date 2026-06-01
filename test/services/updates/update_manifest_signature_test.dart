import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/updates/update_manifest_signature.dart';

void main() {
  group('UpdateManifestSignature', () {
    const publicKey = 'Od6UovnFoXAlLZ5UskQ7P9Gs8SI4ERu/E/XvaP7ic78=';
    const signature =
        'oHNYqXkRtqw+vVxxWQL1pj0z5jSxPQa4Uo0L9L1AGXq/RjEiGGipUf2XzvvgHNeBccXUtHxyBqct5VrQ19y+Aw==';

    Map<String, Object?> signedManifest() {
      return {
        'schema': 2,
        'app': 'slovofon',
        'channel': 'stable',
        'status': 'no_release',
        'version': null,
        'build': null,
        'published_at': null,
        'mandatory': false,
        'release_url': null,
        'release_notes': null,
        'assets': <Object?>[],
        'signature': {
          'alg': 'ed25519',
          'key_id': 'test-key',
          'value': signature,
        },
      };
    }

    test('accepts a valid Ed25519 manifest signature', () async {
      expect(
        await verifyUpdateManifestSignature(
          signedManifest(),
          publicKeys: const {'test-key': publicKey},
        ),
        isTrue,
      );
    });

    test('rejects a tampered manifest', () async {
      final manifest = signedManifest();
      manifest['status'] = 'available';

      expect(
        await verifyUpdateManifestSignature(
          manifest,
          publicKeys: const {'test-key': publicKey},
        ),
        isFalse,
      );
    });
  });
}
