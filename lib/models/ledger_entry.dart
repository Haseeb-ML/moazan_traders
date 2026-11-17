/// Transaction type in the khata ledger.
/// - [debit]: Udhaar / Bill given to dealer (increases dealer's payable balance).
/// - [credit]: Payment / Receiving collected from dealer (decreases balance).
enum EntryType {
  debit,
  credit,
}

/// Represents a single Debit (Bill) or Credit (Payment Received) entry.
class LedgerEntry {
  final String id;
  final String dealerId;
  final String dealerCode;
  final String dealerName;
  final EntryType type;
  final double amount;
  final DateTime date;
  final String billNo;
  final String note;
  final DateTime createdAt;

  const LedgerEntry({
    required this.id,
    required this.dealerId,
    required this.dealerCode,
    required this.dealerName,
    required this.type,
    required this.amount,
    required this.date,
    this.billNo = '',
    this.note = '',
    required this.createdAt,
  });

  LedgerEntry copyWith({
    String? id,
    String? dealerId,
    String? dealerCode,
    String? dealerName,
    EntryType? type,
    double? amount,
    DateTime? date,
    String? billNo,
    String? note,
    DateTime? createdAt,
  }) {
    return LedgerEntry(
      id: id ?? this.id,
      dealerId: dealerId ?? this.dealerId,
      dealerCode: dealerCode ?? this.dealerCode,
      dealerName: dealerName ?? this.dealerName,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      billNo: billNo ?? this.billNo,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dealerId': dealerId,
      'dealerCode': dealerCode,
      'dealerName': dealerName,
      'type': type.name,
      'amount': amount,
      'date': date.toIso8601String(),
      'billNo': billNo,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LedgerEntry.fromMap(String id, Map<String, dynamic> map) {
    final rawType = (map['type'] ?? 'debit').toString();
    final parsedType =
        rawType == EntryType.credit.name ? EntryType.credit : EntryType.debit;
    final rawAmount = map['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '0') ?? 0.0;

    return LedgerEntry(
      id: id,
      dealerId: (map['dealerId'] ?? '').toString(),
      dealerCode: (map['dealerCode'] ?? '').toString(),
      dealerName: (map['dealerName'] ?? '').toString(),
      type: parsedType,
      amount: amount,
      date: DateTime.tryParse((map['date'] ?? '').toString()) ?? DateTime.now(),
      billNo: (map['billNo'] ?? '').toString(),
      note: (map['note'] ?? '').toString(),
      createdAt: DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
