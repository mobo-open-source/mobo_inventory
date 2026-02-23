import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobo_inv_app/features/inventory/providers/inventory_product_provider.dart';

Widget wrapWithProviders({
  required Widget child,
  required InventoryProductProvider inventoryProductProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<InventoryProductProvider>.value(
        value: inventoryProductProvider,
      ),
    ],
    child: MaterialApp(home: child),
  );
}
