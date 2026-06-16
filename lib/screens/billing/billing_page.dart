import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/core.dart';

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

class ProductSizeOption {
  final String label;
  final double price;

  const ProductSizeOption({
    required this.label,
    required this.price,
  });
}

class Product {
  final String id;
  final String name;
  final String category;
  final String barcode;
  final double gstRate; // e.g. 0.05 for 5%
  final List<ProductSizeOption> sizes;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.barcode,
    required this.gstRate,
    required this.sizes,
  });
}

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
  // ── Mock Product Catalog ──────────────────────────────────────────────────
  static const List<Product> _catalog = [
    Product(
      id: 'banana_chips',
      name: 'Banana Chips',
      category: 'Chips',
      barcode: '8901234567890',
      gstRate: 0.05,
      sizes: [
        ProductSizeOption(label: '100 gr', price: 70),
        ProductSizeOption(label: '200 gr', price: 140),
        ProductSizeOption(label: '500 gr', price: 350),
      ],
    ),
    Product(
      id: 'potato_chips',
      name: 'Potato Chips',
      category: 'Chips',
      barcode: '8901234567891',
      gstRate: 0.0,
      sizes: [
        ProductSizeOption(label: '500 gr', price: 90),
        ProductSizeOption(label: '1 kg', price: 175),
        ProductSizeOption(label: '2 kg', price: 340),
      ],
    ),
    Product(
      id: 'jackfruit_chips',
      name: 'Jackfruit Chips',
      category: 'Chips',
      barcode: '8901234567892',
      gstRate: 0.0,
      sizes: [
        ProductSizeOption(label: '250 gr', price: 190),
        ProductSizeOption(label: '500 gr', price: 380),
        ProductSizeOption(label: '1 kg', price: 760),
      ],
    ),
    Product(
      id: 'chocolate_cake',
      name: 'Chocolate Cake',
      category: 'Cake',
      barcode: '8901234567893',
      gstRate: 0.18,
      sizes: [
        ProductSizeOption(label: '0.5 kg', price: 400),
        ProductSizeOption(label: '1 kg', price: 750),
      ],
    ),
    Product(
      id: 'vanilla_shake',
      name: 'Vanilla Shake',
      category: 'Shakes',
      barcode: '8901234567894',
      gstRate: 0.05,
      sizes: [
        ProductSizeOption(label: 'Regular', price: 120),
        ProductSizeOption(label: 'Large', price: 180),
      ],
    ),
    Product(
      id: 'mango_juice',
      name: 'Mango Juice',
      category: 'Juice',
      barcode: '8901234567895',
      gstRate: 0.05,
      sizes: [
        ProductSizeOption(label: 'Regular', price: 100),
        ProductSizeOption(label: 'Large', price: 150),
      ],
    ),
  ];

  // ── State Variables ────────────────────────────────────────────────────────
  final Map<String, CartItem> _cart = {}; // key: productId
  String _selectedCategory = 'All';
  String _searchQuery = '';
  double _discount = 0.0;
  double? _gstOverride;
  bool _isReceiptExpanded = false;

  final TextEditingController _searchController = TextEditingController();

  // Temporary billing metadata matching mockup
  final String _billNo = '1025';
  final String _billDate = '27-05-2026';
  final String _billTime = '08:45 PM';

  @override
  void initState() {
    super.initState();
    // Do NOT pre-populate the cart so it starts empty.
    // The cart sheet will only display once at least one item is added.
  }

  @override
  void dispose() {
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
  void _updateQuantity(Product product, ProductSizeOption size, int delta) {
    setState(() {
      final existingItem = _cart[product.id];
      if (existingItem != null) {
        final newQty = existingItem.quantity + delta;
        if (newQty <= 0) {
          _cart.remove(product.id);
        } else {
          existingItem.quantity = newQty;
        }
      } else if (delta > 0) {
        _cart[product.id] = CartItem(
          product: product,
          selectedSize: size,
          quantity: delta,
        );
      }
    });
  }

  void _changeItemSize(Product product, ProductSizeOption newSize) {
    setState(() {
      final existingItem = _cart[product.id];
      if (existingItem != null) {
        _cart[product.id] = CartItem(
          product: product,
          selectedSize: newSize,
          quantity: existingItem.quantity,
        );
      }
    });
  }

  void _addOrIncrementByBarcode(String barcode) {
    final product = _catalog.cast<Product?>().firstWhere(
          (p) => p != null && p.barcode == barcode,
          orElse: () => null,
        );

    if (product != null) {
      // Use default size (second option if available, otherwise first)
      final defaultSize = product.sizes.length > 1 ? product.sizes[1] : product.sizes[0];
      _updateQuantity(product, defaultSize, 1);
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

  // ── Build Method ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Accessibility layout constraints: Adapt sizes for better screen legibility.
    final screenW = MediaQuery.sizeOf(context).width;
    final contentW = screenW > 600 ? 540.0 : screenW;

    // Filter catalog items
    final filteredCatalog = _catalog.where((product) {
      final matchesCategory = _selectedCategory == 'All' || product.category == _selectedCategory;
      final matchesSearch = product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.barcode.contains(_searchQuery);
      return matchesCategory && matchesSearch;
    }).toList();

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
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 26),
            tooltip: 'Notifications',
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.divider),
        ),
      ),

      // ── Main Content Body ──────────────────────────────────────────────────
      body: Center(
        child: SizedBox(
          width: contentW,
          child: Column(
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
                            hintText: 'Item search/Barcode Number',
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
                  children: [
                    'All',
                    'Chips',
                    'Cake',
                    'Shakes',
                    'Juice',
                  ].map((category) {
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
                child: filteredCatalog.isEmpty
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
                          final cartItem = _cart[product.id];
                          final selectedSize = cartItem?.selectedSize ??
                              (product.sizes.length > 1 ? product.sizes[1] : product.sizes[0]);
                          final quantity = cartItem?.quantity ?? 0;

                          return _buildCatalogItemCard(product, selectedSize, quantity);
                        },
                      ),
              ),

              // Leave layout space for the bottom expandable sheet
              if (_cart.isNotEmpty && !_isReceiptExpanded)
                SizedBox(height: 72 + MediaQuery.paddingOf(context).bottom),
            ],
          ),
        ),
      ),

      // ── Bottom Sheet & Actions Integration ────────────────────────────────
      bottomSheet: _cart.isEmpty
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
                        ? _buildExpandedReceiptView(contentW)
                        : _buildCollapsedSummaryView(contentW);
                  },
                ),
              ),
            ),
    );
  }

  // ── Component: Individual Catalog Product Card ─────────────────────────────
  Widget _buildCatalogItemCard(Product product, ProductSizeOption selectedSize, int quantity) {
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
              color: const Color(0xFF8B5CF6), // Premium rounded-purple fill
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                // Standard visual dropdown size selector (padded for ease of use)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<ProductSizeOption>(
                    value: selectedSize,
                    isDense: true,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primary, size: 24),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                    items: product.sizes.map((size) {
                      return DropdownMenuItem<ProductSizeOption>(
                        value: size,
                        child: Text('${size.label} • ₹${size.price.toStringAsFixed(0)}'),
                      );
                    }).toList(),
                    onChanged: (newSize) {
                      if (newSize != null) {
                        if (quantity > 0) {
                          _changeItemSize(product, newSize);
                        } else {
                          // If quantity was 0, auto-add 1 with the selected size
                          _updateQuantity(product, newSize, 1);
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // 3. Accessible Quantity Selector Box: [ - | Qty | + ]
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Decrement button (Large visual target)
                InkWell(
                  onTap: () => _updateQuantity(product, selectedSize, -1),
                  child: Container(
                    width: 36,
                    height: double.infinity,
                    alignment: Alignment.center,
                    child: const Icon(Icons.remove, size: 18, color: AppTheme.textDark),
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                // Vertical divider
                Container(width: 1.5, color: Colors.grey[300]),
                // Increment button (Large visual target)
                InkWell(
                  onTap: () => _updateQuantity(product, selectedSize, 1),
                  child: Container(
                    width: 36,
                    height: double.infinity,
                    alignment: Alignment.center,
                    child: const Icon(Icons.add, size: 18, color: AppTheme.textDark),
                  ),
                ),
              ],
            ),
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
                onPressed: () => setState(() => _isReceiptExpanded = true),
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
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark),
              ),
              Text(
                'Date : $_billDate   Time : $_billTime',
                style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
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
                          item.product.name,
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
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildReceiptActionButton(
                      label: 'Share\nWhatsapp',
                      color: const Color(0xFF007F0E), // WhatsApp Green
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildReceiptActionButton(
                      label: 'Done',
                      color: const Color(0xFF007F80), // Teal
                      onPressed: () {
                        setState(() {
                          _cart.clear();
                          _discount = 0.0;
                          _gstOverride = null;
                          _isReceiptExpanded = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Order saved successfully!', style: TextStyle(fontSize: 15)),
                            backgroundColor: AppTheme.primary,
                          ),
                        );
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

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  final MobileScannerController _controller = MobileScannerController();
  bool _cameraHasError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        height: 560,
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

                    // Scanner Overlay Graphic (Transparent window with pulsing/static indicator line)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                        ),
                        child: Center(
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.primary, width: 3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Stack(
                              children: [
                                // Scanning indicator line
                                Positioned(
                                  top: 96,
                                  left: 10,
                                  right: 10,
                                  child: Container(
                                    height: 3,
                                    color: Colors.red,
                                  ),
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

            const SizedBox(height: 16),

            // Demo/Developer testing controls (Simulation Mode)
            const Text(
              'No physical barcode? Try Simulation:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textMid),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: widget.catalog.take(3).map((product) {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: AppTheme.textDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey[350]!),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onPressed: () {
                    // Close dialog returning mock barcode
                    Navigator.of(context).pop(product.barcode);
                  },
                  child: Text(
                    'Simulate: ${product.name}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
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
