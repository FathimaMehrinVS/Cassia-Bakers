import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/product.dart';

class ProductService {
  final CollectionReference _productsCollection =
      FirebaseFirestore.instance.collection('products');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 1. Listen to all products as a stream (real-time updates)
  Stream<List<InventoryItem>> getInventoryItemsStream() {
    return _productsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => InventoryItem.fromFirestore(doc)).toList();
    });
  }

  // 2. Fetch catalog for billing (one-time fetch)
  Future<List<Product>> getCatalog() async {
    final query = await _productsCollection.get();
    return query.docs.map((doc) => Product.fromFirestore(doc)).toList();
  }

  // 3. Add or update a product (inventory view)
  Future<void> saveProduct(InventoryItem item) async {
    // If updating, merge it; if new, set it using id as doc id
    await _productsCollection.doc(item.id).set(
          item.toFirestore(),
          SetOptions(merge: true),
        );
  }

  // 4. Delete a product
  Future<void> deleteProduct(String productId) async {
    await _productsCollection.doc(productId).delete();
  }

  // 5. Upload image bytes to Firebase Storage & get download URL
  Future<String?> uploadProductImage(String fileName, Uint8List fileBytes) async {
    try {
      final ref = _storage.ref().child('products/$fileName');
      final uploadTask = await ref.putData(fileBytes);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Firebase Storage upload failed: $e");
      return null;
    }
  }
}
