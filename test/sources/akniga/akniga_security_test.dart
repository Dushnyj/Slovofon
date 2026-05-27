import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/akniga/akniga_security.dart';

void main() {
  group('AknigaSecurityEncoder', () {
    test('builds CryptoJS-compatible OpenSSL JSON with deterministic salt', () {
      final encoder = AknigaSecurityEncoder(
        saltFactory: () => const [0, 1, 2, 3, 4, 5, 6, 7],
      );

      final payload = encoder.encryptToOpenSslJson(
        '"test-key"',
        passphrase: AknigaSecurityEncoder.passphrase,
      );

      expect(payload['s'], '0001020304050607');
      expect(payload['iv'], hasLength(32));
      expect(payload['ct'], isNotEmpty);
      expect(base64Decode(payload['ct']!), isNotEmpty);
    });

    test('builds ajax/bid form body without exposing the passphrase', () {
      final encoder = AknigaSecurityEncoder(
        saltFactory: () => const [0, 1, 2, 3, 4, 5, 6, 7],
      );

      final body = encoder.securityBody(
        bookId: '12345',
        securityKey: 'live-key',
      );
      final form = Uri.splitQueryString(body);
      final hash = jsonDecode(form['hash']!) as Map<String, Object?>;

      expect(form['bid'], '12345');
      expect(form['security_ls_key'], 'live-key');
      expect(hash.keys, containsAll(['ct', 'iv', 's']));
      expect(body, isNot(contains(AknigaSecurityEncoder.passphrase)));
    });
  });
}
