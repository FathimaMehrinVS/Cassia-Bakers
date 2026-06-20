import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/core.dart';
import '../../core/models/supplier.dart';
import '../../core/services/supplier_service.dart';
import '../../core/services/customer_supplier_service.dart';
import 'supplier_detail_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SupplierPage
// ─────────────────────────────────────────────────────────────────────────────

class SupplierPage extends StatefulWidget {
  const SupplierPage({super.key});

  @override
  State<SupplierPage> createState() => _SupplierPageState();
}

class _SupplierPageState extends State<SupplierPage> {
  String _searchQuery = '';
  String _activeFilter = 'ALL'; // 'ALL', 'ACTIVE', 'INACTIVE', 'RECENT'
  final Set<String> _selectedSupplierIds = {};

  // ── Add Supplier Overlay state ─────────────────────────────────────────────
  bool _showAddSupplierOverlay = false;
  final _addNameController = TextEditingController();
  final _addPhoneController = TextEditingController();
  final _addGstinController = TextEditingController();

  @override
  void dispose() {
    _addNameController.dispose();
    _addPhoneController.dispose();
    _addGstinController.dispose();
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
  Future<void> _saveNewSupplier() async {
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

    final id = 'supplier_${DateTime.now().millisecondsSinceEpoch}';
    final newSupplier = SupplierData(
      id: id,
      name: name,
      phone: phone,
      gstin: gstin,
      status: 'ACTIVE',
      isEnabled: true,
      netDue: 0.0,
    );

    try {
      await SupplierService().addSupplier(newSupplier);

      setState(() {
        _addNameController.clear();
        _addPhoneController.clear();
        _addGstinController.clear();
        _showAddSupplierOverlay = false;
      });

      CustomerSupplierService().notify();
      _showSuccessSnackbar('Supplier "$name" added successfully!');
    } catch (e) {
      _showErrorSnackbar('Error adding supplier: $e');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SupplierData>>(
      stream: SupplierService().getSuppliers(),
      builder: (context, snapshot) {
        final suppliersList = snapshot.data ?? [];

        final filteredSuppliers = suppliersList.where((s) {
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
        final totalDue = suppliersList
            .where((s) => s.isEnabled && s.netDue > 0)
            .fold(0.0, (sum, s) => sum + s.netDue);
        final activeCount = suppliersList.where((s) => s.isEnabled).length;

        return Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                _selectedSupplierIds.isNotEmpty ? 72 : 16,
                16,
                16,
              ),
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
                  const SizedBox(height: 16),

                  // ── Add Supplier Button ───────────────────────────────────────
                  if (_selectedSupplierIds.isEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        onPressed: () =>
                            setState(() => _showAddSupplierOverlay = true),
                        icon: const Icon(Icons.person_add, size: 20),
                        label: const Text(
                          'Add Supplier',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

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
                          const Text(
                            'Supplier Directory',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark),
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

            // ── Contextual Selection Toolbar ──
            if (_selectedSupplierIds.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Colors.purple, // Purple matching the theme color gradient
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _selectedSupplierIds.clear();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedSupplierIds.length} Selected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white),
                        onPressed: () => _confirmDeleteSuppliers(context),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Supplier Card ──────────────────────────────────────────────────────────
  Widget _buildSupplierCard(SupplierData s) {
    final isSelected = _selectedSupplierIds.contains(s.id);
    final netDue = s.netDue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green[50] : Colors.grey[100],
        border: Border.all(
          color: isSelected ? Colors.green[400]! : Colors.grey[300]!,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          if (_selectedSupplierIds.isNotEmpty) {
            setState(() {
              if (isSelected) {
                _selectedSupplierIds.remove(s.id);
              } else {
                _selectedSupplierIds.add(s.id);
              }
            });
          } else {
            Navigator.of(context).push(
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
          }
        },
        onLongPress: () {
          HapticFeedback.vibrate();
          setState(() {
            if (isSelected) {
              _selectedSupplierIds.remove(s.id);
            } else {
              _selectedSupplierIds.add(s.id);
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Pic circle placeholder or checkmark
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.green[100] : Colors.grey[300],
                  border: Border.all(
                    color: isSelected ? Colors.green[300]! : Colors.grey[400]!,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.green, size: 24)
                    : const Icon(Icons.storefront, color: AppTheme.textDark, size: 24),
              ),
              const SizedBox(width: 16),
              // Text details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.phone,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    if (s.gstin.isNotEmpty && s.gstin != 'N/A') ...[
                      const SizedBox(height: 2),
                      Text(
                        'GSTIN: ${s.gstin}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                    const SizedBox(height: 2),
                    StreamBuilder<List<BillData>>(
                      stream: SupplierService().getBills(s.id),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.length ?? 0;
                        return Text(
                          '$count bill${count == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Due label
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    netDue != 0
                        ? '₹ ${netDue.abs().toStringAsFixed(0)}'
                        : '₹ 0',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: netDue > 0 ? Colors.red : Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    netDue > 0
                        ? 'You Pay'
                        : netDue < 0
                            ? 'Advance'
                            : 'Settled',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: netDue > 0 ? Colors.brown[700] : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
              padding: EdgeInsets.fromLTRB(
                20, 20, 20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
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
      ),
    );
  }

  Future<void> _confirmDeleteSuppliers(BuildContext ctx) async {
    final count = _selectedSupplierIds.length;
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Delete $count ${count == 1 ? 'Supplier' : 'Suppliers'}?',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${count == 1 ? 'this supplier' : 'these suppliers'}? '
          'This will permanently delete all associated ledger transactions and bills.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final idsToDelete = List<String>.from(_selectedSupplierIds);
        for (final id in idsToDelete) {
          await SupplierService().deleteSupplier(id);
        }
        setState(() {
          _selectedSupplierIds.clear();
        });
        CustomerSupplierService().notify();
        _showSuccessSnackbar('Deleted supplier(s) successfully!');
      } catch (e) {
        _showErrorSnackbar('Failed to delete supplier(s): $e');
      }
    }
  }
}
