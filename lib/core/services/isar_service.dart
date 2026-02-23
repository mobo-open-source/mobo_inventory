import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/inventory/models/inventory_product_isar.dart';

class IsarService {
  IsarService._();
  static Isar? _isar;

  static Future<Isar> get instance async {
    if (_isar != null && _isar!.isOpen) return _isar!;

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [

        InventoryProductEntitySchema,
      ],
      directory: dir.path,
      inspector: false,
    );
    return _isar!;
  }
}
