import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer.dart';

class CustomerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _customers => _db.collection('customers');

  // Stream all customers
  Stream<List<CustomerData>> getCustomers() {
    return _customers.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => CustomerData.fromFirestore(doc))
          .toList(),
    );
  }

  // Stream all transactions across all customers
  Stream<List<CustomerDueTransaction>> getAllTransactionsStream() {
    return _db.collectionGroup('transactions').snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => CustomerDueTransaction.fromFirestore(doc))
          .toList(),
    );
  }

  // Add customer
  Future<void> addCustomer(CustomerData customer) async {
    await _customers.add(customer.toFirestore());
  }

  // Stream transactions of one customer
  Stream<List<CustomerDueTransaction>> getTransactions(
    String customerId,
  ) {
    return _customers
        .doc(customerId)
        .collection('transactions')
        .orderBy('date')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CustomerDueTransaction.fromFirestore(doc))
              .toList(),
        );
  }

  // Add transaction + update customer netDue
  Future<void> addTransaction(
    String customerId,
    CustomerDueTransaction tx,
  ) async {
    await _customers
        .doc(customerId)
        .collection('transactions')
        .add(tx.toFirestore());

    final delta = tx.isPayment
        ? -tx.amount // customer paid us → reduce due
        : tx.amount; // customer took credit → increase due

    await _customers.doc(customerId).update({
      'netDue': FieldValue.increment(delta),
    });
  }
}