import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BillItemRow {
  String name;
  double quantity;
  String unit; // e.g. "kg", "gr", "pcs"
  double rate;
  late TextEditingController nameController;

  BillItemRow({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.rate,
  }) {
    nameController = TextEditingController(text: name);
    nameController.addListener(() {
      name = nameController.text;
    });
  }

  double get amount => quantity * rate;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'rate': rate,
    };
  }

  factory BillItemRow.fromMap(Map<String, dynamic> map) {
    return BillItemRow(
      name: map['name'] as String? ?? '',
      quantity: (map['quantity'] as num? ?? 0.0).toDouble(),
      unit: map['unit'] as String? ?? '',
      rate: (map['rate'] as num? ?? 0.0).toDouble(),
    );
  }
}

class BillData {
  final String id;
  final String billNo;
  final DateTime date;
  final double subtotal;
  final double gst;
  final double total;
  final String notes;
  final List<BillItemRow> items;
  final String? attachedImageUrl;
  final String? attachedImageName;

  BillData({
    required this.id,
    required this.billNo,
    required this.date,
    required this.subtotal,
    required this.gst,
    required this.total,
    required this.notes,
    required this.items,
    this.attachedImageUrl,
    this.attachedImageName,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'billNo': billNo,
      'date': Timestamp.fromDate(date),
      'subtotal': subtotal,
      'gst': gst,
      'total': total,
      'notes': notes,
      'items': items.map((i) => i.toMap()).toList(),
      'attachedImageUrl': attachedImageUrl,
      'attachedImageName': attachedImageName,
    };
  }

  factory BillData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final itemsList = data['items'] as List? ?? [];
    return BillData(
      id: doc.id,
      billNo: data['billNo'] as String? ?? '',
      date: (data['date'] as Timestamp? ?? Timestamp.now()).toDate(),
      subtotal: (data['subtotal'] as num? ?? 0.0).toDouble(),
      gst: (data['gst'] as num? ?? 0.0).toDouble(),
      total: (data['total'] as num? ?? 0.0).toDouble(),
      notes: data['notes'] as String? ?? '',
      items: itemsList.map((i) => BillItemRow.fromMap(Map<String, dynamic>.from(i))).toList(),
      attachedImageUrl: data['attachedImageUrl'] as String?,
      attachedImageName: data['attachedImageName'] as String?,
    );
  }
}

class SupplierTransaction {
  final String id;
  final String description;
  final DateTime date;
  final double amount;
  final bool isPayment; // true = payment made (reduces due), false = bill (increases due)
  final String? attachedImageUrl;
  final String? attachedImageName;

  SupplierTransaction({
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

  factory SupplierTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SupplierTransaction(
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

class SupplierData {
  final String id;
  final String name;
  final String phone;
  final String gstin;
  String status; // 'ACTIVE' or 'INACTIVE'
  bool isEnabled;
  final double netDue;
  final List<BillData> bills;
  final List<SupplierTransaction> transactions;

  SupplierData({
    required this.id,
    required this.name,
    required this.phone,
    required this.gstin,
    required this.status,
    required this.isEnabled,
    required this.netDue,
    this.bills = const [],
    this.transactions = const [],
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'gstin': gstin,
      'status': status,
      'isEnabled': isEnabled,
      'netDue': netDue,
    };
  }

  factory SupplierData.fromFirestore(DocumentSnapshot doc, {List<BillData> bills = const [], List<SupplierTransaction> transactions = const []}) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SupplierData(
      id: doc.id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      gstin: data['gstin'] as String? ?? '',
      status: data['status'] as String? ?? 'ACTIVE',
      isEnabled: data['isEnabled'] as bool? ?? true,
      netDue: (data['netDue'] as num? ?? 0.0).toDouble(),
      bills: bills,
      transactions: transactions,
    );
  }
}
