import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/core.dart';
import 'staff_detail_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Staff Data Models
// ─────────────────────────────────────────────────────────────────────────────

class StaffTransaction {
  final String description;
  final String date;
  final double amount;
  final bool isPayment; // true if paid (we pay them), false if salary credited (we owe them)
  final Uint8List? attachedImageBytes;
  final String? attachedImageName;

  StaffTransaction({
    required this.description,
    required this.date,
    required this.amount,
    required this.isPayment,
    this.attachedImageBytes,
    this.attachedImageName,
  });
}

class StaffData {
  final String id;
  final String name;
  final String phone;
  final String dateAdded;
  final List<StaffTransaction> transactions;

  StaffData({
    required this.id,
    required this.name,
    required this.phone,
    required this.dateAdded,
    required this.transactions,
  });

  double get balance {
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
// StaffPage Widget
// ─────────────────────────────────────────────────────────────────────────────

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  final ScrollController _scrollController = ScrollController();

  // ── Mock Staff Directory State ──────────────────────────────────────────────
  final List<StaffData> _staffList = [
    StaffData(
      id: 'st000',
      name: 'Ramesh Kumar',
      phone: '+91 99887 76655',
      dateAdded: '01 Jun 2026',
      transactions: [
        StaffTransaction(description: 'Monthly Salary Credit', date: '01 Jun 2026 at 10:00 AM', amount: 20000, isPayment: false),
        StaffTransaction(description: 'Salary Paid (Cash)', date: '01 Jun 2026 at 06:00 PM', amount: 19999, isPayment: true),
      ],
    ),
    StaffData(
      id: 'st001',
      name: 'Sunita Sharma',
      phone: '+91 88776 65544',
      dateAdded: '05 Jun 2026',
      transactions: [
        StaffTransaction(description: 'Monthly Salary Credit', date: '05 Jun 2026 at 10:00 AM', amount: 25000, isPayment: false),
        StaffTransaction(description: 'Salary Paid (UPI)', date: '05 Jun 2026 at 04:30 PM', amount: 24999, isPayment: true),
      ],
    ),
  ];

  // ── Add Staff Form State ───────────────────────────────────────────────────
  bool _showAddStaffForm = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _initialBalanceController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  // ── Calculations ──────────────────────────────────────────────────────────
  double get _totalNetBalance => _staffList.fold(0.0, (sum, s) => sum + s.balance);
  int get _accountsCount => _staffList.length;

  // ── Handlers ───────────────────────────────────────────────────────────────
  void _saveStaff() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final balVal = double.tryParse(_initialBalanceController.text) ?? 0.0;

    if (name.isEmpty) {
      _showErrorSnackbar('Please enter Staff Name');
      return;
    }
    if (phone.isEmpty) {
      _showErrorSnackbar('Please enter Phone Number');
      return;
    }

    final newId = 'st${DateTime.now().millisecondsSinceEpoch}';
    final nowStr = '${DateTime.now().day} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}';

    final List<StaffTransaction> txs = [];
    if (balVal > 0) {
      txs.add(StaffTransaction(
        description: 'Opening Salary Balance',
        date: '$nowStr at 12:00 PM',
        amount: balVal,
        isPayment: false,
      ));
    }

    setState(() {
      _staffList.add(StaffData(
        id: newId,
        name: name,
        phone: phone,
        dateAdded: nowStr,
        transactions: txs,
      ));

      _nameController.clear();
      _phoneController.clear();
      _initialBalanceController.clear();
      _showAddStaffForm = false;
    });

    _showSuccessSnackbar('Staff member "$name" added successfully!');
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

  @override
  Widget build(BuildContext context) {
    final hasPayable = _totalNetBalance > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main Scrollable Area
          SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Hero Balance Card ─────────────────────────────────────
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
                          Row(
                            children: [
                              const Icon(Icons.person, size: 16, color: AppTheme.textDark),
                              const SizedBox(width: 4),
                              Text(
                                '$_accountsCount Accounts',
                                style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₹ ',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: hasPayable ? Colors.green[800] : Colors.green[800]),
                          ),
                          Text(
                            _totalNetBalance.toStringAsFixed(0),
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: hasPayable ? Colors.green[800] : Colors.green[800]),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Salary',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── 2. Scrollable Staff Directory List ────────────────────────
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _staffList.length,
                  itemBuilder: (context, idx) {
                    final staff = _staffList[idx];
                    final isDue = staff.balance > 0;

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
                              builder: (context) => StaffDetailPage(
                                staff: staff,
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
                          // Avatar placeholder
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
                          // Details block
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  staff.name,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  staff.phone,
                                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  staff.dateAdded,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                          // Balance indicator
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹ ${staff.balance.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDue ? Colors.green[800] : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Salary',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.brown[700],
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

          // ── 3. Add Staff Bottom Sheet Overlay ──
          if (_showAddStaffForm)
            _buildAddStaffOverlay(),

          // ── 4. Add Staff FAB ──
          if (!_showAddStaffForm)
            Positioned(
              bottom: 16,
              right: 16,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _showAddStaffForm = true;
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
                        'Add Staff',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Overlay: Add Staff ──
  Widget _buildAddStaffOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showAddStaffForm = false),
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
                      const Text('Add New Staff Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _showAddStaffForm = false),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Staff Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Enter staff name',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Staff Phone Number *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: 'Enter staff phone number',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Monthly Salary (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _initialBalanceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Enter monthly salary',
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
                          onPressed: () => setState(() => _showAddStaffForm = false),
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
                          onPressed: _saveStaff,
                          child: const Text('SAVE STAFF', style: TextStyle(fontWeight: FontWeight.bold)),
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
