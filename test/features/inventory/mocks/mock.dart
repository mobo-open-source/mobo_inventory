import 'package:mocktail/mocktail.dart';
import 'package:flutter/material.dart';
import 'package:mobo_inv_app/features/inventory/providers/inventory_product_provider.dart';

class MockInventoryProductProvider extends Mock
    implements InventoryProductProvider {}

class FakeBuildContext extends Fake implements BuildContext {}
