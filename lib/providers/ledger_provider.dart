import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/initial_dealers.dart';
import '../models/dealer.dart';
import '../models/ledger_entry.dart';
import '../services/ledger_repository.dart';
import '../utils/formatters.dart';

class DealerSummary {
  final Dealer dealer;
  final double totalDebit;
  final double totalCredit;
  final int entryCount;

  const DealerSummary({
    required this.dealer,
    required this.totalDebit,
    required this.totalCredit,
    required this.entryCount,
  });

  double get balance => totalDebit - totalCredit;
}

class LedgerProvider extends ChangeNotifier {
  final LedgerRepository repository;

  List<Dealer> _dealers = [];
  List<LedgerEntry> _entries = [];
  bool _isLoading = true;
  bool _dedupChecked = false;
  String? _error;

  StreamSubscription<List<Dealer>>? _dealersSub;
  StreamSubscription<List<LedgerEntry>>? _entriesSub;

  LedgerProvider({required this.repository}) {
    _init();
  }

  bool get isLoading => _isLoading;
  bool get isCloudSynced => repository.isCloudSynced;
  String? get error => _error;
  List<Dealer> get dealers => _dealers;
  List<LedgerEntry> get entries => _entries;

  void _init() {
    _dealersSub = repository.watchDealers().listen(
      (list) {
        _dealers = list;
        _isLoading = false;
        _error = null;
        notifyListeners();
        if (!_dedupChecked && _hasDuplicateCodes(list)) {
          _dedupChecked = true;
          Timer.run(() => repository.deduplicateDealers());
        }
      },
      onError: (Object e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );

    _entriesSub = repository.watchEntries().listen(
      (list) {
        _entries = list;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  bool _hasDuplicateCodes(List<Dealer> list) {
    final seen = <String>{};
    for (final d in list) {
      final code = d.code.trim();
      if (code.isNotEmpty && !seen.add(code)) {
        return true;
      }
    }
    return false;
  }

  /// Auto-seed the 73 Moazan Traders dealers if the database is empty.
  Future<void> seedDefaultDealersIfEmpty() async {
    await repository.seedInitialDealers(kInitialDealers);
  }

  Future<int> removeDuplicateDealers() {
    return repository.deduplicateDealers();
  }

  /// Computes summary for each dealer (total debit, total credit, net balance).
  List<DealerSummary> getDealerSummaries({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final debitMap = <String, double>{};
    final creditMap = <String, double>{};
    final countMap = <String, int>{};

    for (final entry in _entries) {
      if (startDate != null && entry.date.isBefore(startDate)) continue;
      if (endDate != null && entry.date.isAfter(endDate)) continue;

      countMap[entry.dealerId] = (countMap[entry.dealerId] ?? 0) + 1;
      if (entry.type == EntryType.debit) {
        debitMap[entry.dealerId] = (debitMap[entry.dealerId] ?? 0) + entry.amount;
      } else {
        creditMap[entry.dealerId] =
            (creditMap[entry.dealerId] ?? 0) + entry.amount;
      }
    }

    return _dealers.map((d) {
      return DealerSummary(
        dealer: d,
        totalDebit: debitMap[d.id] ?? 0,
        totalCredit: creditMap[d.id] ?? 0,
        entryCount: countMap[d.id] ?? 0,
      );
    }).toList();
  }

  DealerSummary summaryForDealer(String dealerId) {
    final dealer = _dealers.firstWhere(
      (d) => d.id == dealerId,
      orElse: () => Dealer(
        id: dealerId,
        code: '',
        name: 'Unknown Dealer',
        createdAt: DateTime.now(),
      ),
    );
    double debit = 0;
    double credit = 0;
    int count = 0;
    for (final e in _entries) {
      if (e.dealerId == dealerId) {
        count++;
        if (e.type == EntryType.debit) {
          debit += e.amount;
        } else {
          credit += e.amount;
        }
      }
    }
    return DealerSummary(
      dealer: dealer,
      totalDebit: debit,
      totalCredit: credit,
      entryCount: count,
    );
  }

  List<LedgerEntry> entriesForDealer(
    String dealerId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _entries.where((e) {
      if (e.dealerId != dealerId) return false;
      if (startDate != null && e.date.isBefore(startDate)) return false;
      if (endDate != null && e.date.isAfter(endDate)) return false;
      return true;
    }).toList();
  }

  List<LedgerEntry> filterEntries({
    DateTime? startDate,
    DateTime? endDate,
    String query = '',
    EntryType? type,
  }) {
    final q = query.trim().toLowerCase();
    return _entries.where((e) {
      if (startDate != null && e.date.isBefore(startDate)) return false;
      if (endDate != null && e.date.isAfter(endDate)) return false;
      if (type != null && e.type != type) return false;
      if (q.isNotEmpty) {
        final matchName = e.dealerName.toLowerCase().contains(q);
        final matchCode = e.dealerCode.toLowerCase().contains(q);
        final matchBillNo = e.billNo.toLowerCase().contains(q);
        final matchNote = e.note.toLowerCase().contains(q);
        if (!matchName && !matchCode && !matchBillNo && !matchNote) return false;
      }
      return true;
    }).toList();
  }

  double get totalReceivable {
    double total = 0;
    for (final e in _entries) {
      total += e.type == EntryType.debit ? e.amount : -e.amount;
    }
    return total;
  }

  double totalDebitInRange(DateTime? start, DateTime? end) {
    return filterEntries(startDate: start, endDate: end, type: EntryType.debit)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double totalCreditInRange(DateTime? start, DateTime? end) {
    return filterEntries(startDate: start, endDate: end, type: EntryType.credit)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  ({DateTime? start, DateTime? end}) resolvePreset(
    DateFilterPreset preset, {
    DateTimeRange? customRange,
  }) {
    final now = DateTime.now();
    switch (preset) {
      case DateFilterPreset.today:
        return (
          start: AppFormatters.startOfDay(now),
          end: AppFormatters.endOfDay(now),
        );
      case DateFilterPreset.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return (
          start: AppFormatters.startOfDay(weekStart),
          end: AppFormatters.endOfDay(now),
        );
      case DateFilterPreset.thisMonth:
        return (
          start: DateTime(now.year, now.month, 1),
          end: AppFormatters.endOfDay(now),
        );
      case DateFilterPreset.allTime:
        return (start: null, end: null);
      case DateFilterPreset.custom:
        if (customRange == null) return (start: null, end: null);
        return (
          start: AppFormatters.startOfDay(customRange.start),
          end: AppFormatters.endOfDay(customRange.end),
        );
    }
  }

  String suggestNextDealerCode() {
    int maxNum = 149;
    for (final d in _dealers) {
      final parts = d.code.split('-');
      if (parts.length == 2) {
        final parsed = int.tryParse(parts[1]);
        if (parsed != null && parsed > maxNum) {
          maxNum = parsed;
        }
      }
    }
    final next = (maxNum + 1).toString().padLeft(4, '0');
    return '100-$next';
  }

  // --- CRUD Operations ---

  Future<Dealer> addDealer({
    required String code,
    required String name,
  }) {
    return repository.addDealer(code: code, name: name);
  }

  Future<void> updateDealer(Dealer dealer) {
    return repository.updateDealer(dealer);
  }

  Future<void> deleteDealer(String dealerId) {
    return repository.deleteDealer(dealerId);
  }

  Future<LedgerEntry> addEntry({
    required Dealer dealer,
    required EntryType type,
    required double amount,
    required DateTime date,
    String billNo = '',
    String note = '',
  }) {
    return repository.addEntry(
      dealer: dealer,
      type: type,
      amount: amount,
      date: date,
      billNo: billNo,
      note: note,
    );
  }

  Future<void> updateEntry(LedgerEntry entry) {
    return repository.updateEntry(entry);
  }

  Future<void> deleteEntry(String entryId) {
    return repository.deleteEntry(entryId);
  }

  // --- Data Import / Export / Bulk Delete ---

  String exportBackupJson() {
    final payload = {
      'app': 'Moazan Traders Digital Khata',
      'exportedAt': DateTime.now().toIso8601String(),
      'dealers': _dealers
          .map((d) => {
                'id': d.id,
                ...d.toMap(),
              })
          .toList(),
      'entries': _entries
          .map((e) => {
                'id': e.id,
                ...e.toMap(),
              })
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String exportDealersCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Dealer Code,Dealer Name,Total Debit,Total Credit,Balance');
    for (final s in getDealerSummaries()) {
      final safeName = '"${s.dealer.name.replaceAll('"', '""')}"';
      buffer.writeln(
          '${s.dealer.code},$safeName,${s.totalDebit},${s.totalCredit},${s.balance}');
    }
    return buffer.toString();
  }

  Future<({int dealersImported, int entriesImported})> importBackupJson(
    String rawJson, {
    bool replaceExisting = false,
  }) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup JSON format');
    }

    final rawDealers = decoded['dealers'];
    final rawEntries = decoded['entries'];

    final dealersList = <Dealer>[];
    if (rawDealers is List) {
      for (final item in rawDealers) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final id = (map['id'] ?? '').toString();
          dealersList.add(Dealer.fromMap(id, map));
        }
      }
    }

    final entriesList = <LedgerEntry>[];
    if (rawEntries is List) {
      for (final item in rawEntries) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final id = (map['id'] ?? '').toString();
          entriesList.add(LedgerEntry.fromMap(id, map));
        }
      }
    }

    return repository.importData(
      dealers: dealersList,
      entries: entriesList,
      replaceExisting: replaceExisting,
    );
  }

  Future<int> deleteEntriesInRange(DateTime start, DateTime end) {
    return repository.deleteEntriesInRange(start, end);
  }

  Future<void> deleteAllEntries() {
    return repository.deleteAllEntries();
  }

  Future<void> deleteAllData() {
    return repository.deleteAllData();
  }

  @override
  void dispose() {
    _dealersSub?.cancel();
    _entriesSub?.cancel();
    super.dispose();
  }
}
