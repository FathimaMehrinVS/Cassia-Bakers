import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/core.dart';
import 'customer_detail_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Customer Data Models
// ─────────────────────────────────────────────────────────────────────────────

class CustomerDueTransaction {
  final String description;
  final String date;
  final double amount;
  final bool isPayment; // true if customer paid us, false if customer incurred due
  final Uint8List? attachedImageBytes;
  final String? attachedImageName;

  CustomerDueTransaction({
    required this.description,
    required this.date,
    required this.amount,
    required this.isPayment,
    this.attachedImageBytes,
    this.attachedImageName,
  });
}

class CustomerData {
  final String id;
  final String name;
  final String phone;
  final String dateAdded;
  final List<CustomerDueTransaction> transactions;

  CustomerData({
    required this.id,
    required this.name,
    required this.phone,
    required this.dateAdded,
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
}

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

  // ── Customer Directory State ───────────────────────────────────────────────
  final List<CustomerData> _customers = [
    CustomerData(
      id: 'c000',
      name: 'Rahul Sharma',
      phone: '+91 98765 43210',
      dateAdded: '10 Jun 2026',
      transactions: [
        CustomerDueTransaction(description: 'Initial Due (Order #1002)', date: '10 Jun 2026 at 11:32 AM', amount: 2500, isPayment: false),
        CustomerDueTransaction(description: 'Cash Payment', date: '11 Jun 2026 at 11:32 AM', amount: 1000, isPayment: true),
      ],
    ),
    CustomerData(
      id: 'c001',
      name: 'Priya Nair',
      phone: '+91 87654 32109',
      dateAdded: '12 Jun 2026',
      transactions: [
        CustomerDueTransaction(description: 'Initial Due (Order #1005)', date: '12 Jun 2026 at 11:32 AM', amount: 850, isPayment: false),
      ],
    ),
    CustomerData(
      id: 'c002',
      name: 'Amit Patel',
      phone: '+91 76543 21098',
      dateAdded: '14 Jun 2026',
      transactions: [
        CustomerDueTransaction(description: 'Order #1012', date: '14 Jun 2026 at 11:32 AM', amount: 3200, isPayment: false),
      ],
    ),
    CustomerData(
      id: 'c003',
      name: 'Sneha Rao',
      phone: '+91 65432 10987',
      dateAdded: '15 Jun 2026',
      transactions: [],
    ),
  ];

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

  // ── Calculations ──────────────────────────────────────────────────────────
  double get _totalNetDue => _customers.fold(0.0, (sum, c) => sum + c.netDue);
  int get _activeAccountsCount => _customers.where((c) => c.netDue > 0).length;

  // ── Handlers ───────────────────────────────────────────────────────────────
  void _saveCustomer() {
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

    final newId = 'c${DateTime.now().millisecondsSinceEpoch}';
    final nowStr = '${DateTime.now().day} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}';

    final List<CustomerDueTransaction> txs = [];
    if (initialDueVal > 0) {
      txs.add(CustomerDueTransaction(
        description: 'Opening Due balance',
        date: '$nowStr at 12:00 PM',
        amount: initialDueVal,
        isPayment: false,
      ));
    }

    setState(() {
      _customers.add(CustomerData(
        id: newId,
        name: name,
        phone: phone,
        dateAdded: nowStr,
        transactions: txs,
      ));

      _nameController.clear();
      _phoneController.clear();
      _initialDueController.clear();
      _showAddCustomerForm = false;
    });

    _showSuccessSnackbar('Customer "$name" added successfully!');
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return 'Jun';
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
                          '$_activeAccountsCount Accounts',
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
                          _totalNetDue.toStringAsFixed(0),
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
                itemCount: _customers.length,
                itemBuilder: (context, idx) {
                  final customer = _customers[idx];
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
                                    customer.dateAdded,
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
  }

  // ── Drawer: Add Customer Overlay ──
  Widget _buildAddCustomerOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showAddCustomerForm = false),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black54,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {}, // Prevent click propagation
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Add New Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _showAddCustomerForm = false),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Customer Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Enter customer name',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Customer Phone Number *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: 'Enter customer phone number',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Initial Due Amount (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _initialDueController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Enter initial due (if any)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: () => setState(() => _showAddCustomerForm = false),
                          child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            minimumSize: const Size(0, 48),
                            elevation: 0,
                          ),
                          onPressed: _saveCustomer,
                          child: const Text('SAVE CUSTOMER', style: TextStyle(fontWeight: FontWeight.bold)),
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
    );
  }
}
