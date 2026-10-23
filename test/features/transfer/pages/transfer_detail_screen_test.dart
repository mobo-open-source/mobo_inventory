import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/services/access_rights_service.dart';
import 'package:mobo_inv_app/features/transfer/models/transfer_model.dart';
import 'package:mobo_inv_app/features/transfer/pages/transfer_detail_screen.dart';
import 'package:mobo_inv_app/features/transfer/providers/transfer_provider.dart';
import 'package:provider/provider.dart';

import '../../../helpers/fake_access_rights.dart';

/// Serves no fresher details, so the screen keeps the transfer it was given.
class _FakeTransferProvider extends TransferProvider {
  @override
  Future<InternalTransfer?> fetchTransferDetails(int transferId) async => null;
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required String state,
  Set<String> denied = const {},
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TransferProvider>(
          create: (_) => _FakeTransferProvider(),
        ),
        ChangeNotifierProvider<AccessRightsService>(
          create: (_) => fakeAccessRights(denied: denied),
        ),
      ],
      child: MaterialApp(
        home: TransferDetailScreen(
          transfer: InternalTransfer(
            id: 7,
            name: 'WH/INT/00007',
            state: state,
            scheduledDate: '2026-10-12 09:00:00',
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
}

Finder get _edit => find.byTooltip('Edit');

void main() {
  testWidgets('a ready transfer shows Edit, Cancel and Validate', (
    tester,
  ) async {
    await _pumpDetail(tester, state: 'assigned');
    expect(_edit, findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Validate'), findsOneWidget);
  });

  testWidgets('a draft transfer shows Mark as Todo', (tester) async {
    await _pumpDetail(tester, state: 'draft');
    expect(find.text('Mark as Todo'), findsOneWidget);
  });

  for (final denied in [
    'stock.picking|write',
    'stock.move|unlink',
    'stock.move|create',
  ]) {
    testWidgets('Edit is hidden without $denied', (tester) async {
      await _pumpDetail(tester, state: 'assigned', denied: {denied});
      expect(_edit, findsNothing);
    });
  }

  testWidgets('without picking write every action is hidden', (tester) async {
    await _pumpDetail(tester, state: 'draft', denied: {'stock.picking|write'});
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Mark as Todo'), findsNothing);
    expect(_edit, findsNothing);
  });

  testWidgets('Validate also needs move write; Cancel does not', (
    tester,
  ) async {
    await _pumpDetail(tester, state: 'assigned', denied: {'stock.move|write'});
    expect(find.text('Validate'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
    expect(_edit, findsOneWidget);
  });
}
