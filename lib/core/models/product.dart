import 'package:cloud_firestore/cloud_firestore.dart';

class ProductSizeOption {
  final String label;
  final double price;

  const ProductSizeOption({
    required this.label,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'price': price,
    };
  }

  factory ProductSizeOption.fromMap(Map<String, dynamic> map) {
    return ProductSizeOption(
      label: map['label'] as String? ?? '',
      price: (map['price'] as num? ?? 0.0).toDouble(),
    );
  }
}

class Product {
  final String id;
  final String name;
  final String category;
  final String barcode;
  final double gstRate; // e.g. 0.05 for 5%
  final double stock;
  final List<ProductSizeOption> sizes;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.barcode,
    required this.gstRate,
    required this.stock,
    required this.sizes,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'barcode': barcode,
      'gstRate': gstRate,
      'stock': stock,
      'sizes': sizes.map((s) => s.toMap()).toList(),
    };
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final sizesList = data['sizes'] as List?;
    List<ProductSizeOption> parsedSizes = [];

    if (sizesList != null && sizesList.isNotEmpty) {
      parsedSizes = sizesList
          .map((s) => ProductSizeOption.fromMap(Map<String, dynamic>.from(s)))
          .toList();
    } else {
      final sellingRate = (data['sellingRate'] as num? ?? 0.0).toDouble();
      final unit = data['unit'] as String? ?? 'pcs';
      parsedSizes = [
        ProductSizeOption(label: 'Standard ($unit)', price: sellingRate),
      ];
    }

    return Product(
      id: doc.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      barcode: data['barcode'] as String? ?? '',
      gstRate: (data['gstRate'] as num? ?? 0.0).toDouble(),
      stock: (data['stock'] as num? ?? 0.0).toDouble(),
      sizes: parsedSizes,
    );
  }
}

class InventoryItem {
  final String id;
  final String name;
  final String category;
  final String barcode;
  final String unit;
  double stock;
  final double reorderLevel;
  final double purchaseRate;
  final double sellingRate;
  final String description;
  String? imageUrl;
  String? imageName;

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.barcode,
    required this.unit,
    required this.stock,
    required this.reorderLevel,
    required this.purchaseRate,
    required this.sellingRate,
    required this.description,
    this.imageUrl,
    this.imageName,
  });

  double get stockValue => stock * sellingRate;

  Product toProduct() {
    return Product(
      id: id,
      name: name,
      category: category,
      barcode: barcode,
      gstRate: 0.05,
      stock: stock,
      sizes: [
        ProductSizeOption(label: 'Standard ($unit)', price: sellingRate),
      ],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'barcode': barcode,
      'unit': unit,
      'stock': stock,
      'reorderLevel': reorderLevel,
      'purchaseRate': purchaseRate,
      'sellingRate': sellingRate,
      'description': description,
      'imageUrl': imageUrl,
      'imageName': imageName,
    };
  }

  factory InventoryItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return InventoryItem(
      id: doc.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      barcode: data['barcode'] as String? ?? '',
      unit: data['unit'] as String? ?? 'pcs',
      stock: (data['stock'] as num? ?? 0.0).toDouble(),
      reorderLevel: (data['reorderLevel'] as num? ?? 0.0).toDouble(),
      purchaseRate: (data['purchaseRate'] as num? ?? 0.0).toDouble(),
      sellingRate: (data['sellingRate'] as num? ?? 0.0).toDouble(),
      description: data['description'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      imageName: data['imageName'] as String?,
    );
  }
}
