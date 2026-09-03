class ExpGift {
  final String id;
  final String fromUid;
  final String fromName;
  final String fromUsername;
  final int amount;
  final bool claimed;
  final DateTime? createdAt;

  const ExpGift({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.fromUsername,
    this.amount = 50,
    this.claimed = false,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fromUid': fromUid,
      'fromName': fromName,
      'fromUsername': fromUsername,
      'amount': amount,
      'claimed': claimed,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory ExpGift.fromMap(Map<String, dynamic> map, {String? docId}) {
    return ExpGift(
      id: (docId ?? map['id'] ?? '').toString(),
      fromUid: (map['fromUid'] ?? '').toString(),
      fromName: (map['fromName'] ?? 'A Friend').toString(),
      fromUsername: (map['fromUsername'] ?? '').toString(),
      amount: (map['amount'] as num?)?.toInt() ?? 50,
      claimed: map['claimed'] == true,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }
}
