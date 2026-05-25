import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor openAppDatabaseConnection() {
  return LazyDatabase(() async {
    final appSupportDirectory = await getApplicationSupportDirectory();
    final databaseFile = File(
      p.join(appSupportDirectory.path, 'slovofon.sqlite'),
    );

    return NativeDatabase.createInBackground(databaseFile);
  });
}
