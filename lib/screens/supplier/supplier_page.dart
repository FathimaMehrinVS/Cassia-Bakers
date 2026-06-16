import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../core/services/customer_supplier_service.dart';
import 'supplier_detail_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

class BillItemRow {
  String name;
  double quantity;
  String unit; // e.g. "kg", "gr", "pcs"
  double rate;
  late TextEditingController nameController;

  BillItemRow({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.rate,
  }) {
    nameController = TextEditingController(text: name);
    nameController.addListener(() {
      name = nameController.text;
    });
  }

  double get amount => quantity * rate;
}

class BillData {
  final String billNo;
  final String date;
  final double subtotal;
  final double gst;
  final double total;
  final String notes;
  final List<BillItemRow> items;
  final Uint8List? attachedImageBytes;
  final String? attachedImageName;

  BillData({
    required this.billNo,
    required this.date,
    required this.subtotal,
    required this.gst,
    required this.total,
    required this.notes,
    required this.items,
    this.attachedImageBytes,
    this.attachedImageName,
  });
}

class SupplierTransaction {
  final String description;
  final String date;
  final double amount;
  final bool isPayment; // true = payment made (reduces due), false = bill (increases due)
  final Uint8List? attachedImageBytes;
  final String? attachedImageName;

  SupplierTransaction({
    required this.description,
    required this.date,
    required this.amount,
    required this.isPayment,
    this.attachedImageBytes,
    this.attachedImageName,
  });
}

class SupplierData {
  final String id;
  final String name;
  final String phone;
  final String gstin;
  String status; // 'ACTIVE' or 'INACTIVE'
  bool isEnabled;
  final List<BillData> bills;
  final List<SupplierTransaction> transactions;

  SupplierData({
    required this.id,
    required this.name,
    required this.phone,
    required this.gstin,
    required this.status,
    required this.isEnabled,
    required this.bills,
    required this.transactions,
  });

  double get netDue {
    double total = 0.0;
    for (final tx in transactions) {
      if (tx.isPayment) {
        total -= tx.amount;
      } else {
        total += tx.amount;
      }
    }
    return total;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierData &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────────────────────────────────────────
// SupplierPage
// ─────────────────────────────────────────────────────────────────────────────

class SupplierPage extends StatefulWidget {
  const SupplierPage({super.key});

  @override
  State<SupplierPage> createState() => _SupplierPageState();
}

class _SupplierPageState extends State<SupplierPage> {
  // ── Supplier Directory ─────────────────────────────────────────────────────
  List<SupplierData> get _suppliers => CustomerSupplierService().suppliers;

  String _searchQuery = '';
  String _activeFilter = 'ALL'; // 'ALL', 'ACTIVE', 'INACTIVE', 'RECENT'

  // ── Add Supplier Overlay state ─────────────────────────────────────────────
  bool _showAddSupplierOverlay = false;
  final _addNameController = TextEditingController();
  final _addPhoneController = TextEditingController();
  final _addGstinController = TextEditingController();
  final _addInitialDueController = TextEditingController();

  @override
  void dispose() {
    _addNameController.dispose();
    _addPhoneController.dispose();
    _addGstinController.dispose();
    _addInitialDueController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _showSuccessSnackbar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.positive,
      ),
    );
  }

  void _showErrorSnackbar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[800],
      ),
    );
  }

  // ── Add Supplier Logic ─────────────────────────────────────────────────────
  void _saveNewSupplier() {
    if (_addNameController.text.trim().isEmpty) {
      _showErrorSnackbar('Please enter a supplier name');
      return;
    }
    final name = _addNameController.text.trim();
    final phone = _addPhoneController.text.trim().isEmpty
        ? '+9199999 00000'
        : _addPhoneController.text.trim();
    final gstin = _addGstinController.text.trim().isEmpty
        ? 'N/A'
        : _addGstinController.text.trim();
    final initialDue = double.tryParse(_addInitialDueController.text) ?? 0.0;

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${now.day} ${months[now.month - 1]} ${now.year}';

    final txList = <SupplierTransaction>[];
    if (initialDue > 0) {
      txList.add(SupplierTransaction(
        description: 'Opening balance',
        date: '$dateStr at $timeStr',
        amount: initialDue,
        isPayment: false,
      ));
    }

    setState(() {
      _suppliers.add(SupplierData(
        id: 'supplier_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        phone: phone,
        gstin: gstin,
        status: 'ACTIVE',
        isEnabled: true,
        bills: [],
        transactions: txList,
      ));
      _addNameController.clear();
      _addPhoneController.clear();
      _addGstinController.clear();
      _addInitialDueController.clear();
      _showAddSupplierOverlay = false;
    });

    CustomerSupplierService().notify();

    _showSuccessSnackbar('Supplier "$name" added successfully!');
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filteredSuppliers = _suppliers.where((s) {
      if (_activeFilter == 'ACTIVE' && s.status != 'ACTIVE') return false;
      if (_activeFilter == 'INACTIVE' && s.status != 'INACTIVE') return false;
      if (_searchQuery.isNotEmpty) {
        if (!s.isEnabled) return false;
        final q = _searchQuery.toLowerCase();
        if (!s.name.toLowerCase().contains(q) &&
            !s.phone.contains(q) &&
            !s.gstin.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();

    // Hero card totals
    final totalDue = _suppliers
        .where((s) => s.isEnabled && s.netDue > 0)
        .fold(0.0, (sum, s) => sum + s.netDue);
    final activeCount = _suppliers.where((s) => s.isEnabled).length;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero Card ─────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C3483), Color(0xFF1A5276)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C3483).withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Supplier Overview',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹ ${totalDue.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total You Pay  •  $activeCount Active Suppliers',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Directory Card ─────────────────────────────────────────────
              Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey[200]!, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Supplier Directory',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark),
                          ),
                          // Add Supplier button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              elevation: 0,
                            ),
                            onPressed: () =>
                                setState(() => _showAddSupplierOverlay = true),
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text('Add Supplier',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Search Bar
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          style: const TextStyle(fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Supplier Name / Phone / GST No',
                            hintStyle: TextStyle(
                                color: Colors.grey[500], fontSize: 14),
                            prefixIcon: Icon(Icons.search,
                                color: Colors.grey[500], size: 22),
                            suffixIcon: Icon(Icons.qr_code_scanner,
                                color: Colors.grey[500], size: 22),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Filter tabs
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: ['ALL', 'ACTIVE', 'INACTIVE', 'RECENT']
                                    .map((tab) {
                                  final isSelected = _activeFilter == tab;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: InkWell(
                                      onTap: () => setState(
                                          () => _activeFilter = tab),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppTheme.primary
                                              : Colors.grey[100],
                                          border: Border.all(
                                            color: isSelected
                                                ? AppTheme.primary
                                                : Colors.grey[300]!,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          tab,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? Colors.white
                                                : AppTheme.textDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.primary),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.filter_alt_outlined,
                                    color: AppTheme.primary, size: 16),
                                SizedBox(width: 6),
                                Text('FILTER',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary)),
                                Icon(Icons.arrow_drop_down,
                                    color: AppTheme.primary, size: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Supplier list
                      if (filteredSuppliers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.storefront_outlined,
                                    size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                const Text('No suppliers found',
                                    style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic)),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredSuppliers.length,
                          itemBuilder: (context, idx) {
                            final s = filteredSuppliers[idx];
                            return _buildSupplierCard(s);
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),

        // ── Add Supplier Overlay ─────────────────────────────────────────────
        if (_showAddSupplierOverlay) _buildAddSupplierOverlay(),
      ],
    );
  }

  // ── Supplier Card ──────────────────────────────────────────────────────────
  Widget _buildSupplierCard(SupplierData s) {
    final isActive = s.status == 'ACTIVE';
    final netDue = s.netDue;

    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SupplierDetailPage(
              supplier: s,
              onChanged: () {
                CustomerSupplierService().notify();
                setState(() {});
              },
            ),
          ),
        );
        CustomerSupplierService().notify();
        setState(() {});
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Company Icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront,
                  color: AppTheme.textDark, size: 26),
            ),
            const SizedBox(width: 12),

            // Details Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.name,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Status pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.green[100]
                              : Colors.red[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s.status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? Colors.green[800]
                                : Colors.red[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(s.phone,
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 12)),
                  Text('GSTIN: ${s.gstin}',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 11)),
                  const SizedBox(height: 6),
                  Text(
                    '${s.bills.length} bill${s.bills.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right: Actions
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.phone_outlined,
                          color: Colors.grey[600], size: 20),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.sms_outlined,
                          color: Colors.grey[600], size: 20),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Active', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 20,
                      width: 36,
                      child: FittedBox(
                        fit: BoxFit.fill,
                        child: Switch(
                          value: s.isEnabled,
                          activeThumbColor: AppTheme.primary,
                          onChanged: (val) {
                            setState(() {
                              s.isEnabled = val;
                              s.status = val ? 'ACTIVE' : 'INACTIVE';
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: netDue > 0
                        ? Colors.red[50]
                        : netDue < 0
                            ? Colors.blue[50]
                            : Colors.green[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: netDue > 0
                          ? Colors.red[200]!
                          : netDue < 0
                              ? Colors.blue[200]!
                              : Colors.green[200]!,
                    ),
                  ),
                  child: Text(
                    netDue > 0
                        ? '₹ ${netDue.toStringAsFixed(0)} Due'
                        : netDue < 0
                            ? '₹ ${(-netDue).toStringAsFixed(0)} Advance'
                            : 'Settled',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: netDue > 0
                          ? Colors.red[700]
                          : netDue < 0
                              ? Colors.blue[700]
                              : Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Add Supplier Overlay ────────────────────────────────────────────────────
  Widget _buildAddSupplierOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showAddSupplierOverlay = false),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black54,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {}, // Prevent tap through
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add New Supplier',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            setState(() => _showAddSupplierOverlay = false),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Name
                  const Text('Supplier Name *',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _addNameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Sri Lakshmi Foods',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Phone
                  const Text('Phone Number',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _addPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '+91 XXXXX XXXXX',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // GSTIN
                  const Text('GSTIN (Optional)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _addGstinController,
                    decoration: const InputDecoration(
                      hintText: '32XXXXX1234X1ZX',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Initial Due
                  const Text('Initial Due Amount (₹)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _addInitialDueController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      helperText:
                          'If you already owe them money, enter the amount',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.primary),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: () =>
                              setState(() => _showAddSupplierOverlay = false),
                          child: const Text('CANCEL',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            minimumSize: const Size(0, 48),
                            elevation: 0,
                          ),
                          onPressed: _saveNewSupplier,
                          child: const Text('SAVE',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
