import 'package:isar_community/isar.dart';

import '../../../core/local_db/entities/company_entity.dart';
import '../../../core/local_db/isar_database.dart';

/// Local (offline) cache for companies, backed by Isar.
class CompanyLocalDataSource {
  Future<List<Map<String, dynamic>>> getAllCompanies() async {
    final isar = await IsarDatabase.instance();
    final entities = await isar.companyEntitys.where().sortByName().findAll();
    return entities.map((e) => e.toMap()).toList();
  }

  Future<void> putAllCompanies(List<Map<String, dynamic>> companies) async {
    final isar = await IsarDatabase.instance();
    final entities = companies.map(CompanyEntity.fromMap).toList();
    await isar.writeTxn(() async {
      await isar.companyEntitys.clear();
      await isar.companyEntitys.putAll(entities);
    });
  }

  Future<void> clear() async {
    final isar = await IsarDatabase.instance();
    await isar.writeTxn(() async {
      await isar.companyEntitys.clear();
    });
  }
}
