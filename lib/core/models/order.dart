import 'package:cloud_firestore/cloud_firestore.dart';

class CartItemData {
  final String productId;
  final String name;
  final String selectedSize;
  final int quantity;
  final double price;

  CartItemData({
    required this.productId,
    required this.name,
    required this.selectedSize,
    required this.quantity,
    required this.price,
  });

  double get amount => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'selectedSize': selectedSize,
      'quantity': quantity,
      'price': price,
      'amount': amount,
    };
  }

  factory CartItemData.fromMap(Map<String, dynamic> map) {
    return CartItemData(
      productId: map['productId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      selectedSize: map['selectedSize'] as String? ?? '',
      quantity: (map['quantity'] as num? ?? 1).toInt(),
      price: (map['price'] as num? ?? 0.0).toDouble(),
    );
  }
}

class OrderData {
  final String id;
  final String billNo;
  final DateTime date;
  final double subtotal;
  final double discount;
  final double gstTotal;
  final double total;
  final String? customerId;
  final String? customerName;
  final String paymentMethod;
  final List<CartItemData> items;

  OrderData({
    required this.id,
    required this.billNo,
    required this.date,
    required this.subtotal,
    required this.discount,
    required this.gstTotal,
    required this.total,
    this.customerId,
    this.customerName,
    required this.paymentMethod,
    required this.items,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'billNo': billNo,
      'date': Timestamp.fromDate(date),
      'subtotal': subtotal,
      'discount': discount,
      'gstTotal': gstTotal,
      'total': total,
      'customerId': customerId,
      'customerName': customerName,
      'paymentMethod': paymentMethod,
      'items': items.map((i) => i.toMap()).toList(),
    };
  }

  factory OrderData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return OrderData(
      id: doc.id,
      billNo: data['billNo'] as String? ?? '',
      date: (data['date'] as Timestamp? ?? Timestamp.now()).toDate(),
      subtotal: (data['subtotal'] as num? ?? 0.0).toDouble(),
      discount: (data['discount'] as num? ?? 0.0).toDouble(),
      gstTotal: (data['gstTotal'] as num? ?? 0.0).toDouble(),
      total: (data['total'] as num? ?? 0.0).toDouble(),
      customerId: data['customerId'] as String?,
      customerName: data['customerName'] as String?,
      paymentMethod: data['paymentMethod'] as String? ?? 'Cash',
      items: (data['items'] as List? ?? [])
          .map((i) => CartItemData.fromMap(Map<String, dynamic>.from(i)))
          .toList(),
    );
  }
}
