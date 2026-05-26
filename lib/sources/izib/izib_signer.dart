import 'dart:convert';

import 'package:crypto/crypto.dart';

class IzibSigner {
  IzibSigner({this.packageName = 'com.izimobile'});

  final String packageName;

  String packageKey() {
    return base64Encode(sha256.convert(utf8.encode(packageName)).bytes);
  }

  String sign(String body) {
    final keyBytes = utf8.encode(packageKey());
    final bodyBytes = utf8.encode(body);

    return base64Encode(sha256.convert([...keyBytes, ...bodyBytes]).bytes);
  }
}
