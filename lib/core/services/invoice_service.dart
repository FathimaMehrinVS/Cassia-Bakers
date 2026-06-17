import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/invoice_record.dart';

class InvoiceService {
  final CollectionReference _invoicesCollection =
      FirebaseFirestore.instance.collection('invoices');
  final CollectionReference _ordersCollection =
      FirebaseFirestore.instance.collection('orders');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads PDF bytes to Firebase Storage and saves metadata in Firestore
  Future<void> saveInvoice(InvoiceRecord record, Uint8List pdfBytes) async {
    // 1. Upload PDF file to Firebase Storage
    final storageRef = _storage.ref().child('invoices/Invoice_${record.billNo}.pdf');
    final uploadTask = await storageRef.putData(
      pdfBytes,
      SettableMetadata(contentType: 'application/pdf'),
    );
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    // 2. Save metadata to Firestore under collection 'invoices' with billNo as doc ID
    final updatedRecord = InvoiceRecord(
      billNo: record.billNo,
      date: record.date,
      time: record.time,
      subtotal: record.subtotal,
      discount: record.discount,
      gst: record.gst,
      total: record.total,
      pdfUrl: downloadUrl,
      createdAt: record.createdAt,
      items: record.items,
    );

    await _invoicesCollection.doc(record.billNo).set(updatedRecord.toFirestore());
  }

  /// Returns a stream of past invoices ordered by creation date descending
  Stream<List<InvoiceRecord>> getInvoicesStream() {
    return _invoicesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => InvoiceRecord.fromFirestore(doc))
          .toList();
    });
  }

  /// Downloads PDF bytes from Firebase Storage URL
  Future<Uint8List> downloadPdf(String pdfUrl) async {
    final ref = _storage.refFromURL(pdfUrl);
    final data = await ref.getData(10 * 1024 * 1024); // max 10MB limit
    if (data == null) {
      throw Exception('Downloaded PDF is empty');
    }
    return data;
  }

  /// Calculates the next unique bill number by checking the maximum bill number
  /// present in both 'orders' and 'invoices' collections.
  Future<String> getNextBillNumber() async {
    // Check orders
    final orderQuery = await _ordersCollection
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    // Check invoices
    final invoiceQuery = await _invoicesCollection
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    int maxBillNum = 1024; // Baseline starting from 1025

    if (orderQuery.docs.isNotEmpty) {
      final billNoStr = orderQuery.docs.first.data() != null
          ? (orderQuery.docs.first.data() as Map<String, dynamic>)['billNo'] as String?
          : null;
      if (billNoStr != null) {
        final val = int.tryParse(billNoStr);
        if (val != null && val > maxBillNum) {
          maxBillNum = val;
        }
      }
    }

    if (invoiceQuery.docs.isNotEmpty) {
      final billNoStr = invoiceQuery.docs.first.id;
      final val = int.tryParse(billNoStr);
      if (val != null && val > maxBillNum) {
        maxBillNum = val;
      }
    }

    return (maxBillNum + 1).toString();
  }
}
