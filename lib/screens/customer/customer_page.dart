import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../core/models/customer.dart';
import '../../core/services/customer_service.dart';
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

  // ── Add Customer Form State ────────────────────────────────────────────────
  bool _showAddCustomerForm = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _initialDueController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _initialDueController.dispose();
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
    final initialDueVal = double.tryParse(_initialDueController.text) ?? 0.0;

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
      netDue: initialDueVal > 0 ? initialDueVal : 0.0,
    );

    try {
      await _customerService.addCustomer(newCustomer);

      setState(() {
        _nameController.clear();
        _phoneController.clear();
        _initialDueController.clear();
        _showAddCustomerForm = false;
      });

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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey[300]!, width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
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
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                // Pic circle placeholder
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    border: Border.all(color: Colors.grey[400]!),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
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
            if (!_showAddCustomerForm)
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
          ],
        );
      },
    );
  }

  Widget _buildAddCustomerOverlay() {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

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
                maxHeight: screenHeight * 0.62,
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16, 16, 16, keyboardHeight > 0 ? keyboardHeight + 16 : 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header (never scrolls) ──
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

                    // ── Scrollable fields (only if needed) ──
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                            const SizedBox(height: 12),
                            const Text(
                              'Initial Due Amount (Optional)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _initialDueController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Enter initial due (if any)',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                prefixText: '₹ ',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Buttons (always visible, never scrolls) ──
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
    );
  }
}