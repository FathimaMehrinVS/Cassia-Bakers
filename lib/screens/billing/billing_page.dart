import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/core.dart';
import '../../core/models/product.dart';
import '../../core/models/order.dart';
import '../../core/models/invoice_record.dart';
import '../../core/services/product_service.dart';
import '../../core/services/order_service.dart';
import '../../core/services/invoice_service.dart';
import '../../widgets/notification_bell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Custom Barcode Icon Widget
// ─────────────────────────────────────────────────────────────────────────────

class BarcodeIcon extends StatelessWidget {
  const BarcodeIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.textDark, width: 2.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(width: 2.5, color: AppTheme.textDark),
          Container(width: 1.2, color: AppTheme.textDark),
          Container(width: 3.5, color: AppTheme.textDark),
          Container(width: 1.2, color: AppTheme.textDark),
          Container(width: 2.5, color: AppTheme.textDark),
          Container(width: 1.8, color: AppTheme.textDark),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Model Classes for Products and Cart Items
// ─────────────────────────────────────────────────────────────────────────────

class CartItem {
  final Product product;
  final ProductSizeOption selectedSize;
  int quantity;

  CartItem({
    required this.product,
    required this.selectedSize,
    required this.quantity,
  });

  double get amount => selectedSize.price * quantity;
}

// ─────────────────────────────────────────────────────────────────────────────
// BillingPage – Accessible POS Interface
// ─────────────────────────────────────────────────────────────────────────────

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  List<Product> _catalog = [];
  bool _isLoadingCatalog = true;

  // ── State Variables ────────────────────────────────────────────────────────
  final Map<String, CartItem> _cart = {}; // key: productId_sizeLabel
  final Map<String, ProductSizeOption> _selectedCatalogSizes = {}; // active visual size choice for catalog dropdowns
  String _selectedCategory = 'All';
  String _searchQuery = '';
  double _discount = 0.0;
  double? _gstOverride;
  bool _isReceiptExpanded = false;

  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Chips',
    'Cake',
    'Shakes',
    'Juice',
  ];
  StreamSubscription<List<String>>? _categoriesSubscription;

  // Dynamic billing metadata matching mockup
  String _billNo = '1025';
  String _billDate = '27-05-2026';
  String _billTime = '08:45 PM';

  String _formatDateOnly(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
  }

  String _formatTimeOnly(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  void initState() {
    super.initState();
    _loadCatalog();

    // Listen to custom categories in Firestore
    _categoriesSubscription = ProductService().getCustomCategoriesStream().listen((customCats) {
      if (mounted) {
        setState(() {
          // Reset categories to default ones first to avoid duplicates
          _categories.clear();
          _categories.addAll([
            'All',
            'Chips',
            'Cake',
            'Shakes',
            'Juice',
          ]);
          // Add custom ones if they don't exist
          for (final cat in customCats) {
            final exists = _categories.any((c) => c.toLowerCase() == cat.toLowerCase());
            if (!exists) {
              _categories.add(cat);
            }
          }
        });
      }
    });
  }

  Future<void> _loadCatalog() async {
    try {
      final catalogData = await ProductService().getCatalog();
      final nextBillNum = await InvoiceService().getNextBillNumber();
      final now = DateTime.now();
      setState(() {
        _catalog = catalogData;
        _billNo = nextBillNum;
        _billDate = _formatDateOnly(now);
        _billTime = _formatTimeOnly(now);
        _isLoadingCatalog = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCatalog = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load product catalog: $e')),
      );
    }
  }

  @override
  void dispose() {
    _categoriesSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ── Calculations ──────────────────────────────────────────────────────────
  double get _subtotal {
    return _cart.values.fold(0.0, (sum, item) => sum + item.amount);
  }

  double get _gstTotal {
    if (_gstOverride != null) return _gstOverride!;
    double gst = 0.0;
    _cart.forEach((id, item) {
      gst += item.amount * item.product.gstRate;
    });
    return double.parse(gst.toStringAsFixed(2));
  }

  double get _total {
    final t = _subtotal - _discount + _gstTotal;
    return t < 0 ? 0.0 : double.parse(t.toStringAsFixed(2));
  }

  int get _totalItemsCount {
    return _cart.values.fold(0, (sum, item) => sum + item.quantity);
  }

  // ── Cart State Mutators ────────────────────────────────────────────────────
  int _getProductCartQuantity(String productId) {
    return _cart.values
        .where((item) => item.product.id == productId)
        .fold(0, (sum, item) => sum + item.quantity);
  }

  void _updateQuantity(Product product, ProductSizeOption size, int delta) {
    setState(() {
      final key = '${product.id}_${size.label}';
      final existingItem = _cart[key];
      if (existingItem != null) {
        final newQty = existingItem.quantity + delta;
        if (newQty <= 0) {
          _cart.remove(key);
        } else {
          final currentProductTotalQty = _getProductCartQuantity(product.id);
          final newProductTotalQty = currentProductTotalQty + delta;
          if (newProductTotalQty > product.stock) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cannot add more. Only ${product.stock.toStringAsFixed(0)} left in stock!'),
                backgroundColor: Colors.red[800],
              ),
            );
          } else {
            existingItem.quantity = newQty;
          }
        }
      } else if (delta > 0) {
        final currentProductTotalQty = _getProductCartQuantity(product.id);
        final newProductTotalQty = currentProductTotalQty + delta;
        if (newProductTotalQty > product.stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot add more. Only ${product.stock.toStringAsFixed(0)} left in stock!'),
              backgroundColor: Colors.red[800],
            ),
          );
        } else {
          _cart[key] = CartItem(
            product: product,
            selectedSize: size,
            quantity: delta,
          );
        }
      }
    });
  }

  void _addOrIncrementByBarcode(String barcode) {
    String cleanBarcode = barcode.trim();
    // Strip Code-39 start/stop asterisks if present
    if (cleanBarcode.startsWith('*') && cleanBarcode.endsWith('*') && cleanBarcode.length > 2) {
      cleanBarcode = cleanBarcode.substring(1, cleanBarcode.length - 1);
    }
    
    final product = _catalog.cast<Product?>().firstWhere(
          (p) => p != null && (p.barcode == cleanBarcode || p.id.toLowerCase() == cleanBarcode.toLowerCase()),
          orElse: () => null,
        );

    if (product != null) {
      // Use default size (second option if available, otherwise first)
      final defaultSize = product.sizes.length > 1 ? product.sizes[1] : product.sizes[0];
      _updateQuantity(product, defaultSize, 1);
      
      // Filter list to only show the scanned item in the interface
      setState(() {
        _selectedCatalogSizes[product.id] = defaultSize;
        _searchQuery = cleanBarcode;
        _searchController.text = cleanBarcode;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${product.name} to bill!',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.positive,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Product with barcode $barcode not found!',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  // ── UI Actions ─────────────────────────────────────────────────────────────
  Future<void> _openBarcodeScanner() async {
    final scannedBarcode = await showDialog<String>(
      context: context,
      builder: (context) => BarcodeScannerDialog(
        catalog: _catalog,
      ),
    );

    if (scannedBarcode != null && scannedBarcode.isNotEmpty) {
      _addOrIncrementByBarcode(scannedBarcode);
    }
  }

  Future<void> _editDiscount() async {
    final controller = TextEditingController(text: _discount.toStringAsFixed(0));
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Enter Discount',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            prefixText: '₹ ',
            border: OutlineInputBorder(),
            hintText: '0',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () {
              final d = double.tryParse(controller.text) ?? 0.0;
              Navigator.of(context).pop(d);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Apply', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _discount = result < 0 ? 0.0 : result;
      });
    }
  }

  Future<void> _editGst() async {
    final controller = TextEditingController(
      text: _gstOverride != null
          ? _gstOverride!.toStringAsFixed(0)
          : _gstTotal.toStringAsFixed(0),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Enter GST Amount',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            prefixText: '₹ ',
            border: OutlineInputBorder(),
            hintText: '0',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(-1.0); // Reset override
            },
            child: const Text('Reset Auto', style: TextStyle(fontSize: 16, color: Colors.orange)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () {
              final d = double.tryParse(controller.text) ?? 0.0;
              Navigator.of(context).pop(d);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Apply', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        if (result < 0) {
          _gstOverride = null;
        } else {
          _gstOverride = result;
        }
      });
    }
  }

  Widget _buildSideReceiptView() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Receipt header layout (Cassia Bakers)
            const Center(
              child: Column(
                children: [
                  Text(
                    'Cassia Bakers',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'The Art of Baking - Aluva, Kerala',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMid),
                  ),
                ],
               ),
            ),
            const SizedBox(height: 12),
            // Metadata rows
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bill No : $_billNo',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Date : $_billDate',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textDark),
                    ),
                    Text(
                      'Time : $_billTime',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textDark),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(thickness: 1.5, color: Colors.black87),
            // Receipt Items Table
            Expanded(
              child: _cart.isEmpty
                  ? const Center(
                      child: Text(
                        'Cart is empty',
                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    )
                  : ListView(
                      children: [
                        // Table Header
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'Item',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Qty',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Rate',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Amt',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                                ),
                              ),
                              SizedBox(width: 28),
                            ],
                          ),
                        ),
                        const Divider(thickness: 1, color: AppTheme.divider),
                        ..._cart.values.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    '${item.product.name} (${item.selectedSize.label})',
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textDark, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${item.quantity}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.selectedSize.price.toStringAsFixed(0),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.amount.toStringAsFixed(0),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textDark, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.delete_forever_outlined, color: Colors.red[800], size: 18),
                                  onPressed: () {
                                    setState(() {
                                      final key = '${item.product.id}_${item.selectedSize.label}';
                                      _cart.remove(key);
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
            ),
            const Divider(thickness: 1.5, color: Colors.black87),
            // Calculations Summary
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal', style: TextStyle(fontSize: 13, color: AppTheme.textDark)),
                  Text(_subtotal.toStringAsFixed(0), style: const TextStyle(fontSize: 13, color: AppTheme.textDark)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('Discount', style: TextStyle(fontSize: 13, color: AppTheme.textDark)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _editDiscount,
                        child: const Icon(Icons.edit, size: 14, color: Colors.purple),
                      ),
                    ],
                  ),
                  Text(_discount.toStringAsFixed(0), style: const TextStyle(fontSize: 13, color: AppTheme.textDark)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('GST (5%)', style: TextStyle(fontSize: 13, color: AppTheme.textDark)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _editGst,
                        child: const Icon(Icons.edit, size: 14, color: Colors.purple),
                      ),
                    ],
                  ),
                  Text(_gstTotal.toStringAsFixed(0), style: const TextStyle(fontSize: 13, color: AppTheme.textDark)),
                ],
              ),
            ),
            const Divider(thickness: 1.5, color: Colors.black87),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                  ),
                  Text(
                    _total.toStringAsFixed(0),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Actions
            Row(
              children: [
                Expanded(
                  child: _buildReceiptActionButton(
                    label: 'Print',
                    color: const Color(0xFFA22204),
                    onPressed: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(child: CircularProgressIndicator()),
                      );
                      try {
                        final pdfBytes = await _generateInvoicePdf();
                        if (mounted) Navigator.of(context).pop();
                        await Printing.layoutPdf(
                          onLayout: (PdfPageFormat format) async => pdfBytes,
                          name: 'Invoice_$_billNo',
                        );
                      } catch (e) {
                        if (mounted) Navigator.of(context).pop();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to print: $e')),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildReceiptActionButton(
                    label: 'Share\nWhatsapp',
                    color: const Color(0xFF007F0E),
                    onPressed: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(child: CircularProgressIndicator()),
                      );
                      try {
                        final pdfBytes = await _generateInvoicePdf();
                        if (mounted) Navigator.of(context).pop();
                        await Printing.sharePdf(
                          bytes: pdfBytes,
                          filename: 'invoice_$_billNo.pdf',
                        );
                      } catch (e) {
                        if (mounted) Navigator.of(context).pop();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to share: $e')),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildReceiptActionButton(
                    label: 'Done',
                    color: const Color(0xFF007F80),
                    onPressed: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(child: CircularProgressIndicator()),
                      );
                      try {
                        final List<CartItemData> orderItems = _cart.values.map((item) {
                          return CartItemData(
                            productId: item.product.id,
                            name: item.product.name,
                            selectedSize: item.selectedSize.label,
                            quantity: item.quantity,
                            price: item.selectedSize.price,
                          );
                        }).toList();

                        final newOrder = OrderData(
                          id: 'order_${DateTime.now().millisecondsSinceEpoch}',
                          billNo: _billNo,
                          date: DateTime.now(),
                          subtotal: _subtotal,
                          discount: _discount,
                          gstTotal: _gstTotal,
                          total: _total,
                          paymentMethod: 'Cash',
                          items: orderItems,
                        );

                        await OrderService().createOrder(newOrder);

                        bool invoiceSaved = true;
                        try {
                          await _generateAndSaveInvoice();
                        } catch (e) {
                          invoiceSaved = false;
                        }

                        final nextBill = await InvoiceService().getNextBillNumber();
                        if (mounted) Navigator.of(context).pop();

                        setState(() {
                          _cart.clear();
                          _discount = 0.0;
                          _gstOverride = null;
                          _billNo = nextBill;
                          final now = DateTime.now();
                          _billDate = _formatDateOnly(now);
                          _billTime = _formatTimeOnly(now);
                        });

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              invoiceSaved
                                  ? 'Order saved successfully!'
                                  : 'Order saved, but PDF storage error.',
                            ),
                            backgroundColor: invoiceSaved ? AppTheme.primary : Colors.orange[800],
                          ),
                        );
                      } catch (e) {
                        if (mounted) Navigator.of(context).pop();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Checkout failed: $e')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Build Method ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Accessibility layout constraints: Adapt sizes for better screen legibility.
    final screenW = MediaQuery.sizeOf(context).width;
    final isSplit = screenW >= 850;

    // Filter catalog items
    final filteredCatalog = _catalog.where((product) {
      final matchesCategory = _selectedCategory == 'All' || product.category == _selectedCategory;
      final query = _searchQuery.toLowerCase();
      final matchesSearch = product.name.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query) ||
          product.id.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();

    final catalogColumn = Column(
      children: [
        // 1. Search Bar & Barcode button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 52, // Bounded target height (Age 40-60 friendly)
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 16, color: AppTheme.textDark),
                    decoration: InputDecoration(
                      hintText: 'Search Name, Barcode, or Product ID',
                      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 15),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 24),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Large visual barcode icon button (min 48px hit area)
              InkWell(
                onTap: _openBarcodeScanner,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const BarcodeIcon(),
                ),
              ),
            ],
          ),
        ),

        // 2. Horizontally scrollable Category Capsules (Generous Padding)
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _categories.map((category) {
              final isSelected = _selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  onTap: () => setState(() => _selectedCategory = category),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // 3. Scrollable Catalog list
        Expanded(
          child: _isLoadingCatalog
              ? const Center(child: CircularProgressIndicator())
              : filteredCatalog.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'No items match your search.',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredCatalog.length,
                      itemBuilder: (context, index) {
                        final product = filteredCatalog[index];
                        // Read active sizes / quantities from cart
                        final selectedSize = _selectedCatalogSizes[product.id] ??
                            (product.sizes.length > 1 ? product.sizes[1] : product.sizes[0]);
                        final key = '${product.id}_${selectedSize.label}';
                        final cartItem = _cart[key];
                        final quantity = cartItem?.quantity ?? 0;

                        return _buildCatalogItemCard(product, selectedSize, quantity);
                      },
                    ),
        ),

        // Leave layout space for the bottom expandable sheet
        if (!isSplit && _cart.isNotEmpty && !_isReceiptExpanded)
          SizedBox(height: 72 + MediaQuery.paddingOf(context).bottom),
      ],
    );

    Widget bodyWidget;
    if (isSplit) {
      bodyWidget = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: catalogColumn,
          ),
          const VerticalDivider(width: 1, thickness: 1, color: AppTheme.divider),
          Expanded(
            flex: 2,
            child: _buildSideReceiptView(),
          ),
        ],
      );
    } else {
      bodyWidget = Center(
        child: SizedBox(
          width: screenW > 600 ? 540.0 : screenW,
          child: catalogColumn,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,

      // ── AppBar ─────────────────────────────────────────────────────────────
      appBar: AppBar(
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 22),
          tooltip: 'Back to Home',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Billing (POS)'),
        actions: [
          const NotificationBell(size: 26),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.divider),
        ),
      ),

      // ── Main Content Body ──────────────────────────────────────────────────
      body: bodyWidget,

      // ── Bottom Sheet & Actions Integration ────────────────────────────────
      bottomSheet: isSplit || _cart.isEmpty
          ? null
          : AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.fastOutSlowIn,
              height: _isReceiptExpanded
                  ? MediaQuery.sizeOf(context).height * 0.72
                  : 76 + MediaQuery.paddingOf(context).bottom,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isExpanded = constraints.maxHeight > 240;
                    return isExpanded
                        ? _buildExpandedReceiptView(screenW > 600 ? 540.0 : screenW)
                        : _buildCollapsedSummaryView(screenW > 600 ? 540.0 : screenW);
                  },
                ),
              ),
            ),
    );
  }

  // ── Component: Individual Catalog Product Card ─────────────────────────────
  Widget _buildCatalogItemCard(Product product, ProductSizeOption selectedSize, int quantity) {
    final isOutOfStock = product.stock <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // 1. JPG Placeholder Image Block
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isOutOfStock ? Colors.grey : const Color(0xFF8B5CF6), // Premium rounded-purple fill
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text(
              'JPG',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // 2. Name & Dropdown Choice Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isOutOfStock ? Colors.grey[500] : AppTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Standard visual dropdown size selector (padded for ease of use)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<ProductSizeOption>(
                    value: selectedSize,
                    isExpanded: true,
                    isDense: true,
                    underline: const SizedBox(),
                    icon: Icon(Icons.arrow_drop_down, color: isOutOfStock ? Colors.grey : AppTheme.primary, size: 20),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOutOfStock ? Colors.grey : AppTheme.textDark,
                    ),
                    items: product.sizes.map((size) {
                      return DropdownMenuItem<ProductSizeOption>(
                        value: size,
                        child: Text('${size.label} • ₹${size.price.toStringAsFixed(0)}'),
                      );
                    }).toList(),
                    onChanged: isOutOfStock
                        ? null
                        : (newSize) {
                            if (newSize != null) {
                              setState(() {
                                _selectedCatalogSizes[product.id] = newSize;
                              });
                            }
                          },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // 3. Right Column: Stock Info & Quantity Selector Box
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stock Info (OUT OF STOCK or Stock count)
              if (isOutOfStock)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Text(
                    'OUT OF STOCK',
                    style: TextStyle(color: Colors.red[800], fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Text(
                  'Stock: ${product.stock.toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 6),
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: isOutOfStock ? Colors.grey[200] : Colors.white,
                  border: Border.all(color: Colors.grey[300]!, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Decrement button (Large visual target)
                    InkWell(
                      onTap: isOutOfStock ? null : () => _updateQuantity(product, selectedSize, -1),
                      child: Container(
                        width: 36,
                        height: double.infinity,
                        alignment: Alignment.center,
                        child: Icon(Icons.remove, size: 18, color: isOutOfStock ? Colors.grey : AppTheme.textDark),
                      ),
                    ),
                    // Vertical divider
                    Container(width: 1.5, color: Colors.grey[300]),
                    // Quantity count text
                    Container(
                      width: 32,
                      alignment: Alignment.center,
                      child: Text(
                        '$quantity',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isOutOfStock ? Colors.grey : AppTheme.textDark,
                        ),
                      ),
                    ),
                    // Vertical divider
                    Container(width: 1.5, color: Colors.grey[300]),
                    // Increment button (Large visual target)
                    InkWell(
                      onTap: isOutOfStock ? null : () => _updateQuantity(product, selectedSize, 1),
                      child: Container(
                        width: 36,
                        height: double.infinity,
                        alignment: Alignment.center,
                        child: Icon(Icons.add, size: 18, color: isOutOfStock ? Colors.grey : AppTheme.textDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Component: Collapsed Summary Bar (Floating above BottomNav) ───────────
  Widget _buildCollapsedSummaryView(double maxWidth) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
      child: Center(
        child: SizedBox(
          width: maxWidth,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Summary Info
              Row(
                children: [
                  const Icon(Icons.shopping_cart, color: AppTheme.primary, size: 26),
                  const SizedBox(width: 12),
                  Text(
                    '$_totalItemsCount Items selected  •  Total: ₹${_total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              // Expand button (Large touch target)
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up, size: 32, color: AppTheme.primary),
                tooltip: 'Show Receipt details',
                onPressed: () {
                  final now = DateTime.now();
                  setState(() {
                    _billDate = _formatDateOnly(now);
                    _billTime = _formatTimeOnly(now);
                    _isReceiptExpanded = true;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Component: Sliding Expanded Receipt View (Full Details) ────────────────
  Widget _buildExpandedReceiptView(double maxWidth) {
    return Column(
      children: [
        // Drag Handle / Divider Header
        GestureDetector(
          onTap: () => setState(() => _isReceiptExpanded = false),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),

        // Receipt header layout (Cassia Bakers)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Stack(
            children: [
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Cassia Bakers',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'The Art of Baking',
                      style: TextStyle(fontSize: 14, color: AppTheme.textMid),
                    ),
                    const Text(
                      'Aluva, Kerala',
                      style: TextStyle(fontSize: 14, color: AppTheme.textMid),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, size: 32, color: AppTheme.primary),
                  tooltip: 'Collapse Receipt',
                  onPressed: () => setState(() => _isReceiptExpanded = false),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Metadata rows
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bill No : $_billNo',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textDark),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Date : $_billDate',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textDark),
                  ),
                  Text(
                    'Time : $_billTime',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textDark),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Divider(thickness: 1.5, color: Colors.black87),
        ),

        // Receipt Items Table
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
               // Table Header
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Item',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Qty',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Rate',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Amt',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                      ),
                    ),
                    SizedBox(width: 28), // Space for delete button
                  ],
                ),
              ),
              const Divider(thickness: 1, color: AppTheme.divider),

              // Cart item rows
              ..._cart.values.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          '${item.product.name} (${item.selectedSize.label})',
                          style: const TextStyle(fontSize: 14, color: AppTheme.textDark, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${item.quantity}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.selectedSize.price.toStringAsFixed(0),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.amount.toStringAsFixed(0),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 14, color: AppTheme.textDark, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.delete_forever_outlined, color: Colors.red[800], size: 20),
                        onPressed: () {
                          setState(() {
                            final key = '${item.product.id}_${item.selectedSize.label}';
                            _cart.remove(key);
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      ),
                    ],
                  ),
                );
              }),

              const Divider(thickness: 1.5, color: Colors.black87),

              // Calculations Summary
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal', style: TextStyle(fontSize: 14, color: AppTheme.textDark)),
                    Text(_subtotal.toStringAsFixed(0), style: const TextStyle(fontSize: 14, color: AppTheme.textDark)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('Discount', style: TextStyle(fontSize: 14, color: AppTheme.textDark)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _editDiscount,
                          child: const Icon(Icons.edit, size: 16, color: Colors.purple),
                        ),
                      ],
                    ),
                    Text(_discount.toStringAsFixed(0), style: const TextStyle(fontSize: 14, color: AppTheme.textDark)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('GST (5%)', style: TextStyle(fontSize: 14, color: AppTheme.textDark)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _editGst,
                          child: const Icon(Icons.edit, size: 16, color: Colors.purple),
                        ),
                      ],
                    ),
                    Text(_gstTotal.toStringAsFixed(0), style: const TextStyle(fontSize: 14, color: AppTheme.textDark)),
                  ],
                ),
              ),

              const Divider(thickness: 1.5, color: Colors.black87),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textDark),
                    ),
                    Text(
                      _total.toStringAsFixed(0),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textDark),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons: Print, Share Whatsapp, Done
              Row(
                children: [
                  Expanded(
                    child: _buildReceiptActionButton(
                      label: 'Print',
                      color: const Color(0xFFA22204), // Reddish-brown
                      onPressed: () async {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(child: CircularProgressIndicator()),
                        );
                        try {
                          final pdfBytes = await _generateInvoicePdf();
                          if (mounted) Navigator.of(context).pop();
                          await Printing.layoutPdf(
                            onLayout: (PdfPageFormat format) async => pdfBytes,
                            name: 'Invoice_$_billNo',
                          );
                        } catch (e) {
                          if (mounted) Navigator.of(context).pop();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to print: $e')),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildReceiptActionButton(
                      label: 'Share\nWhatsapp',
                      color: const Color(0xFF007F0E), // WhatsApp Green
                      onPressed: () async {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(child: CircularProgressIndicator()),
                        );
                        try {
                          final pdfBytes = await _generateInvoicePdf();
                          if (mounted) Navigator.of(context).pop();
                          await Printing.sharePdf(
                            bytes: pdfBytes,
                            filename: 'invoice_$_billNo.pdf',
                          );
                        } catch (e) {
                          if (mounted) Navigator.of(context).pop();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to share: $e')),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildReceiptActionButton(
                      label: 'Done',
                      color: const Color(0xFF007F80), // Teal
                      onPressed: () async {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(child: CircularProgressIndicator()),
                        );

                        try {
                          final List<CartItemData> orderItems = _cart.values.map((item) {
                            return CartItemData(
                              productId: item.product.id,
                              name: item.product.name,
                              selectedSize: item.selectedSize.label,
                              quantity: item.quantity,
                              price: item.selectedSize.price,
                            );
                          }).toList();

                          final newOrder = OrderData(
                            id: 'order_${DateTime.now().millisecondsSinceEpoch}',
                            billNo: _billNo,
                            date: DateTime.now(),
                            subtotal: _subtotal,
                            discount: _discount,
                            gstTotal: _gstTotal,
                            total: _total,
                            paymentMethod: 'Cash',
                            items: orderItems,
                          );

                          // Create order in Firestore (which atomically decrements stock)
                          await OrderService().createOrder(newOrder);

                          bool invoiceSaved = true;
                          // Generate and save PDF metadata inside 'invoices' Firestore collection
                          try {
                            await _generateAndSaveInvoice();
                          } catch (e) {
                            invoiceSaved = false;
                            debugPrint('Failed to upload/save invoice PDF: $e');
                          }

                          // Generate next unique bill number
                          final nextBill = await InvoiceService().getNextBillNumber();

                          if (mounted) Navigator.of(context).pop(); // close loading indicator

                          setState(() {
                            _cart.clear();
                            _discount = 0.0;
                            _gstOverride = null;
                            _isReceiptExpanded = false;
                            _billNo = nextBill;
                            final now = DateTime.now();
                            _billDate = _formatDateOnly(now);
                            _billTime = _formatTimeOnly(now);
                          });

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                invoiceSaved
                                    ? 'Order saved and stock updated successfully!'
                                    : 'Order saved successfully, but invoice PDF failed to upload (Firebase Storage error).',
                                style: const TextStyle(fontSize: 15),
                              ),
                              backgroundColor: invoiceSaved ? AppTheme.primary : Colors.orange[800],
                            ),
                          );
                        } catch (e) {
                          if (mounted) Navigator.of(context).pop(); // close loading indicator
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Checkout failed: $e', style: const TextStyle(fontSize: 15)),
                              backgroundColor: Colors.red[800],
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptActionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 52, // Bounded target height (Age 40-60 friendly)
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.1,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _generateAndSaveInvoice() async {
    final pdfBytes = await _generateInvoicePdf();
    final List<Map<String, dynamic>> itemsList = _cart.values.map((item) {
      return {
        'name': item.product.name,
        'size': item.selectedSize.label,
        'quantity': item.quantity,
        'rate': item.selectedSize.price,
        'amount': item.amount,
      };
    }).toList();

    final record = InvoiceRecord(
      billNo: _billNo,
      date: _billDate,
      time: _billTime,
      subtotal: _subtotal,
      discount: _discount,
      gst: _gstTotal,
      total: _total,
      pdfUrl: '',
      createdAt: DateTime.now(),
      items: itemsList,
    );

    await InvoiceService().saveInvoice(record, pdfBytes);
    return pdfBytes;
  }

  Future<Uint8List> _generateInvoicePdf() async {
    final pdf = pw.Document();
    final List<Map<String, dynamic>> pdfItems = _cart.values.map((item) {
      return {
        'name': item.product.name,
        'size': item.selectedSize.label,
        'quantity': item.quantity,
        'rate': item.selectedSize.price,
        'amount': item.amount,
      };
    }).toList();

    // Load the real Cassia Bakers logo from assets
    final logoData = await rootBundle.load('assets/images/cassia_logo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Container(
              width: 390,
              constraints: const pw.BoxConstraints(minHeight: 540),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 2.2),
              ),
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Real Cassia Bakers logo image
                      pw.Image(
                        logoImage,
                        width: 72,
                        height: 72,
                        fit: pw.BoxFit.contain,
                      ),
                      pw.SizedBox(width: 16),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              'Cassia Bakers',
                              style: pw.TextStyle(
                                fontSize: 26,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'The Art of Baking',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontStyle: pw.FontStyle.italic,
                                color: PdfColors.black,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Aluva , Kerala',
                              style: const pw.TextStyle(
                                fontSize: 11,
                                color: PdfColors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 72), // balance for centering
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  // ── Metadata ─────────────────────────────────────────────
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Bill No: $_billNo', style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                      pw.Text('Date: $_billDate', style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                      pw.Text('Time : $_billTime', style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 2.0, color: PdfColors.black),
                  pw.SizedBox(height: 6),
                  // ── Items Table ───────────────────────────────────────────
                  pw.Table(
                    columnWidths: const {
                      0: pw.FlexColumnWidth(3.2),
                      1: pw.FlexColumnWidth(1.0),
                      2: pw.FlexColumnWidth(1.2),
                      3: pw.FlexColumnWidth(1.2),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                          ),
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.black)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.black)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.black)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Text('Amt', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.black)),
                          ),
                        ],
                      ),
                      ...pdfItems.map((item) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6),
                            child: pw.Text('${item['name']} (${item['size']})', style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6),
                            child: pw.Text('${item['quantity']}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6),
                            child: pw.Text(item['rate'].toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6),
                            child: pw.Text(item['amount'].toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                          ),
                        ],
                      )),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 2.0, color: PdfColors.black),
                  pw.SizedBox(height: 8),
                  // ── Totals ────────────────────────────────────────────────
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Subtotal', style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                        pw.Text(_subtotal.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Discount', style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                        pw.Text(_discount.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('GST', style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                        pw.Text(_gstTotal.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(thickness: 2.0, color: PdfColors.black),
                  pw.SizedBox(height: 8),
                  // ── TOTAL ─────────────────────────────────────────────────
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'TOTAL',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.black),
                        ),
                        pw.Text(
                          _total.toStringAsFixed(0),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.black),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 1.2, color: PdfColors.black),
                  pw.SizedBox(height: 8),
                  // ── Thank You Footer ──────────────────────────────────────
                  pw.Center(
                    child: pw.Text(
                      'Thank you for choosing Cassia Bakers!',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColor.fromHex('#C8960C'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return pdf.save();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BarcodeScannerDialog – Dialog supporting live camera and simulations
// ─────────────────────────────────────────────────────────────────────────────

class BarcodeScannerDialog extends StatefulWidget {
  final List<Product> catalog;
  const BarcodeScannerDialog({super.key, required this.catalog});

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  bool _cameraHasError = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        height: 420,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Scan Barcode / QR Code',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 26, color: AppTheme.textDark),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),

            // Camera Area / Preview
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    if (!_cameraHasError)
                      MobileScanner(
                        controller: _controller,
                        errorBuilder: (context, error) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && !_cameraHasError) {
                              setState(() => _cameraHasError = true);
                            }
                          });
                          return _buildCameraErrorPlaceholder();
                        },
                        onDetect: (capture) {
                          final List<Barcode> barcodes = capture.barcodes;
                          if (barcodes.isNotEmpty) {
                            final code = barcodes.first.rawValue;
                            if (code != null && code.isNotEmpty) {
                              Navigator.of(context).pop(code);
                            }
                          }
                        },
                      )
                    else
                      _buildCameraErrorPlaceholder(),

                    // Scanner Overlay Graphic (Transparent window with dynamic green laser sweep)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        child: Center(
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.greenAccent, width: 2.5),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.greenAccent.withValues(alpha: 0.15),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                AnimatedBuilder(
                                  animation: _animation,
                                  builder: (context, child) {
                                    return Positioned(
                                      top: _animation.value * 180, // Sweep from 0 to 180px in a 220px box
                                      left: 0,
                                      right: 0,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Glowing green sweep laser line
                                          Container(
                                            height: 3,
                                            decoration: BoxDecoration(
                                              color: Colors.greenAccent,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.greenAccent.withValues(alpha: 0.9),
                                                  blurRadius: 8,
                                                  spreadRadius: 1.5,
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Soft green gradient trailing shade
                                          Container(
                                            height: 40,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.greenAccent.withValues(alpha: 0.3),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildCameraErrorPlaceholder() {
    return Container(
      color: Colors.grey[900],
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, color: Colors.grey, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Camera initialization failed or permissions denied.\n(Common in desktop web simulations)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the simulation triggers below to test the barcode flow.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.amber[300], fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
