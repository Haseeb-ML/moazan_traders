import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moazan_traders/data/initial_dealers.dart';
import 'package:moazan_traders/main.dart';
import 'package:moazan_traders/models/ledger_entry.dart';
import 'package:moazan_traders/providers/ledger_provider.dart';
import 'package:moazan_traders/services/ledger_repository.dart';
import 'package:moazan_traders/utils/pdf_report_service.dart';

void main() {
  group('Moazan Traders Ledger Tests', () {
    test('Initial dealer seed contains all 73 dealers', () {
      expect(kInitialDealers.length, 73);
      expect(kInitialDealers.first.code, '100-0002');
      expect(kInitialDealers.last.code, '100-0149');
    });

    test('Full CRUD for Dealers and Entries updates balances accurately',
        () async {
      final repo = InMemoryLedgerRepository();
      final provider = LedgerProvider(repository: repo);
      await provider.seedDefaultDealersIfEmpty();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.dealers.length, 73);

      // Create Dealer
      final newDealer = await provider.addDealer(
        code: '100-0150',
        name: 'TEST BAKERS',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(provider.dealers.length, 74);

      // Create Debit (Bill) & Credit (Payment Received)
      final today = DateTime.now();
      final debitEntry = await provider.addEntry(
        dealer: newDealer,
        type: EntryType.debit,
        amount: 5000,
        date: today,
        billNo: '29',
        note: 'Supply',
      );
      expect(debitEntry.billNo, '29');
      expect(provider.filterEntries(query: '29').length, 1);
      final creditEntry = await provider.addEntry(
        dealer: newDealer,
        type: EntryType.credit,
        amount: 2000,
        date: today,
        note: 'Cash',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.summaryForDealer(newDealer.id).balance, 3000);
      expect(provider.totalReceivable, 3000);

      // Edit Entry (fix bill amount from 5000 to 5050, and verify original date is preserved)
      final twelveDaysAgo = today.subtract(const Duration(days: 12));
      final oldBill = await provider.addEntry(
        dealer: newDealer,
        type: EntryType.debit,
        amount: 1000,
        date: twelveDaysAgo,
        note: 'Old Bill',
      );
      await provider.updateEntry(oldBill.copyWith(amount: 1200));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final updatedOldBill =
          provider.entries.firstWhere((e) => e.id == oldBill.id);
      expect(updatedOldBill.amount, 1200);
      expect(updatedOldBill.date, twelveDaysAgo);
      await provider.deleteEntry(oldBill.id);

      await provider.updateEntry(debitEntry.copyWith(amount: 5050));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(provider.summaryForDealer(newDealer.id).balance, 3050);

      // Edit Dealer (updates denormalized entries too)
      await provider.updateDealer(newDealer.copyWith(name: 'NEW TEST BAKERS'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        provider.entriesForDealer(newDealer.id).first.dealerName,
        'NEW TEST BAKERS',
      );

      // Delete Credit Entry
      await provider.deleteEntry(creditEntry.id);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(provider.summaryForDealer(newDealer.id).balance, 5050);

      // Delete Dealer (cascades to remaining entries)
      await provider.deleteDealer(newDealer.id);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(provider.dealers.length, 73);
      expect(provider.totalReceivable, 0);

      provider.dispose();
      repo.dispose();
    });

    test('Data Export, Import, and Bulk Delete work accurately', () async {
      final repo = InMemoryLedgerRepository(seedDefaults: true);
      final provider = LedgerProvider(repository: repo);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final dealer = provider.dealers.first;
      await provider.addEntry(
        dealer: dealer,
        type: EntryType.debit,
        amount: 4500,
        date: DateTime(2026, 10, 15),
        billNo: '101',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final jsonBackup = provider.exportBackupJson();
      final csvExport = provider.exportDealersCsv();
      expect(csvExport.contains('100-0002,'), isTrue);
      expect(csvExport.contains('4500.0'), isTrue);

      // Clear all entries and verify balance resets
      await provider.deleteAllEntries();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(provider.entries.isEmpty, isTrue);
      expect(provider.dealers.length, 73);

      // Import JSON backup back (replace mode)
      final res =
          await provider.importBackupJson(jsonBackup, replaceExisting: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(res.dealersImported, 73);
      expect(res.entriesImported, 1);
      expect(provider.totalReceivable, 4500);

      // Bulk delete by date range
      final deletedCount = await provider.deleteEntriesInRange(
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 31, 23, 59, 59),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(deletedCount, 1);
      expect(provider.entries.isEmpty, isTrue);

      provider.dispose();
      repo.dispose();
    });

    test('Deduplicating dealers merges duplicates and preserves entries',
        () async {
      final repo = InMemoryLedgerRepository(seedDefaults: true);
      // Simulate a duplicate dealer already in DB before app starts
      final dupDealer = await repo.addDealer(
        code: '100-0002',
        name: 'HAFIZ TARIQ K/S',
      );
      await repo.addEntry(
        dealer: dupDealer,
        type: EntryType.debit,
        amount: 2500,
        date: DateTime.now(),
      );

      final provider = LedgerProvider(repository: repo);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await provider.removeDuplicateDealers();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Auto-dedup should have merged duplicates back to 73 while preserving the 2500 entry
      expect(provider.dealers.length, 73);
      expect(provider.totalReceivable, 2500);

      // Verify Dealer Balance PDF generates valid PDF bytes
      final pdfBytes = await PdfReportService.buildAllDealersBalancePdf(
        provider.getDealerSummaries(),
      );
      expect(pdfBytes.length, greaterThan(1000));
      expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');

      provider.dispose();
      repo.dispose();
    });

    testWidgets('UI renders dealers, searches by code/name, and switches tabs',
        (tester) async {
      final repo = InMemoryLedgerRepository(seedDefaults: true);
      await tester.pumpWidget(MoazanTradersApp(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Moazan Traders'), findsOneWidget);
      expect(find.text('73 Dealers'), findsOneWidget);
      expect(find.text('HAFIZ TARIQ K/S'), findsOneWidget);

      // Search by Dealer Code
      await tester.enterText(find.byType(TextField).first, '100-0075');
      await tester.pumpAndSettle();
      expect(find.text('ZAHOOR BAKERS'), findsOneWidget);
      expect(find.text('HAFIZ TARIQ K/S'), findsNothing);

      // Switch to Cross-Check tab
      await tester.tap(find.text('Cross-Check'));
      await tester.pumpAndSettle();
      expect(find.text('Entries Cross-Check'), findsOneWidget);

      // Switch to Reports tab
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      expect(find.text('Total Debit (Bills)'), findsOneWidget);

      repo.dispose();
    });

    testWidgets('Mobile viewport (360x640) renders without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryLedgerRepository(seedDefaults: true);
      await tester.pumpWidget(MoazanTradersApp(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('New Debit'), findsOneWidget);
      expect(find.text('New Credit'), findsOneWidget);

      // Open HAFIZ TARIQ K/S ledger and verify Edit + Delete icons fit cleanly
      await tester.ensureVisible(find.text('HAFIZ TARIQ K/S'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HAFIZ TARIQ K/S'));
      await tester.pumpAndSettle();
      expect(find.text('Code: 100-0002'), findsOneWidget);

      // Add a Wasooli entry via repository and verify Edit/Delete icons are visible
      final dealer = repo.watchDealers();
      final firstDealer = (await dealer.first).first;
      await repo.addEntry(
        dealer: firstDealer,
        type: EntryType.credit,
        amount: 58,
        date: DateTime.now(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total'), findsOneWidget);
      expect(find.byTooltip('Edit Entry'), findsOneWidget);
      expect(find.byTooltip('Delete Entry'), findsOneWidget);
      expect(tester.takeException(), isNull);

      repo.dispose();
    });
  });
}
