import 'package:cloud_firestore/cloud_firestore.dart';

/// Lightweight metadata for a generated PDF invoice, stored in Firestore.
class InvoiceRecord {
  final String billNo;       // also used as Firestore document ID
  final String date;
  final String time;
  final double subtotal;
  final double discount;
  final double gst;
  final double total;
  final String pdfUrl;       // Firebase Storage download URL
  final DateTime createdAt;
  final List<Map<String, dynamic>> items; // [{name, size, qty, rate, amount}]

  const InvoiceRecord({
    required this.billNo,
    required this.date,
    required this.time,
    required this.subtotal,
    required this.discount,
    required this.gst,
    required this.total,
    required this.pdfUrl,
    required this.createdAt,
    required this.items,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'billNo': billNo,
      'date': date,
      'time': time,
      'subtotal': subtotal,
      'discount': discount,
      'gst': gst,
      'total': total,
      'pdfUrl': pdfUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'items': items,
    };
  }

  factory InvoiceRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return InvoiceRecord(
      billNo: d['billNo'] as String? ?? doc.id,
      date: d['date'] as String? ?? '',
      time: d['time'] as String? ?? '',
      subtotal: (d['subtotal'] as num? ?? 0).toDouble(),
      discount: (d['discount'] as num? ?? 0).toDouble(),
      gst: (d['gst'] as num? ?? 0).toDouble(),
      total: (d['total'] as num? ?? 0).toDouble(),
      pdfUrl: d['pdfUrl'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      items: List<Map<String, dynamic>>.from(
        (d['items'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      ),
    );
  }
}
