import 'package:cloud_firestore/cloud_firestore.dart';

class StaffTransaction {
  final String id;
  final String description;
  final String date;
  final double amount;
  final bool isPayment; // true if paid (we paid them), false if salary credited (we owe them)
  final String? attachedImageUrl;
  final String? attachedImageName;

  StaffTransaction({
    required this.id,
    required this.description,
    required this.date,
    required this.amount,
    required this.isPayment,
    this.attachedImageUrl,
    this.attachedImageName,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'description': description,
      'date': date,
      'amount': amount,
      'isPayment': isPayment,
      'attachedImageUrl': attachedImageUrl,
      'attachedImageName': attachedImageName,
    };
  }

  factory StaffTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return StaffTransaction(
      id: doc.id,
      description: data['description'] as String? ?? '',
      date: data['date'] as String? ?? '',
      amount: (data['amount'] as num? ?? 0.0).toDouble(),
      isPayment: data['isPayment'] as bool? ?? false,
      attachedImageUrl: data['attachedImageUrl'] as String?,
      attachedImageName: data['attachedImageName'] as String?,
    );
  }
}

class StaffData {
  final String id;
  final String name;
  final String phone;
  final String dateAdded;
  final double balance; // cached outstanding balance
  final List<StaffTransaction> transactions;

  StaffData({
    required this.id,
    required this.name,
    required this.phone,
    required this.dateAdded,
    required this.balance,
    this.transactions = const [],
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'dateAdded': dateAdded,
      'balance': balance,
    };
  }

  factory StaffData.fromFirestore(DocumentSnapshot doc, {List<StaffTransaction> transactions = const []}) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return StaffData(
      id: doc.id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      dateAdded: data['dateAdded'] as String? ?? '',
      balance: (data['balance'] as num? ?? 0.0).toDouble(),
      transactions: transactions,
    );
  }
}
