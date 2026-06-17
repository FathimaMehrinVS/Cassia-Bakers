import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/staff.dart';

class StaffService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _staff => _db.collection('staff');

  // Stream all staff
  Stream<List<StaffData>> getStaffStream() {
    return _staff.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => StaffData.fromFirestore(doc))
          .toList(),
    );
  }

  // Stream all staff transactions (for dashboard dues calculation)
  Stream<List<StaffTransaction>> getAllTransactionsStream() {
    return _db.collectionGroup('transactions').snapshots().map(
      (snapshot) => snapshot.docs
          .where((doc) => doc.reference.parent.parent?.parent.path == 'staff')
          .map((doc) => StaffTransaction.fromFirestore(doc))
          .toList(),
    );
  }

  // Add staff member
  Future<void> addStaff(StaffData staffData) async {
    await _staff.doc(staffData.id).set(staffData.toFirestore());
  }

  // Stream transactions of one staff member
  Stream<List<StaffTransaction>> getTransactions(String staffId) {
    return _staff
        .doc(staffId)
        .collection('transactions')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => StaffTransaction.fromFirestore(doc))
              .toList(),
        );
  }

  // Add transaction + update staff balance
  Future<void> addTransaction(String staffId, StaffTransaction tx) async {
    await _staff
        .doc(staffId)
        .collection('transactions')
        .add(tx.toFirestore());

    final delta = tx.isPayment
        ? -tx.amount // we paid them → reduces what we owe
        : tx.amount; // salary credited → increases what we owe

    await _staff.doc(staffId).update({
      'balance': FieldValue.increment(delta),
    });
  }
}
