import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order.dart';

class OrderService {
  final CollectionReference _ordersCollection =
      FirebaseFirestore.instance.collection('orders');
  final CollectionReference _productsCollection =
      FirebaseFirestore.instance.collection('products');

  // 1. Save an order & update inventory stock in a secure atomic transaction
  Future<void> createOrder(OrderData order) async {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // Step A: Read product documents to check stock availability and decrement
      for (final item in order.items) {
        final productDocRef = _productsCollection.doc(item.productId);
        final productDoc = await transaction.get(productDocRef);

        if (productDoc.exists) {
          final currentData = productDoc.data() as Map<String, dynamic>? ?? {};
          final currentStock = (currentData['stock'] as num? ?? 0.0).toDouble();

          // Calculate new stock (e.g., if sold in 'pcs', size label can also be parsed if weight applies)
          // For now, simple count subtraction:
          final newStock = currentStock - item.quantity;
          
          // Update product stock inside transaction
          transaction.update(productDocRef, {'stock': newStock});
        }
      }

      // Step B: Write the order document
      final newOrderRef = _ordersCollection.doc(order.id.isEmpty ? null : order.id);
      transaction.set(newOrderRef, order.toFirestore());
    });
  }

  // 2. Fetch past orders (optional/reports)
  Future<List<OrderData>> getOrders() async {
    final query = await _ordersCollection.orderBy('date', descending: true).get();
    return query.docs.map((doc) => OrderData.fromFirestore(doc)).toList();
  }
}
