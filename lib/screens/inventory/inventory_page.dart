import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/core.dart';
import '../../core/models/product.dart';
import '../../core/services/product_service.dart';
import '../billing/billing_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InventoryPage Widget
// ─────────────────────────────────────────────────────────────────────────────

class InventoryPage extends StatefulWidget {
  final bool autoShowAddItemForm;
  final String initialStockStatusFilter;

  const InventoryPage({
    super.key,
    this.autoShowAddItemForm = false,
    this.initialStockStatusFilter = 'ALL',
  });

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final ScrollController _scrollController = ScrollController();

  // ── Categories State ───────────────────────────────────────────────────────
  final List<String> _categories = [
    'All',
    'Cakes',
    'Pastries',
    'Bread',
    'Chips',
    'Dry Fruits',
    'Biscuits',
    'Beverages',
    'Packaging',
  ];

  String _selectedCategoryFilter = 'All';
  String _searchQuery = '';
  String _selectedStockStatusFilter = 'ALL'; // 'ALL', 'LOW_STOCK', 'OUT_OF_STOCK'


  // ── Inventory Items State ──────────────────────────────────────────────────
  List<InventoryItem> _items = [];
  String? _attachedImageUrl;
  String? _editingOriginalProductId; // Track original ID during edits
  late final Stream<List<InventoryItem>> _inventoryStream;
  StreamSubscription<List<String>>? _categoriesSubscription;

  // ── ADD CATEGORY Form State ────────────────────────────────────────────────
  bool _showAddCategoryForm = false;
  final _newCategoryController = TextEditingController();

  // ── ADD ITEM Form State ────────────────────────────────────────────────────
  bool _showAddItemForm = false;
  final _productIdController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _stockController = TextEditingController();
  final _reorderController = TextEditingController();
  final _purchaseRateController = TextEditingController();
  final _sellingRateController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();

  String _selectedItemCategory = 'Cakes';
  String _selectedItemUnit = 'pcs';

  Uint8List? _attachedImageBytes;
  String? _attachedImageName;

  bool _doesProductIdExist(String id) {
    if (id.isEmpty) return false;
    if (_editingOriginalProductId != null && id.toLowerCase() == _editingOriginalProductId!.toLowerCase()) {
      return false;
    }
    return _items.any((item) => item.id.toLowerCase() == id.toLowerCase());
  }

  @override
  void initState() {
    super.initState();
    _selectedStockStatusFilter = widget.initialStockStatusFilter;
    _inventoryStream = ProductService().getInventoryItemsStream();
    
    // Listen to custom categories in Firestore
    _categoriesSubscription = ProductService().getCustomCategoriesStream().listen((customCats) {
      if (mounted) {
        setState(() {
          // Reset categories to default ones first to avoid duplicates
          _categories.clear();
          _categories.addAll([
            'All',
            'Cakes',
            'Pastries',
            'Bread',
            'Chips',
            'Dry Fruits',
            'Biscuits',
            'Beverages',
            'Packaging',
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

    _resetProductId();
    if (widget.autoShowAddItemForm) {
      _showAddItemForm = true;
    }
  }

  @override
  void dispose() {
    _categoriesSubscription?.cancel();
    _scrollController.dispose();
    _newCategoryController.dispose();
    _productIdController.dispose();
    _itemNameController.dispose();
    _barcodeController.dispose();
    _stockController.dispose();
    _reorderController.dispose();
    _purchaseRateController.dispose();
    _sellingRateController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  // Generate next Product ID sequential suggestion
  void _resetProductId() {
    int maxId = -1;
    final regex = RegExp(r'^P(\d+)$', caseSensitive: false);
    for (final item in _items) {
      final match = regex.firstMatch(item.id);
      if (match != null) {
        final val = int.tryParse(match.group(1) ?? '');
        if (val != null && val > maxId) {
          maxId = val;
        }
      }
    }
    final nextId = maxId + 1;
    final paddedId = 'P${nextId.toString().padLeft(3, '0')}';
    _productIdController.text = paddedId;
  }

  Future<void> _openBarcodeScanner() async {
    final scannedCode = await showDialog<String>(
      context: context,
      builder: (context) => BarcodeScannerDialog(catalog: _items.map((e) => e.toProduct()).toList()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      final existingIndex = _items.indexWhere(
        (item) => item.barcode.toLowerCase() == scannedCode.toLowerCase() ||
                  item.id.toLowerCase() == scannedCode.toLowerCase(),
      );

      if (existingIndex != -1) {
        final item = _items[existingIndex];
        setState(() {
          _itemNameController.text = item.name;
          _productIdController.text = item.id;
          _barcodeController.text = item.barcode;
          _stockController.text = item.stock.toStringAsFixed(0);
          _reorderController.text = item.reorderLevel.toStringAsFixed(0);
          _purchaseRateController.text = item.purchaseRate.toStringAsFixed(0);
          _sellingRateController.text = item.sellingRate.toStringAsFixed(0);
          _descriptionController.text = item.description;
          _selectedItemCategory = item.category;
          _selectedItemUnit = item.unit;
          _attachedImageBytes = null;
          _attachedImageName = item.imageName;
          _attachedImageUrl = item.imageUrl;
          _imageUrlController.text = item.imageUrl ?? '';
          _editingOriginalProductId = item.id;
          _showAddItemForm = true;
        });
        _scrollToBottom(true);
        _showSuccessSnackbar('Found existing item: "${item.name}". Populated edit form.');
      } else {
        setState(() {
          _itemNameController.clear();
          _productIdController.text = scannedCode.startsWith('P') && scannedCode.length == 4 ? scannedCode : '';
          if (_productIdController.text.isEmpty) {
            _resetProductId();
          }
          _barcodeController.text = scannedCode;
          _stockController.clear();
          _reorderController.clear();
          _purchaseRateController.clear();
          _sellingRateController.clear();
          _descriptionController.clear();
          _imageUrlController.clear();
          _selectedItemCategory = 'Cakes';
          _selectedItemUnit = 'pcs';
          _attachedImageBytes = null;
          _attachedImageName = null;
          _attachedImageUrl = null;
          _editingOriginalProductId = null;
          _showAddItemForm = true;
        });
        _scrollToBottom(true);
        _showSuccessSnackbar('New code scanned. Initialized new product form.');
      }
    }
  }

  // ── Calculations ──────────────────────────────────────────────────────────
  double get _totalStockValue => _items.fold(0.0, (sum, item) => sum + item.stockValue);
  int get _totalProductsCount => _items.length;
  int get _lowStockCount => _items.where((i) => i.stock > 0 && i.stock <= i.reorderLevel).length;
  int get _outOfStockCount => _items.where((i) => i.stock == 0).length;

  // ── Image Picker Options ───────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _attachedImageBytes = bytes;
          _attachedImageName = image.name;
        });
        _showSuccessSnackbar('Product image attached successfully!');
      }
    } catch (e) {
      debugPrint("Image picker error: $e");
      _showErrorSnackbar('Could not open image picker source.');
    }
  }

  void _showImageSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select Image Source',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
                title: const Text('Take Photo / Camera', style: TextStyle(fontSize: 15)),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
                title: const Text('Import from Gallery', style: TextStyle(fontSize: 15)),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                title: const Text('Cancel', style: TextStyle(fontSize: 15, color: Colors.red)),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _simulateImageCapture(String name) {
    final mockBytes = Uint8List.fromList(List.generate(100, (i) => i));
    setState(() {
      _attachedImageBytes = mockBytes;
      _attachedImageName = name;
    });
    _showSuccessSnackbar('Simulated product photo loaded!');
  }

  Future<void> _saveCategory() async {
    final newCat = _newCategoryController.text.trim();
    if (newCat.isEmpty) {
      _showErrorSnackbar('Please enter a Category Name');
      return;
    }
    final formattedCat = newCat[0].toUpperCase() + newCat.substring(1);
    
    try {
      await ProductService().saveCategory(formattedCat);
      setState(() {
        final alreadyExists = _categories.any((c) => c.toLowerCase() == formattedCat.toLowerCase());
        if (!alreadyExists) {
          _categories.add(formattedCat);
        }
        _selectedCategoryFilter = formattedCat;
        _newCategoryController.clear();
        _showAddCategoryForm = false;
      });
      _showSuccessSnackbar('Category "$formattedCat" created and selected!');
    } catch (e) {
      _showErrorSnackbar('Failed to save category to database: $e');
    }
  }

  Future<void> _saveProduct() async {
    final id = _productIdController.text.trim().isEmpty ? 'P000' : _productIdController.text.trim();
    final name = _itemNameController.text.trim();
    final barcode = _barcodeController.text.trim().isEmpty ? '8900000000000' : _barcodeController.text.trim();
    final stockVal = double.tryParse(_stockController.text) ?? 0.0;
    final reorderVal = double.tryParse(_reorderController.text) ?? 0.0;
    final purchaseVal = double.tryParse(_purchaseRateController.text) ?? 0.0;
    final sellingVal = double.tryParse(_sellingRateController.text) ?? 0.0;
    final desc = _descriptionController.text.trim();

    if (name.isEmpty) {
      _showErrorSnackbar('Please enter a product Item Name');
      return;
    }

    if (_doesProductIdExist(id)) {
      _showErrorSnackbar('Cannot save. Product ID "$id" already exists!');
      return;
    }

    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String? imageUrl = _imageUrlController.text.trim();
      if (imageUrl.isEmpty) {
        imageUrl = _attachedImageUrl;
      }
      if (_attachedImageBytes != null && _attachedImageName != null) {
        final uploadedUrl = await ProductService().uploadProductImage(
          '${id}_${DateTime.now().millisecondsSinceEpoch}_$_attachedImageName',
          _attachedImageBytes!,
        );
        if (uploadedUrl != null) {
          imageUrl = uploadedUrl;
        }
      }

      final newItem = InventoryItem(
        id: id,
        name: name,
        category: _selectedItemCategory,
        barcode: barcode,
        unit: _selectedItemUnit,
        stock: stockVal,
        reorderLevel: reorderVal,
        purchaseRate: purchaseVal,
        sellingRate: sellingVal,
        description: desc,
        imageUrl: imageUrl,
        imageName: _attachedImageName,
      );

      await ProductService().saveProduct(newItem);

      // Close the loading dialog
      if (mounted) Navigator.of(context).pop();

      setState(() {
        _itemNameController.clear();
        _barcodeController.clear();
        _stockController.clear();
        _reorderController.clear();
        _purchaseRateController.clear();
        _sellingRateController.clear();
        _descriptionController.clear();
        _imageUrlController.clear();
        _attachedImageBytes = null;
        _attachedImageName = null;
        _attachedImageUrl = null;
        _editingOriginalProductId = null;
        _showAddItemForm = false;
        _resetProductId();
      });

      _showSuccessSnackbar('Product "$name" saved successfully!');
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showErrorSnackbar('Failed to save product: $e');
    }
  }

  void _showSuccessSnackbar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.positive,
      ),
    );
  }

  void _showErrorSnackbar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[800],
      ),
    );
  }

  void _scrollToBottom(bool delay) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build Method ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InventoryItem>>(
      stream: _inventoryStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: Text('Error loading inventory: ${snapshot.error}')),
          );
        }

        _items = snapshot.data ?? [];

        // Auto-allocate next unused sequential ID once stream data is loaded
        if (_showAddItemForm &&
            (_productIdController.text.isEmpty || _productIdController.text == 'P000') &&
            _editingOriginalProductId == null) {
          _resetProductId();
        }

        final isIdDuplicate = _doesProductIdExist(_productIdController.text.trim());

        // Filter Items
        final filteredItems = _items.where((item) {
          // 1. Search Query
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            final matches = item.name.toLowerCase().contains(query) ||
                item.category.toLowerCase().contains(query) ||
                item.barcode.contains(query) ||
                item.id.toLowerCase().contains(query);
            if (!matches) return false;
          }

          // 2. Category Filter
          if (_selectedCategoryFilter != 'All') {
            final cat = _selectedCategoryFilter.toLowerCase();
            final matches = item.category.toLowerCase().contains(cat) ||
                cat.contains(item.category.toLowerCase());
            if (!matches) return false;
          }

          // 4. Stock status summary card filter
          if (_selectedStockStatusFilter == 'LOW_STOCK') {
            final isLowStock = item.stock > 0 && item.stock <= item.reorderLevel;
            if (!isLowStock) return false;
          } else if (_selectedStockStatusFilter == 'OUT_OF_STOCK') {
            final isOutOfStock = item.stock == 0;
            if (!isOutOfStock) return false;
          }

          return true;
        }).toList();

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            leadingWidth: 56,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 22),
              tooltip: 'Back to Home',
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('INVENTORY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, size: 26),
                tooltip: 'Settings',
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: AppTheme.divider),
            ),
          ),
          body: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // ── 1. Search Bar ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search Name, Barcode, or Product ID',
                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 22),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Scanner decoration icon
                InkWell(
                  onTap: _openBarcodeScanner,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const BarcodeScannerIcon(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),


            // ── 3. Stock Status Summary cards ────────────────────────────────
            const Text(
              'ITEM LIST',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Total Products Card
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedStockStatusFilter = 'ALL';
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedStockStatusFilter == 'ALL'
                            ? AppTheme.primary.withOpacity(0.18)
                            : AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.primary,
                          width: _selectedStockStatusFilter == 'ALL' ? 2.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$_totalProductsCount',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                          const SizedBox(height: 4),
                          const Text('Total Products', style: TextStyle(fontSize: 12, color: AppTheme.textMid, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Low Stock Items Card
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedStockStatusFilter = _selectedStockStatusFilter == 'LOW_STOCK' ? 'ALL' : 'LOW_STOCK';
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedStockStatusFilter == 'LOW_STOCK'
                            ? Colors.orange[100]
                            : Colors.orange[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orange[800]!,
                          width: _selectedStockStatusFilter == 'LOW_STOCK' ? 2.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$_lowStockCount',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                          ),
                          const SizedBox(height: 4),
                          Text('Low Stock Items', style: TextStyle(fontSize: 12, color: Colors.orange[800], fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Out of Stock Card
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedStockStatusFilter = _selectedStockStatusFilter == 'OUT_OF_STOCK' ? 'ALL' : 'OUT_OF_STOCK';
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedStockStatusFilter == 'OUT_OF_STOCK'
                            ? Colors.red[100]
                            : Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.red[800]!,
                          width: _selectedStockStatusFilter == 'OUT_OF_STOCK' ? 2.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$_outOfStockCount',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red[800]),
                          ),
                          const SizedBox(height: 4),
                          Text('Out of Stock', style: TextStyle(fontSize: 12, color: Colors.red[800], fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── 4. Category Filter Chips ─────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategoryFilter == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(cat, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                      selected: isSelected,
                      selectedColor: Colors.cyan[100],
                      backgroundColor: Colors.grey[100],
                      labelStyle: TextStyle(color: isSelected ? Colors.cyan[800] : AppTheme.textDark),
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategoryFilter = cat;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // ── 5. Product List Card Items ───────────────────────────────────
            if (filteredItems.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: const Text(
                  'No items found matching the filter criteria.',
                  style: TextStyle(color: Colors.grey, fontSize: 14, fontStyle: FontStyle.italic),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredItems.length,
                itemBuilder: (context, idx) {
                  final item = filteredItems[idx];

                  // Compute status dynamically
                  String statusText = 'In Stock';
                  Color badgeBg = Colors.green[50]!;
                  Color badgeText = Colors.green[800]!;
                  if (item.stock == 0) {
                    statusText = 'Out of Stock';
                    badgeBg = Colors.red[50]!;
                    badgeText = Colors.red[800]!;
                  } else if (item.stock <= item.reorderLevel) {
                    statusText = 'Low Stock';
                    badgeBg = Colors.orange[50]!;
                    badgeText = Colors.orange[800]!;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[200]!),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Image Thumbnail or Placeholder
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    item.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.broken_image, color: Colors.red),
                                  ),
                                )
                              : const Center(
                                  child: Text(
                                    '[ PIC ]',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        // Detail text block
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'ID: ${item.id} | Category: ${item.category} | Stock: ${item.stock.toStringAsFixed(0)} ${item.unit}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                              Text(
                                'Price: ₹${item.sellingRate.toStringAsFixed(0)} (Purchase: ₹${item.purchaseRate.toStringAsFixed(0)})',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Actions Column: status badge, edit, delete
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: badgeText,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _itemNameController.text = item.name;
                                      _productIdController.text = item.id;
                                      _barcodeController.text = item.barcode;
                                      _stockController.text = item.stock.toStringAsFixed(0);
                                      _reorderController.text = item.reorderLevel.toStringAsFixed(0);
                                      _purchaseRateController.text = item.purchaseRate.toStringAsFixed(0);
                                      _sellingRateController.text = item.sellingRate.toStringAsFixed(0);
                                      _descriptionController.text = item.description;
                                      _selectedItemCategory = item.category;
                                      _selectedItemUnit = item.unit;
                                      _attachedImageBytes = null;
                                      _attachedImageName = item.imageName;
                                      _attachedImageUrl = item.imageUrl;
                                      _imageUrlController.text = item.imageUrl ?? '';
                                      _editingOriginalProductId = item.id;

                                      _showAddItemForm = true;
                                    });
                                    _scrollToBottom(true);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(Icons.edit_outlined, color: Colors.purple, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () async {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Product'),
                                        content: Text('Are you sure you want to delete ${item.name}?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () async {
                                              Navigator.of(context).pop();
                                              try {
                                                await ProductService().deleteProduct(item.id);
                                                _showSuccessSnackbar('Item "${item.name}" deleted.');
                                              } catch (e) {
                                                _showErrorSnackbar('Failed to delete item: $e');
                                              }
                                            },
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),

            // ── 6. Sticky Bottom Buttons & Total card ───────────────────────
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primary, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () {
                      setState(() {
                        _showAddCategoryForm = !_showAddCategoryForm;
                      });
                      _scrollToBottom(true);
                    },
                    child: const Text(
                      '+ ADD CATEGORY',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.monetization_on_outlined, color: AppTheme.primary, size: 18),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('TOTAL STOCK VALUE', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                              Text(
                                '₹ ${_totalStockValue.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size(0, 48),
                      elevation: 0,
                    ),
                    onPressed: () {
                      setState(() {
                        _showAddItemForm = !_showAddItemForm;
                        if (_showAddItemForm) {
                          _resetProductId();
                        }
                      });
                      _scrollToBottom(true);
                    },
                    child: const Text(
                      '+ ADD ITEM',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),

            // ── 7. ADD NEW CATEGORY Form ─────────────────────────────────────
            if (_showAddCategoryForm) ...[
              const SizedBox(height: 20),
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey[200]!, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ADD NEW CATEGORY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primary)),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newCategoryController,
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: 'Enter Category Name',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: AppTheme.primary, size: 36),
                            onPressed: _saveCategory,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ── 8. ADD NEW ITEM Form ─────────────────────────────────────────
            if (_showAddItemForm) ...[
              const SizedBox(height: 20),
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey[200]!, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ADD NEW ITEM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primary)),
                          Row(
                            children: [
                              const Text('Active ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                              Switch(
                                value: true,
                                activeThumbColor: AppTheme.primary,
                                onChanged: (val) {},
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Manual Product ID Input
                      const Text('Product ID *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _productIdController,
                        onChanged: (val) {
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter custom Product ID (e.g. P999)',
                          border: const OutlineInputBorder(),
                          errorText: isIdDuplicate
                              ? 'This Product ID already exists!'
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Item Name & Category
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Item Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _itemNameController,
                                  enabled: !isIdDuplicate,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter item name',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Category *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedItemCategory,
                                      isExpanded: true,
                                      items: _categories.where((c) => c != 'All').map((c) {
                                        return DropdownMenuItem<String>(
                                          value: c,
                                          child: Text(c),
                                        );
                                      }).toList(),
                                      onChanged: isIdDuplicate
                                          ? null
                                          : (val) {
                                              if (val != null) {
                                                setState(() {
                                                  _selectedItemCategory = val;
                                                });
                                              }
                                            },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // SKU/Barcode & Unit
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('SKU/Barcode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _barcodeController,
                                  enabled: !isIdDuplicate,
                                  decoration: InputDecoration(
                                    hintText: 'Enter SKU / Scan Barcode',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primary),
                                      onPressed: _openBarcodeScanner,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Unit *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedItemUnit,
                                      isExpanded: true,
                                      items: ['pcs', 'kg', 'gr', 'pack'].map((u) {
                                        return DropdownMenuItem<String>(
                                          value: u,
                                          child: Text(u),
                                        );
                                      }).toList(),
                                      onChanged: isIdDuplicate
                                          ? null
                                          : (val) {
                                              if (val != null) {
                                                setState(() {
                                                  _selectedItemUnit = val;
                                                });
                                              }
                                            },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Stock Quantity & Reorder level
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Stock Quantity *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _stockController,
                                  enabled: !isIdDuplicate,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Enter Stock Quantity',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    suffixIcon: Icon(Icons.unfold_more, color: Colors.grey[600]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Reorder level', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _reorderController,
                                  enabled: !isIdDuplicate,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter reorder level',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Purchase Rate & Selling Rate
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Purchase Rate (₹) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _purchaseRateController,
                                  enabled: !isIdDuplicate,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter purchase rate',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Selling Rate (₹) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _sellingRateController,
                                  enabled: !isIdDuplicate,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter Selling Rate',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Description
                      const Text('Description (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _descriptionController,
                        enabled: !isIdDuplicate,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Enter description',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Image Web URL Input
                      const Text('Image Web URL (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _imageUrlController,
                        enabled: !isIdDuplicate,
                        decoration: const InputDecoration(
                          hintText: 'Paste direct image URL (e.g. from PostImages/Imgur)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          suffixIcon: Icon(Icons.link, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Add Image Box
                      const Text('Or Upload/Simulate Image (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      _buildAddImageBox(isEnabled: !isIdDuplicate),
                      const SizedBox(height: 18),

                      // Reset & Save buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.primary),
                                foregroundColor: AppTheme.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: () {
                                setState(() {
                                  _itemNameController.clear();
                                  _barcodeController.clear();
                                  _stockController.clear();
                                  _reorderController.clear();
                                  _purchaseRateController.clear();
                                  _sellingRateController.clear();
                                  _descriptionController.clear();
                                  _imageUrlController.clear();
                                  _attachedImageUrl = null;
                                  _attachedImageBytes = null;
                                  _attachedImageName = null;
                                  _editingOriginalProductId = null;
                                });
                                _showErrorSnackbar('Form values reset.');
                              },
                              child: const Text('RESET', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isIdDuplicate ? Colors.grey : Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                minimumSize: const Size(0, 48),
                                elevation: 0,
                              ),
                              onPressed: isIdDuplicate
                                  ? () {
                                      _showErrorSnackbar('Cannot save. Product ID already exists!');
                                    }
                                  : _saveProduct,
                              child: const Text('SAVE ITEM', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
      },
    );
  }

  // ── Component: Add Image attachment box ──
  Widget _buildAddImageBox({bool isEnabled = true}) {
    final hasImage = _attachedImageBytes != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isEnabled ? Colors.grey[50] : Colors.grey[200],
        border: Border.all(
          color: hasImage && isEnabled ? AppTheme.primary : Colors.grey[300]!,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IgnorePointer(
        ignoring: !isEnabled,
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: Column(
            children: [
              if (!hasImage)
                GestureDetector(
                  onTap: _showImageSourceBottomSheet,
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    color: Colors.grey[200],
                    alignment: Alignment.center,
                    child: Text(
                      'Add an image',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.grey[300],
                      ),
                      child: const Icon(Icons.image, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _attachedImageName ?? 'image.png',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text('Attached', style: TextStyle(fontSize: 11, color: AppTheme.positive)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _attachedImageBytes = null;
                          _attachedImageName = null;
                        });
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              // Simulator helper controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () => _simulateImageCapture('simulated_camera_photo.jpg'),
                    child: const Text('Simulate Camera Capture', style: TextStyle(fontSize: 10)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () => _simulateImageCapture('simulated_gallery_photo.png'),
                    child: const Text('Simulate Gallery Import', style: TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Custom Barcode Scanner Icon Widget ──
class BarcodeScannerIcon extends StatelessWidget {
  const BarcodeScannerIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(width: 2.2, color: AppTheme.textDark),
          Container(width: 1.0, color: AppTheme.textDark),
          Container(width: 3.5, color: AppTheme.textDark),
          Container(width: 1.0, color: AppTheme.textDark),
          Container(width: 2.2, color: AppTheme.textDark),
          Container(width: 1.5, color: AppTheme.textDark),
        ],
      ),
    );
  }
}
