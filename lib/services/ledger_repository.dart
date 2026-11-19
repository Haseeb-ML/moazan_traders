import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/initial_dealers.dart';
import '../models/dealer.dart';
import '../models/ledger_entry.dart';

/// Abstraction over Firestore / local storage for dealers and ledger entries.
abstract class LedgerRepository {
  bool get isCloudSynced;

  Stream<List<Dealer>> watchDealers();
  Stream<List<LedgerEntry>> watchEntries();

  Future<void> seedInitialDealers(List<InitialDealerSeed> seeds);
  Future<int> deduplicateDealers();
  Future<Dealer> addDealer({required String code, required String name});
  Future<void> updateDealer(Dealer dealer);
  Future<void> deleteDealer(String dealerId);

  Future<LedgerEntry> addEntry({
    required Dealer dealer,
    required EntryType type,
    required double amount,
    required DateTime date,
    String billNo = '',
    String note = '',
  });
  Future<void> updateEntry(LedgerEntry entry);
  Future<void> deleteEntry(String entryId);

  Future<({int dealersImported, int entriesImported})> importData({
    required List<Dealer> dealers,
    required List<LedgerEntry> entries,
    bool replaceExisting = false,
  });
  Future<int> deleteEntriesInRange(DateTime start, DateTime end);
  Future<void> deleteAllEntries();
  Future<void> deleteAllData();
}

/// Cloud Firestore implementation for real-time sync across Mobile & Web.
class FirestoreLedgerRepository implements LedgerRepository {
  final FirebaseFirestore _firestore;

  FirestoreLedgerRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _dealersCol =>
      _firestore.collection('dealers');

  CollectionReference<Map<String, dynamic>> get _entriesCol =>
      _firestore.collection('entries');

  @override
  bool get isCloudSynced => true;

  @override
  Stream<List<Dealer>> watchDealers() {
    return _dealersCol.orderBy('code').snapshots().map((snap) {
      return snap.docs
          .map((doc) => Dealer.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  @override
  Stream<List<LedgerEntry>> watchEntries() {
    return _entriesCol.orderBy('date', descending: true).snapshots().map((snap) {
      return snap.docs
          .map((doc) => LedgerEntry.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  @override
  Future<void> seedInitialDealers(List<InitialDealerSeed> seeds) async {
    final existing = await _dealersCol.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _firestore.batch();
    final now = DateTime.now();
    for (final seed in seeds) {
      // Use deterministic document ID (seed.code) so concurrent startups never create duplicates.
      final docRef = _dealersCol.doc(seed.code);
      batch.set(docRef, {
        'code': seed.code,
        'name': seed.name,
        'createdAt': now.toIso8601String(),
      });
    }
    await batch.commit();
  }

  @override
  Future<int> deduplicateDealers() async {
    final dealersSnap = await _dealersCol.get();
    final byCode = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final doc in dealersSnap.docs) {
      final code = (doc.data()['code'] ?? '').toString().trim();
      if (code.isEmpty) continue;
      byCode.putIfAbsent(code, () => []).add(doc);
    }

    final duplicateGroups =
        byCode.values.where((group) => group.length > 1).toList();
    if (duplicateGroups.isEmpty) return 0;

    final entriesSnap = await _entriesCol.get();
    final entryCounts = <String, int>{};
    for (final e in entriesSnap.docs) {
      final dId = (e.data()['dealerId'] ?? '').toString();
      entryCounts[dId] = (entryCounts[dId] ?? 0) + 1;
    }

    var batch = _firestore.batch();
    int ops = 0;
    int removedCount = 0;

    for (final group in duplicateGroups) {
      // Keep the dealer with the most entries (or first one if tied).
      group.sort((a, b) =>
          (entryCounts[b.id] ?? 0).compareTo(entryCounts[a.id] ?? 0));
      final keeper = group.first;

      for (int i = 1; i < group.length; i++) {
        final dup = group[i];
        // Re-point any entries from duplicate dealer to the keeper dealer.
        for (final entryDoc in entriesSnap.docs) {
          if ((entryDoc.data()['dealerId'] ?? '').toString() == dup.id) {
            batch.update(entryDoc.reference, {
              'dealerId': keeper.id,
              'dealerCode': (keeper.data()['code'] ?? '').toString(),
              'dealerName': (keeper.data()['name'] ?? '').toString(),
            });
            ops++;
            if (ops >= 400) {
              await batch.commit();
              batch = _firestore.batch();
              ops = 0;
            }
          }
        }
        batch.delete(dup.reference);
        removedCount++;
        ops++;
        if (ops >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          ops = 0;
        }
      }
    }

    if (ops > 0) {
      await batch.commit();
    }
    return removedCount;
  }

  @override
  Future<Dealer> addDealer({
    required String code,
    required String name,
  }) async {
    final now = DateTime.now();
    final docRef = _dealersCol.doc();
    final dealer = Dealer(
      id: docRef.id,
      code: code.trim(),
      name: name.trim(),
      createdAt: now,
    );
    // Queue write optimistically so UI updates instantly via Firestore local cache.
    unawaited(docRef.set(dealer.toMap()));
    return dealer;
  }

  @override
  Future<void> updateDealer(Dealer dealer) async {
    final batch = _firestore.batch();
    batch.update(_dealersCol.doc(dealer.id), {
      'code': dealer.code.trim(),
      'name': dealer.name.trim(),
    });

    // Keep denormalized dealer info in entries in sync.
    final relatedEntries =
        await _entriesCol.where('dealerId', isEqualTo: dealer.id).get();
    for (final doc in relatedEntries.docs) {
      batch.update(doc.reference, {
        'dealerCode': dealer.code.trim(),
        'dealerName': dealer.name.trim(),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> deleteDealer(String dealerId) async {
    final batch = _firestore.batch();
    batch.delete(_dealersCol.doc(dealerId));

    final relatedEntries =
        await _entriesCol.where('dealerId', isEqualTo: dealerId).get();
    for (final doc in relatedEntries.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Future<LedgerEntry> addEntry({
    required Dealer dealer,
    required EntryType type,
    required double amount,
    required DateTime date,
    String billNo = '',
    String note = '',
  }) async {
    final now = DateTime.now();
    final docRef = _entriesCol.doc();
    final entry = LedgerEntry(
      id: docRef.id,
      dealerId: dealer.id,
      dealerCode: dealer.code,
      dealerName: dealer.name,
      type: type,
      amount: amount,
      date: date,
      billNo: billNo.trim(),
      note: note.trim(),
      createdAt: now,
    );
    // Queue write optimistically so Debit/Credit saves feel instant even on slow internet.
    unawaited(docRef.set(entry.toMap()));
    return entry;
  }

  @override
  Future<void> updateEntry(LedgerEntry entry) async {
    unawaited(_entriesCol.doc(entry.id).update(entry.toMap()));
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    unawaited(_entriesCol.doc(entryId).delete());
  }

  Future<void> _deleteCollection(
      CollectionReference<Map<String, dynamic>> col) async {
    final snap = await col.get();
    const chunkSize = 400;
    for (int i = 0; i < snap.docs.length; i += chunkSize) {
      final batch = _firestore.batch();
      final end = (i + chunkSize < snap.docs.length)
          ? i + chunkSize
          : snap.docs.length;
      for (int j = i; j < end; j++) {
        batch.delete(snap.docs[j].reference);
      }
      await batch.commit();
    }
  }

  @override
  Future<({int dealersImported, int entriesImported})> importData({
    required List<Dealer> dealers,
    required List<LedgerEntry> entries,
    bool replaceExisting = false,
  }) async {
    if (replaceExisting) {
      await _deleteCollection(_entriesCol);
      await _deleteCollection(_dealersCol);
    }

    final existingDealersSnap = await _dealersCol.get();
    final codeToId = <String, String>{};
    for (final doc in existingDealersSnap.docs) {
      final code = (doc.data()['code'] ?? '').toString().trim();
      if (code.isNotEmpty) codeToId[code] = doc.id;
    }

    int dealersAdded = 0;
    int entriesAdded = 0;

    final dealerIdMap = <String, String>{};
    var batch = _firestore.batch();
    int ops = 0;

    for (final d in dealers) {
      final existingId = codeToId[d.code.trim()];
      if (existingId != null) {
        dealerIdMap[d.id] = existingId;
      } else {
        final docRef = _dealersCol.doc();
        dealerIdMap[d.id] = docRef.id;
        codeToId[d.code.trim()] = docRef.id;
        batch.set(docRef, d.toMap());
        dealersAdded++;
        ops++;
        if (ops >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          ops = 0;
        }
      }
    }

    for (final e in entries) {
      final targetDealerId = dealerIdMap[e.dealerId] ?? e.dealerId;
      final docRef = _entriesCol.doc();
      batch.set(
        docRef,
        e.copyWith(dealerId: targetDealerId).toMap(),
      );
      entriesAdded++;
      ops++;
      if (ops >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        ops = 0;
      }
    }

    if (ops > 0) {
      await batch.commit();
    }

    return (dealersImported: dealersAdded, entriesImported: entriesAdded);
  }

  @override
  Future<int> deleteEntriesInRange(DateTime start, DateTime end) async {
    final snap = await _entriesCol.get();
    final toDelete = snap.docs.where((doc) {
      final date =
          DateTime.tryParse((doc.data()['date'] ?? '').toString());
      if (date == null) return false;
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();

    const chunkSize = 400;
    for (int i = 0; i < toDelete.length; i += chunkSize) {
      final batch = _firestore.batch();
      final sliceEnd = (i + chunkSize < toDelete.length)
          ? i + chunkSize
          : toDelete.length;
      for (int j = i; j < sliceEnd; j++) {
        batch.delete(toDelete[j].reference);
      }
      await batch.commit();
    }
    return toDelete.length;
  }

  @override
  Future<void> deleteAllEntries() async {
    await _deleteCollection(_entriesCol);
  }

  @override
  Future<void> deleteAllData() async {
    await _deleteCollection(_entriesCol);
    await _deleteCollection(_dealersCol);
  }
}

/// In-memory repository used for automated tests and local fallback when
/// Firebase is not yet configured.
class InMemoryLedgerRepository implements LedgerRepository {
  final List<Dealer> _dealers = [];
  final List<LedgerEntry> _entries = [];
  int _idCounter = 1;

  final _dealersController = StreamController<List<Dealer>>.broadcast();
  final _entriesController = StreamController<List<LedgerEntry>>.broadcast();

  InMemoryLedgerRepository({bool seedDefaults = false}) {
    if (seedDefaults) {
      final now = DateTime.now();
      for (final s in kInitialDealers) {
        _dealers.add(Dealer(
          id: 'd_${_idCounter++}',
          code: s.code,
          name: s.name,
          createdAt: now,
        ));
      }
    }
  }

  @override
  bool get isCloudSynced => false;

  void _emitDealers() {
    final sorted = List<Dealer>.from(_dealers)
      ..sort((a, b) => a.code.compareTo(b.code));
    _dealersController.add(sorted);
  }

  void _emitEntries() {
    final sorted = List<LedgerEntry>.from(_entries)
      ..sort((a, b) {
        final cmp = b.date.compareTo(a.date);
        return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
      });
    _entriesController.add(sorted);
  }

  @override
  Stream<List<Dealer>> watchDealers() async* {
    final sorted = List<Dealer>.from(_dealers)
      ..sort((a, b) => a.code.compareTo(b.code));
    yield sorted;
    yield* _dealersController.stream;
  }

  @override
  Stream<List<LedgerEntry>> watchEntries() async* {
    final sorted = List<LedgerEntry>.from(_entries)
      ..sort((a, b) {
        final cmp = b.date.compareTo(a.date);
        return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
      });
    yield sorted;
    yield* _entriesController.stream;
  }

  @override
  Future<void> seedInitialDealers(List<InitialDealerSeed> seeds) async {
    if (_dealers.isNotEmpty) return;
    final now = DateTime.now();
    for (final seed in seeds) {
      _dealers.add(Dealer(
        id: 'd_${_idCounter++}',
        code: seed.code,
        name: seed.name,
        createdAt: now,
      ));
    }
    _emitDealers();
  }

  @override
  Future<int> deduplicateDealers() async {
    final byCode = <String, List<Dealer>>{};
    for (final d in _dealers) {
      final code = d.code.trim();
      if (code.isEmpty) continue;
      byCode.putIfAbsent(code, () => []).add(d);
    }

    final duplicateGroups =
        byCode.values.where((g) => g.length > 1).toList();
    if (duplicateGroups.isEmpty) {
      _emitDealers();
      return 0;
    }

    final entryCounts = <String, int>{};
    for (final e in _entries) {
      entryCounts[e.dealerId] = (entryCounts[e.dealerId] ?? 0) + 1;
    }

    int removed = 0;
    for (final group in duplicateGroups) {
      group.sort((a, b) =>
          (entryCounts[b.id] ?? 0).compareTo(entryCounts[a.id] ?? 0));
      final keeper = group.first;
      for (int i = 1; i < group.length; i++) {
        final dup = group[i];
        for (int j = 0; j < _entries.length; j++) {
          if (_entries[j].dealerId == dup.id) {
            _entries[j] = _entries[j].copyWith(
              dealerId: keeper.id,
              dealerCode: keeper.code,
              dealerName: keeper.name,
            );
          }
        }
        _dealers.removeWhere((d) => d.id == dup.id);
        removed++;
      }
    }

    _emitDealers();
    _emitEntries();
    return removed;
  }

  @override
  Future<Dealer> addDealer({
    required String code,
    required String name,
  }) async {
    final dealer = Dealer(
      id: 'd_${_idCounter++}',
      code: code.trim(),
      name: name.trim(),
      createdAt: DateTime.now(),
    );
    _dealers.add(dealer);
    _emitDealers();
    return dealer;
  }

  @override
  Future<void> updateDealer(Dealer dealer) async {
    final index = _dealers.indexWhere((d) => d.id == dealer.id);
    if (index != -1) {
      _dealers[index] = dealer.copyWith(
        code: dealer.code.trim(),
        name: dealer.name.trim(),
      );
    }
    for (int i = 0; i < _entries.length; i++) {
      if (_entries[i].dealerId == dealer.id) {
        _entries[i] = _entries[i].copyWith(
          dealerCode: dealer.code.trim(),
          dealerName: dealer.name.trim(),
        );
      }
    }
    _emitDealers();
    _emitEntries();
  }

  @override
  Future<void> deleteDealer(String dealerId) async {
    _dealers.removeWhere((d) => d.id == dealerId);
    _entries.removeWhere((e) => e.dealerId == dealerId);
    _emitDealers();
    _emitEntries();
  }

  @override
  Future<LedgerEntry> addEntry({
    required Dealer dealer,
    required EntryType type,
    required double amount,
    required DateTime date,
    String billNo = '',
    String note = '',
  }) async {
    final entry = LedgerEntry(
      id: 'e_${_idCounter++}',
      dealerId: dealer.id,
      dealerCode: dealer.code,
      dealerName: dealer.name,
      type: type,
      amount: amount,
      date: date,
      billNo: billNo.trim(),
      note: note.trim(),
      createdAt: DateTime.now(),
    );
    _entries.add(entry);
    _emitEntries();
    return entry;
  }

  @override
  Future<void> updateEntry(LedgerEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
      _emitEntries();
    }
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    _entries.removeWhere((e) => e.id == entryId);
    _emitEntries();
  }

  @override
  Future<({int dealersImported, int entriesImported})> importData({
    required List<Dealer> dealers,
    required List<LedgerEntry> entries,
    bool replaceExisting = false,
  }) async {
    if (replaceExisting) {
      _dealers.clear();
      _entries.clear();
    }

    final codeToId = <String, String>{
      for (final d in _dealers) d.code.trim(): d.id,
    };
    final dealerIdMap = <String, String>{};
    int dealersAdded = 0;
    int entriesAdded = 0;

    for (final d in dealers) {
      final existingId = codeToId[d.code.trim()];
      if (existingId != null) {
        dealerIdMap[d.id] = existingId;
      } else {
        final newId = 'd_${_idCounter++}';
        dealerIdMap[d.id] = newId;
        codeToId[d.code.trim()] = newId;
        _dealers.add(d.copyWith(id: newId));
        dealersAdded++;
      }
    }

    for (final e in entries) {
      final targetDealerId = dealerIdMap[e.dealerId] ?? e.dealerId;
      _entries.add(e.copyWith(
        id: 'e_${_idCounter++}',
        dealerId: targetDealerId,
      ));
      entriesAdded++;
    }

    _emitDealers();
    _emitEntries();
    return (dealersImported: dealersAdded, entriesImported: entriesAdded);
  }

  @override
  Future<int> deleteEntriesInRange(DateTime start, DateTime end) async {
    final before = _entries.length;
    _entries.removeWhere(
        (e) => !e.date.isBefore(start) && !e.date.isAfter(end));
    _emitEntries();
    return before - _entries.length;
  }

  @override
  Future<void> deleteAllEntries() async {
    _entries.clear();
    _emitEntries();
  }

  @override
  Future<void> deleteAllData() async {
    _entries.clear();
    _dealers.clear();
    _emitDealers();
    _emitEntries();
  }

  void dispose() {
    _dealersController.close();
    _entriesController.close();
  }
}
