import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerDueTransaction {
  final String id;
  final String description;
  final DateTime date;
  final double amount;
  final bool isPayment; // true if customer paid us, false if customer incurred due
  final String? attachedImageUrl;
  final String? attachedImageName;

  CustomerDueTransaction({
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
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'isPayment': isPayment,
      'attachedImageUrl': attachedImageUrl,
      'attachedImageName': attachedImageName,
    };
  }

  factory CustomerDueTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CustomerDueTransaction(
      id: doc.id,
      description: data['description'] as String? ?? '',
      date: (data['date'] as Timestamp? ?? Timestamp.now()).toDate(),
      amount: (data['amount'] as num? ?? 0.0).toDouble(),
      isPayment: data['isPayment'] as bool? ?? false,
      attachedImageUrl: data['attachedImageUrl'] as String?,
      attachedImageName: data['attachedImageName'] as String?,
    );
  }
}

class CustomerData {
  final String id;
  final String name;
  final String phone;
  final DateTime dateAdded;
  final double netDue; // Cached net outstanding balance

  CustomerData({
    required this.id,
    required this.name,
    required this.phone,
    required this.dateAdded,
    required this.netDue,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'dateAdded': Timestamp.fromDate(dateAdded),
      'netDue': netDue,
    };
  }

  factory CustomerData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CustomerData(
      id: doc.id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      dateAdded: (data['dateAdded'] as Timestamp? ?? Timestamp.now()).toDate(),
      netDue: (data['netDue'] as num? ?? 0.0).toDouble(),
    );
  }
}
