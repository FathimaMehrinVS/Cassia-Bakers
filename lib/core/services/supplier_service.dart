import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/supplier.dart';

class SupplierService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _suppliers => _db.collection('suppliers');

  // Stream all suppliers
  Stream<List<SupplierData>> getSuppliers() {
    return _suppliers.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => SupplierData.fromFirestore(doc))
          .toList(),
    );
  }

  // Stream all transactions across all suppliers (for dashboard dues calculation)
  Stream<List<SupplierTransaction>> getAllTransactionsStream() {
    return _db.collectionGroup('transactions').snapshots().map(
      (snapshot) => snapshot.docs
          .where((doc) => doc.reference.parent.parent?.parent.path == 'suppliers')
          .map((doc) => SupplierTransaction.fromFirestore(doc))
          .toList(),
    );
  }

  // Add supplier
  Future<void> addSupplier(SupplierData supplier) async {
    await _suppliers.doc(supplier.id).set(supplier.toFirestore());
  }

  // Update supplier enabled/status
  Future<void> updateSupplierStatus(String supplierId, bool isEnabled, String status) async {
    await _suppliers.doc(supplierId).update({
      'isEnabled': isEnabled,
      'status': status,
    });
  }

  // Stream bills of one supplier
  Stream<List<BillData>> getBills(String supplierId) {
    return _suppliers
        .doc(supplierId)
        .collection('bills')
        .orderBy('date')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BillData.fromFirestore(doc))
              .toList(),
        );
  }

  // Add bill
  Future<void> addBill(String supplierId, BillData bill) async {
    await _suppliers
        .doc(supplierId)
        .collection('bills')
        .add(bill.toFirestore());
  }

  // Stream transactions of one supplier
  Stream<List<SupplierTransaction>> getTransactions(String supplierId) {
    return _suppliers
        .doc(supplierId)
        .collection('transactions')
        .orderBy('date')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SupplierTransaction.fromFirestore(doc))
              .toList(),
        );
  }

  // Add transaction + update supplier netDue
  Future<void> addTransaction(String supplierId, SupplierTransaction tx) async {
    await _suppliers
        .doc(supplierId)
        .collection('transactions')
        .add(tx.toFirestore());

    final delta = tx.isPayment
        ? -tx.amount // we paid them → reduces what we owe
        : tx.amount; // they billed us / credit added → increases what we owe

    await _suppliers.doc(supplierId).update({
      'netDue': FieldValue.increment(delta),
    });
  }
}
