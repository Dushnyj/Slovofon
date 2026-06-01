import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

Future<bool> verifyUpdateManifestSignature(
  Map<String, Object?> manifest, {
  required Map<String, String> publicKeys,
}) async {
  final signature = manifest['signature'];
  if (signature is! Map) {
    return false;
  }

  final signatureMap = Map<String, Object?>.from(signature);
  if (signatureMap['alg'] != 'ed25519') {
    return false;
  }

  final keyId = signatureMap['key_id'];
  final signatureValue = signatureMap['value'];
  if (keyId is! String || signatureValue is! String) {
    return false;
  }

  final publicKeyValue = publicKeys[keyId];
  if (publicKeyValue == null) {
    return false;
  }

  final publicKeyBytes = _decodeBase64(publicKeyValue);
  final signatureBytes = _decodeBase64(signatureValue);
  if (publicKeyBytes == null ||
      publicKeyBytes.length != 32 ||
      signatureBytes == null ||
      signatureBytes.length != 64) {
    return false;
  }

  final payload = Map<String, Object?>.from(manifest)..remove('signature');
  final canonical = Uint8List.fromList(utf8.encode(_canonicalJson(payload)));
  final publicKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
  final updateSignature = Signature(signatureBytes, publicKey: publicKey);

  try {
    return await Ed25519().verify(canonical, signature: updateSignature);
  } on Object {
    return false;
  }
}

String _canonicalJson(Object? value) {
  return jsonEncode(_sortedJsonValue(value));
}

Object? _sortedJsonValue(Object? value) {
  if (value is Map) {
    final sorted = SplayTreeMap<String, Object?>();
    for (final entry in value.entries) {
      sorted[entry.key.toString()] = _sortedJsonValue(entry.value);
    }
    return sorted;
  }
  if (value is List) {
    return [for (final item in value) _sortedJsonValue(item)];
  }
  return value;
}

List<int>? _decodeBase64(String value) {
  try {
    return base64Decode(value);
  } on FormatException {
    return null;
  }
}
