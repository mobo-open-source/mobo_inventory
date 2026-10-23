import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/services/access_rights_service.dart';
import 'package:mobo_inv_app/features/transfer/models/transfer_model.dart';
import 'package:mobo_inv_app/features/transfer/pages/transfer_list_screen.dart';
import 'package:mobo_inv_app/features/transfer/providers/transfer_provider.dart';
import 'package:mobo_inv_app/shared/widgets/filters/premium_filter_bottom_sheet.dart';
import 'package:provider/provider.dart';

import '../../../helpers/fake_access_rights.dart';
import '../../../shared/widgets/layout/landscape_test_helpers.dart';

/// A [TransferProvider] that records what the screen asks it to fetch, and
/// keeps the status filter the way the real one does, without a network.
class _RecordingTransferProvider extends TransferProvider {
  /// The `states` of every `fetchTransfers` call, in order.
  final List<List<String>?> fetches = [];
  List<String> applied = [];

  @override
  List<String> get selectedStates => applied;

  @override
  bool get isLoading => false;
  @override
  bool get hasLoadedOnce => true;
  @override
  String? get error => null;
  @override
  List<InternalTransfer> get transfers => [
    for (var i = 0; i < 3; i++)
      InternalTransfer(
        id: i,
        name: 'WH/INT/0000$i',
        scheduledDate: '2026-10-12 09:00:00',
      ),
  ];
  @override
  int get totalCount => 3;
  @override
  bool get canGoToNextPage => false;
  @override
  bool get canGoToPreviousPage => false;

  @override
  Future<void> fetchTransfers({
    String? searchQuery,
    List<String>? states,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
    bool updateFilters = true,
  }) async {
    fetches.add(states);
    if (updateFilters && states != null) applied = states;
    notifyListeners();
  }

  @override
  Future<void> fetchGroupSummary() async {}
}

Widget _app(TransferProvider provider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TransferProvider>.value(value: provider),
      ChangeNotifierProvider<AccessRightsService>(
        create: (_) => fakeAccessRights(),
      ),
    ],
    child: const MaterialApp(home: FakeShell(child: TransferListScreen())),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Filter & Group By'));
  await tester.pumpAndSettle();
  expect(find.byType(PremiumFilterBottomSheet), findsOneWidget);
}

void main() {
  testWidgets('the filter button opens the sheet; a status picked and applied '
      'reaches the provider and shows in the badge', (tester) async {
    setPortraitPhone(tester);
    final provider = _RecordingTransferProvider();
    await tester.pumpWidget(_app(provider));
    await _settle(tester);

    // Nothing applied yet.
    expect(find.text('No filters applied'), findsOneWidget);

    await _openSheet(tester);
    await tester.tap(find.text('Ready'));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.byType(PremiumFilterBottomSheet), findsNothing);
    expect(provider.fetches.last, ['assigned']);
    expect(find.text('No filters applied'), findsNothing);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('reopened, the applied status is selected; Clear All removes it '
      'from the provider and the badge', (tester) async {
    setPortraitPhone(tester);
    final provider = _RecordingTransferProvider()..applied = ['done'];
    await tester.pumpWidget(_app(provider));
    await _settle(tester);
    expect(find.text('Active'), findsOneWidget);

    await _openSheet(tester);
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Done')).selected,
      isTrue,
    );

    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();

    expect(provider.fetches.last, isEmpty);
    expect(find.text('Active'), findsNothing);
    expect(find.text('No filters applied'), findsOneWidget);
  });
}
