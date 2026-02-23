import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

import 'entities/company_entity.dart';

class IsarDatabase {
  IsarDatabase._();
  static Isar? _instance;

  static Future<Isar> instance() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationDocumentsDirectory();
    _instance = await Isar.open(
      [CompanyEntitySchema],
      directory: dir.path,
      inspector: false,
    );
    return _instance!;
  }
}
