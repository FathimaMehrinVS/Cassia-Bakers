import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/core.dart';
import '../../core/models/customer.dart';
import '../../core/services/customer_service.dart';
import '../../core/services/customer_supplier_service.dart';
import 'customer_detail_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CustomerPage Screen
// ─────────────────────────────────────────────────────────────────────────────

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  final ScrollController _scrollController = ScrollController();
  final CustomerService _customerService = CustomerService();
  final Set<String> _selectedCustomerIds = {};

  // ── Add Customer Form State ────────────────────────────────────────────────
  bool _showAddCustomerForm = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Date Helpers ───────────────────────────────────────────────────────────
  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return 'Jun';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_getMonthName(dt.month)} ${dt.year}';
  }

  // ── Handlers ───────────────────────────────────────────────────────────────
  Future<void> _saveCustomer() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      _showErrorSnackbar('Please enter Customer Name');
      return;
    }
    if (phone.isEmpty) {
      _showErrorSnackbar('Please enter Phone Number');
      return;
    }

    final now = DateTime.now();

    final newCustomer = CustomerData(
      id: '',
      name: name,
      phone: phone,
      dateAdded: now,
      netDue: 0.0,
    );

    try {
      await _customerService.addCustomer(newCustomer);

      setState(() {
        _nameController.clear();
        _phoneController.clear();
        _showAddCustomerForm = false;
      });

      CustomerSupplierService().notify();
      _showSuccessSnackbar('Customer "$name" added successfully!');
    } catch (e) {
      _showErrorSnackbar('Failed to add customer. Please try again.');
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

  // ── Build Method ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CustomerData>>(
      stream: _customerService.getCustomers(),
      builder: (context, snapshot) {
        final customers = snapshot.data ?? [];
        final totalNetDue = customers.fold(0.0, (sum, c) => sum + c.netDue);
        final activeAccountsCount = customers.where((c) => c.netDue > 0).length;

        return Stack(
          children: [
            // Main Scrollable Area
            SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                16,
                _selectedCustomerIds.isNotEmpty ? 72 : 16,
                16,
                16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Hero Balance Card ───────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.grey[400]!, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Net Balance',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$activeAccountsCount Accounts',
                              style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const Text(
                              '₹ ',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                            Text(
                              totalNetDue.toStringAsFixed(0),
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'You get',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 2. Scrollable Customer Directory List ──────────────────────
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: customers.length,
                    itemBuilder: (context, idx) {
                      final customer = customers[idx];
                      final hasDue = customer.netDue > 0;
                      final isSelected = _selectedCustomerIds.contains(customer.id);

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
                            if (_selectedCustomerIds.isNotEmpty) {
                              setState(() {
                                if (isSelected) {
                                  _selectedCustomerIds.remove(customer.id);
                                } else {
                                  _selectedCustomerIds.add(customer.id);
                                }
                              });
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => CustomerDetailPage(
                                    customer: customer,
                                    onChanged: () {
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
                                _selectedCustomerIds.remove(customer.id);
                              } else {
                                _selectedCustomerIds.add(customer.id);
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
                                      : const Text(
                                          '[pic]',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                                        ),
                                ),
                                const SizedBox(width: 16),
                                // Text details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        customer.phone,
                                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatDate(customer.dateAdded),
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ),
                                ),
                                // Due label
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      hasDue ? '₹ ${customer.netDue.toStringAsFixed(0)}' : '₹ 0',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: hasDue ? Colors.red : Colors.green[800],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Due',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: hasDue ? Colors.brown[700] : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 80), // Space for bottom FAB
                ],
              ),
            ),

            // ── 3. Add Customer Bottom Form ──
            if (_showAddCustomerForm)
              _buildAddCustomerOverlay(),

            // ── 4. Add Customer Rectangular FAB ──
            if (!_showAddCustomerForm && _selectedCustomerIds.isEmpty)
              Positioned(
                bottom: 16,
                right: 16,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _showAddCustomerForm = true;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green[500],
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.person_add_alt_1_sharp, color: Colors.black, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Add Customer',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Contextual Selection Toolbar ──
            if (_selectedCustomerIds.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.green[800],
                    boxShadow: const [
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
                            _selectedCustomerIds.clear();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedCustomerIds.length} Selected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white),
                        onPressed: () => _confirmDeleteCustomers(context),
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

  Widget _buildAddCustomerOverlay() {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showAddCustomerForm = false),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black54,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (screenHeight - topPadding - 56) * 0.85,
              ),
              child: Container(
                width: AppTheme.isWideScreen(context) ? 500 : double.infinity,
                padding: EdgeInsets.fromLTRB(
                  16, 16, 16,
                  bottomPadding + 16,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Add New Customer',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.primary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(
                              () => _showAddCustomerForm = false,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 8),

                      const Text(
                        'Customer Name *',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Enter customer name',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Customer Phone Number *',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: 'Enter customer phone number',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Buttons ──
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: () => setState(
                                () => _showAddCustomerForm = false,
                              ),
                              child: const Text(
                                'CANCEL',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                minimumSize: const Size(0, 48),
                                elevation: 0,
                              ),
                              onPressed: _saveCustomer,
                              child: const Text(
                                'SAVE CUSTOMER',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCustomers(BuildContext ctx) async {
    final count = _selectedCustomerIds.length;
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Delete $count ${count == 1 ? 'Customer' : 'Customers'}?',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${count == 1 ? 'this customer' : 'these customers'}? '
          'This will permanently delete all associated ledger transactions.',
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
        final idsToDelete = List<String>.from(_selectedCustomerIds);
        for (final id in idsToDelete) {
          await _customerService.deleteCustomer(id);
        }
        setState(() {
          _selectedCustomerIds.clear();
        });
        CustomerSupplierService().notify();
        _showSuccessSnackbar('Deleted customer(s) successfully!');
      } catch (e) {
        _showErrorSnackbar('Failed to delete customer(s): $e');
      }
    }
  }
}