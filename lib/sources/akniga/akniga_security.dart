import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

class AknigaSecurityEncoder {
  AknigaSecurityEncoder({List<int> Function()? saltFactory})
    : _saltFactory = saltFactory ?? _randomSalt;

  static const passphrase = 'EKxtcg46V';

  final List<int> Function() _saltFactory;

  String securityBody({required String bookId, required String securityKey}) {
    final encrypted = encryptToOpenSslJson(
      '"$securityKey"',
      passphrase: passphrase,
    );
    final hash = jsonEncode(encrypted);

    return Uri(
      queryParameters: {
        'bid': bookId,
        'hash': hash,
        'security_ls_key': securityKey,
      },
    ).query;
  }

  Map<String, String> encryptToOpenSslJson(
    String message, {
    required String passphrase,
  }) {
    final salt = _saltFactory();
    if (salt.length != 8) {
      throw ArgumentError.value(salt.length, 'salt.length', 'must be 8');
    }

    final keyAndIv = _evpBytesToKey(
      password: utf8.encode(passphrase),
      salt: salt,
      keyLength: 32,
      ivLength: 16,
    );
    final key = keyAndIv.sublist(0, 32);
    final iv = keyAndIv.sublist(32, 48);
    final encrypted = _aesCbcEncrypt(utf8.encode(message), key: key, iv: iv);

    return {'ct': base64Encode(encrypted), 'iv': _hex(iv), 's': _hex(salt)};
  }

  static List<int> _evpBytesToKey({
    required List<int> password,
    required List<int> salt,
    required int keyLength,
    required int ivLength,
  }) {
    final generated = <int>[];
    var previous = <int>[];

    while (generated.length < keyLength + ivLength) {
      previous = md5.convert([...previous, ...password, ...salt]).bytes;
      generated.addAll(previous);
    }

    return generated.take(keyLength + ivLength).toList(growable: false);
  }

  static List<int> _aesCbcEncrypt(
    List<int> data, {
    required List<int> key,
    required List<int> iv,
  }) {
    final cipher = CBCBlockCipher(AESEngine())
      ..init(
        true,
        ParametersWithIV<KeyParameter>(
          KeyParameter(Uint8List.fromList(key)),
          Uint8List.fromList(iv),
        ),
      );
    final padded = _pkcs7Pad(data, cipher.blockSize);
    final output = Uint8List(padded.length);
    for (var offset = 0; offset < padded.length; offset += cipher.blockSize) {
      cipher.processBlock(padded, offset, output, offset);
    }
    return output;
  }

  static Uint8List _pkcs7Pad(List<int> data, int blockSize) {
    final padding = blockSize - (data.length % blockSize);
    return Uint8List.fromList([...data, ...List.filled(padding, padding)]);
  }

  static List<int> _randomSalt() {
    final random = Random.secure();
    return List<int>.generate(8, (_) => random.nextInt(256), growable: false);
  }

  static String _hex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
