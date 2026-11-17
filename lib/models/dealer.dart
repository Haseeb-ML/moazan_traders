/// Represents a dealer/customer in the Moazan Traders khata system.
class Dealer {
  final String id;
  final String code;
  final String name;
  final DateTime createdAt;

  const Dealer({
    required this.id,
    required this.code,
    required this.name,
    required this.createdAt,
  });

  Dealer copyWith({
    String? id,
    String? code,
    String? name,
    DateTime? createdAt,
  }) {
    return Dealer(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Dealer.fromMap(String id, Map<String, dynamic> map) {
    return Dealer(
      id: id,
      code: (map['code'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      createdAt: DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
