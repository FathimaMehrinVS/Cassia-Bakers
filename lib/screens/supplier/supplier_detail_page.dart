import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/core.dart';
import '../../core/models/supplier.dart';
import '../../core/services/supplier_service.dart';
import '../../core/services/customer_supplier_service.dart';
import 'supplier_page.dart';
import '../common/transaction_entry_page.dart';
import '../common/transaction_detail_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SupplierDetailPage – Ledger + Add Bill tabs
// ─────────────────────────────────────────────────────────────────────────────

class SupplierDetailPage extends StatefulWidget {
  final SupplierData supplier;
  final VoidCallback onChanged;

  const SupplierDetailPage({
    super.key,
    required this.supplier,
    required this.onChanged,
  });

  @override
  State<SupplierDetailPage> createState() => _SupplierDetailPageState();
}

class _SupplierDetailPageState extends State<SupplierDetailPage> {
  // ── Tab: 0 = Ledger, 1 = Add Bill ─────────────────────────────────────────
  int _activeTab = 0; // default is Ledger

  // ── Ledger Overlay ─────────────────────────────────────────────────────────
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isOverlayOpen = false;
  bool _overlayIsPayment = true; // true = Paid (cash we paid supplier), false = Bill (credit added)

  // ── Add Bill Form State ────────────────────────────────────────────────────
  final _billNoController = TextEditingController();
  final _dateController = TextEditingController();
  final _notesController = TextEditingController();
  Uint8List? _attachedImageBytes;
  String? _attachedImageName;
  double? _gstOverride;
  final List<BillItemRow> _billItems = [
    BillItemRow(name: '', quantity: 1, unit: 'kg', rate: 0),
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill bill number
    final nextBillNum = 1026 + widget.supplier.bills.length;
    _billNoController.text = 'BILL-$nextBillNum';
    // Today's date
    final now = DateTime.now();
    _dateController.text =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _billNoController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    for (final item in _billItems) {
      item.nameController.dispose();
    }
    super.dispose();
  }

  // ── Calculation Helpers ────────────────────────────────────────────────────
  // ── Date Helpers ───────────────────────────────────────────────────────────
  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return 'Jun';
  }

  /// Formats a DateTime to "14 Jun 2026 at 11:32 AM"
  String _formatDateTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final dateStr = '${dt.day} ${_getMonthName(dt.month)} ${dt.year}';
    return '$dateStr at ${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  /// Returns just the date part "14 Jun 2026"
  String _formatDateOnly(DateTime dt) {
    return '${dt.day} ${_getMonthName(dt.month)} ${dt.year}';
  }

  /// Returns just the time part "11:32 AM"
  String _formatTimeOnly(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  // ── Calculation Helpers ────────────────────────────────────────────────────
  List<double> _calculateRunningBalances(List<SupplierTransaction> transactionsList) {
    final balances = <double>[];
    double current = 0.0;
    for (final tx in transactionsList) {
      if (tx.isPayment) {
        current -= tx.amount; // Payment decreases what we owe
      } else {
        current += tx.amount; // Bill increases what we owe
      }
      balances.add(current);
    }
    return balances;
  }

  double get _subtotal =>
      _billItems.fold(0.0, (sum, item) => sum + item.amount);
  double get _gst => _gstOverride ?? _subtotal * 0.05;
  double get _total => _subtotal + _gst;

  // ── Ledger: save a quick payment/bill transaction ──────────────────────────
  Future<void> _saveLedgerTransaction() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final desc = _descriptionController.text.trim();
    if (amount <= 0) {
      _showErrorSnackbar('Please enter a valid amount');
      return;
    }
    final formattedDesc = desc.isEmpty
        ? (_overlayIsPayment ? 'Cash paid' : 'Bill amount added')
        : desc;

    final tx = SupplierTransaction(
      id: '',
      description: formattedDesc,
      date: DateTime.now(),
      amount: amount,
      isPayment: _overlayIsPayment,
      attachedImageUrl: null,
      attachedImageName: null,
    );

    try {
      await SupplierService().addTransaction(widget.supplier.id, tx);
      setState(() {
        _amountController.clear();
        _descriptionController.clear();
        _isOverlayOpen = false;
      });
      widget.onChanged();
      _showSuccessSnackbar('Transaction recorded successfully!');
    } catch (e) {
      _showErrorSnackbar('Error recording transaction: $e');
    }
  }

  // ── Add Bill: save a bill ──────────────────────────────────────────────────
  Future<void> _saveBill() async {
    if (_billItems.every((item) => item.name.trim().isEmpty)) {
      _showErrorSnackbar('Please add at least one item');
      return;
    }

    final List<BillItemRow> itemsCopy = _billItems
        .map((item) => BillItemRow(
              name: item.name,
              quantity: item.quantity,
              unit: item.unit,
              rate: item.rate,
            ))
        .toList();

    final billNo = _billNoController.text.trim().isEmpty
        ? 'BILL-${DateTime.now().millisecondsSinceEpoch % 10000}'
        : _billNoController.text.trim();

    // Parse dd-MM-yyyy to DateTime
    DateTime parseDate(String input) {
      try {
        final parts = input.split('-');
        if (parts.length == 3) {
          return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (_) {}
      return DateTime.now();
    }

    final billDate = parseDate(_dateController.text.trim());

    final newBill = BillData(
      id: '',
      billNo: billNo,
      date: billDate,
      subtotal: _subtotal,
      gst: _gst,
      total: _total,
      notes: _notesController.text.trim(),
      items: itemsCopy,
      attachedImageUrl: null,
      attachedImageName: _attachedImageName,
    );

    final tx = SupplierTransaction(
      id: '',
      description: 'Bill $billNo',
      date: billDate,
      amount: _total,
      isPayment: false, // Increases the due (we owe them)
      attachedImageUrl: null,
      attachedImageName: _attachedImageName,
    );

    try {
      await SupplierService().addBill(widget.supplier.id, newBill);
      await SupplierService().addTransaction(widget.supplier.id, tx);

      setState(() {
        // Reset form
        for (final item in _billItems) {
          item.nameController.dispose();
        }
        _billItems.clear();
        _billItems.add(BillItemRow(name: '', quantity: 1, unit: 'kg', rate: 0));
        _notesController.clear();
        _attachedImageBytes = null;
        _attachedImageName = null;
        _gstOverride = null;

        // Increment bill number
        final match = RegExp(r'\d+').firstMatch(_billNoController.text);
        if (match != null) {
          final currentNum = int.tryParse(match.group(0) ?? '') ?? 1026;
          _billNoController.text = _billNoController.text
              .replaceFirst(match.group(0)!, '${currentNum + 1}');
        }

        // Switch to ledger to show the result
        _activeTab = 0;
      });

      widget.onChanged();
      _showSuccessSnackbar('Bill $billNo saved! Due updated in ledger.');
    } catch (e) {
      _showErrorSnackbar('Error saving bill: $e');
    }
  }


  void _showSuccessSnackbar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.positive,
      ),
    );
  }

  void _showErrorSnackbar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[800],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
          source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _attachedImageBytes = bytes;
          _attachedImageName = image.name;
        });
        _showSuccessSnackbar('Bill receipt attached!');
      }
    } catch (e) {
      _showErrorSnackbar('Could not open image gallery.');
    }
  }

  Future<void> _editGst() async {
    final controller = TextEditingController(
        text: (_gstOverride ?? _gst).toStringAsFixed(0));
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enter GST Amount',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
              prefixText: '₹ ', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(-1.0),
            child: const Text('Reset Auto',
                style:
                    TextStyle(fontSize: 16, color: Colors.orange)),
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
                foregroundColor: Colors.white),
            child: const Text('Apply', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        _gstOverride = result < 0 ? null : result;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('suppliers').doc(widget.supplier.id).snapshots(),
      builder: (context, supplierSnapshot) {
        if (!supplierSnapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final s = SupplierData.fromFirestore(supplierSnapshot.data!);
        final initials = s.name.isNotEmpty
            ? s.name[0].toUpperCase()
            : 'S';
        final netDue = s.netDue;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            leadingWidth: 44,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back,
                  size: 24, color: AppTheme.textDark),
              onPressed: () => Navigator.of(context).pop(),
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                // Company Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.deepOrange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: TextStyle(
                        color: Colors.deepOrange[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
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
                              : Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.phone_outlined,
                    size: 22, color: AppTheme.textDark),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.receipt_long,
                    size: 22, color: AppTheme.textDark),
                onPressed: () {},
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(49),
              child: Column(
                children: [
                  const Divider(height: 1, thickness: 1, color: AppTheme.divider),
                  // ── TOP TAB BAR ──
                  Container(
                    color: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _buildTab(0, Icons.account_balance_wallet_outlined,
                            'Ledger'),
                        const SizedBox(width: 12),
                        _buildTab(1, Icons.receipt_long_outlined, 'Add Bill'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: _activeTab == 0 ? _buildLedgerTab(s) : _buildAddBillTab(s),
        );
      },
    );
  }

  // ── Tab Button ─────────────────────────────────────────────────────────────
  Widget _buildTab(int index, IconData icon, String label) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 36,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primary : Colors.grey[300]!,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected ? Colors.white : AppTheme.textDark),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LEDGER TAB
  // ─────────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────
  // LEDGER TAB
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLedgerTab(SupplierData s) {
    return StreamBuilder<List<SupplierTransaction>>(
      stream: SupplierService().getTransactions(s.id),
      builder: (context, snapshot) {
        final transactionsList = snapshot.data ?? [];
        final runningBalances = _calculateRunningBalances(transactionsList);
        final netDue = s.netDue;

        return Column(
          children: [
            // Supplier info card with netDue
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: netDue > 0
                      ? [Colors.red[50]!, Colors.orange[50]!]
                      : [Colors.green[50]!, Colors.teal[50]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: netDue > 0 ? Colors.red[200]! : Colors.green[200]!,
                ),
              ),
              child: Row(
                children: [
                  // Supplier icon
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.storefront,
                        color: AppTheme.textDark, size: 24),
                  ),
                  const SizedBox(width: 12),
                  // Name + phone
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.phone,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  // Due amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹ ${netDue.abs().toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: netDue > 0
                              ? Colors.red[700]
                              : Colors.green[700],
                        ),
                      ),
                      Text(
                        netDue > 0
                            ? 'You Pay'
                            : netDue < 0
                                ? 'Advance'
                                : 'Settled',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: netDue > 0
                              ? Colors.red[400]
                              : Colors.green[400],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Transaction timeline
            Expanded(
              child: transactionsList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          const Text(
                            'No transactions recorded yet',
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                                fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _activeTab = 1),
                            icon: const Icon(Icons.add),
                            label: const Text('Add first bill'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: transactionsList.length,
                      itemBuilder: (context, index) {
                        final tx = transactionsList[index];
                        final balance = runningBalances[index];
                        final isPayment = tx.isPayment; // true=payment(paid), false=bill(owe)

                        // Date header
                        bool showDateHeader = false;
                        final datePart = _formatDateOnly(tx.date);
                        if (index == 0) {
                          showDateHeader = true;
                        } else {
                          final prevDatePart = _formatDateOnly(transactionsList[index - 1].date);
                          if (datePart != prevDatePart) showDateHeader = true;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDateHeader) ...[
                              const SizedBox(height: 8),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.cyan[50],
                                    border: Border.all(
                                        color: Colors.cyan[100]!),
                                    borderRadius:
                                        BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    datePart,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.cyan[800]),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Payment on LEFT, Bill on RIGHT
                            Align(
                              alignment: isPayment
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () => showTransactionDetailSheet(
                                  context,
                                  TxDetail(
                                    amount: tx.amount,
                                    isPayment: isPayment,
                                    description: tx.description,
                                    date: _formatDateTime(tx.date),
                                    runningBalance: balance,
                                    balanceLabel: balance <= 0 ? 'Advance' : 'You Pay',
                                    attachedImageBytes: null,
                                    attachedImageName: tx.attachedImageName,
                                    linkedBillNo: !isPayment && tx.description.contains('BILL')
                                        ? tx.description
                                        : null,
                                    positiveColor: Colors.green,
                                  ),
                                ),
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.sizeOf(context).width *
                                            0.70,
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isPayment
                                        ? Colors.green[50]
                                        : Colors.white,
                                    border: Border.all(
                                      color: isPayment
                                          ? Colors.green[200]!
                                          : Colors.grey[200]!,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 2,
                                          offset: Offset(0, 1)),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isPayment
                                                    ? Icons.arrow_downward
                                                    : Icons.arrow_upward,
                                                color: isPayment
                                                    ? Colors.green[700]
                                                    : Colors.red[700],
                                                size: 18,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '₹ ${tx.amount.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 16),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _formatTimeOnly(tx.date),
                                                style: TextStyle(
                                                    color: Colors.grey[500],
                                                    fontSize: 10),
                                              ),
                                              const SizedBox(width: 2),
                                              Icon(Icons.check,
                                                  size: 12,
                                                  color: Colors.blue[600]),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        tx.description,
                                        style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 13),
                                      ),
                                      if (tx.attachedImageName != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          '📎 ${tx.attachedImageName}',
                                          style: TextStyle(
                                              color: AppTheme.primary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Running balance below bubble
                            Align(
                              alignment: isPayment
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                    top: 4,
                                    bottom: 12,
                                    left: 4,
                                    right: 4),
                                child: Text(
                                  balance <= 0
                                      ? '₹ ${(-balance).toStringAsFixed(0)} Advance'
                                      : '₹ ${balance.toStringAsFixed(0)} Due',
                                  style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),

            // ── Bottom bars ──
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Utility icons row
                Container(
                  color: Colors.grey[200],
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildUtilityIcon(Icons.receipt_long, () {}),
                      const SizedBox(width: 12),
                      _buildUtilityIcon(Icons.sms_outlined, () {}),
                      const SizedBox(width: 12),
                      _buildUtilityIcon(Icons.phone_outlined, () {}),
                      const SizedBox(width: 12),
                      _buildUtilityIcon(Icons.share_outlined, () {}),
                      const Spacer(),
                      InkWell(
                        onTap: () {},
                        child: Row(
                          children: [
                            Text('More',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.grey[700])),
                            const SizedBox(width: 2),
                            Icon(Icons.more_horiz,
                                color: Colors.grey[700], size: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Call / Due Date row
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.teal),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          foregroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        onPressed: () {},
                        icon: const Icon(Icons.calendar_today, size: 14),
                        label: const Text('Bill Date',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final phone = widget.supplier.phone.trim();
                          if (phone.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No phone number saved for this supplier.')),
                            );
                            return;
                          }
                          final uri = Uri.parse('tel:$phone');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          } else {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not launch call to $phone')),
                            );
                          }
                        },
                        icon: const Icon(Icons.phone, size: 14),
                        label: const Text('Call',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

                // Net due row
                Container(
                  color: Colors.grey[100],
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Balance Due',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textMid)),
                      Row(
                        children: [
                          Text(
                            netDue > 0
                                ? '₹ ${netDue.toStringAsFixed(0)} You Pay'
                                : netDue < 0
                                    ? '₹ ${(-netDue).toStringAsFixed(0)} Advance'
                                    : 'Settled',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: netDue > 0
                                  ? Colors.red[700]
                                  : Colors.green[800],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: netDue > 0
                                ? Colors.red[700]
                                : Colors.green[800],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Paid / Bill buttons
                Container(
                  color: Colors.grey[50],
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Row(
                    children: [
                      // Paid (cash paid to supplier)
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => TransactionEntryPage(
                                  title: s.name,
                                  phone: s.phone,
                                  currentDue: netDue,
                                  dueLabel: 'Due',
                                  isPayment: true,
                                  avatarInitial: s.name.isNotEmpty
                                      ? s.name[0].toUpperCase()
                                      : 'S',
                                  avatarColor: Colors.deepOrange[100]!,
                                  onConfirm: (amount, notes, date, imageBytes, imageName) async {
                                    final formattedDesc = notes.isEmpty ? 'Cash paid' : notes;

                                    final tx = SupplierTransaction(
                                      id: '',
                                      description: formattedDesc,
                                      date: date,
                                      amount: amount,
                                      isPayment: true,
                                      attachedImageUrl: null,
                                      attachedImageName: imageName,
                                    );

                                    try {
                                      await SupplierService().addTransaction(s.id, tx);
                                      widget.onChanged();
                                      _showSuccessSnackbar('Transaction recorded successfully!');
                                    } catch (e) {
                                      _showErrorSnackbar('Error recording transaction: $e');
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: Colors.green[500]!, width: 1.5),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 3,
                                    offset: Offset(0, 1)),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_downward,
                                    color: Colors.green[800], size: 20),
                                const SizedBox(width: 6),
                                Text('Paid',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.green[800])),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Bill (credit added – navigate to Add Bill tab)
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _activeTab = 1),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: Colors.red[500]!, width: 1.5),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 3,
                                    offset: Offset(0, 1)),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long,
                                    color: Colors.red[800], size: 20),
                                const SizedBox(width: 6),
                                Text('Add Bill',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.red[800])),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADD BILL TAB
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAddBillTab(SupplierData s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: ADD BILL + NEW BILL
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ADD BILL',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark),
              ),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    for (final item in _billItems) {
                      item.nameController.dispose();
                    }
                    _billItems.clear();
                    _billItems.add(BillItemRow(name: '', quantity: 1, unit: 'kg', rate: 0));
                    _notesController.clear();
                    _attachedImageBytes = null;
                    _attachedImageName = null;
                    _gstOverride = null;

                    _billNoController.text = 'BILL-${DateTime.now().millisecondsSinceEpoch % 10000}';
                    final now = DateTime.now();
                    _dateController.text =
                        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text(
                  'NEW BILL',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Supplier, Bill No, Date row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark),
                        children: [
                          TextSpan(text: 'Supplier'),
                          TextSpan(
                              text: ' *',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: s.id,
                          isExpanded: true,
                          isDense: true,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primary, size: 20),
                          items: [
                            DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name, overflow: TextOverflow.ellipsis),
                            )
                          ],
                          onChanged: (_) {},
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark),
                        children: [
                          TextSpan(text: 'Bill No'),
                          TextSpan(
                              text: ' *',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _billNoController,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          fillColor: Colors.grey[100],
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark),
                        children: [
                          TextSpan(text: 'Date'),
                          TextSpan(
                              text: ' *',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _dateController,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          fillColor: Colors.grey[100],
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Items Table Header
          Row(
            children: [
              const Expanded(
                  flex: 4,
                  child: Text('Item',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textDark))),
              const SizedBox(width: 8),
              const SizedBox(
                  width: 110,
                  child: Text('Qty',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textDark),
                      textAlign: TextAlign.left)),
              const SizedBox(width: 8),
              const SizedBox(
                  width: 65,
                  child: Text('Rate',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textDark),
                      textAlign: TextAlign.center)),
              const SizedBox(width: 8),
              const SizedBox(
                  width: 65,
                  child: Text('Amount',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textDark),
                      textAlign: TextAlign.center)),
              const SizedBox(width: 32),
            ],
          ),
          const Divider(thickness: 1),

          // Item rows
          ..._billItems.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: item.nameController,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      decoration: const InputDecoration(
                        hintText: 'Enter item name',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: Row(
                      children: [
                        // Qty input box
                        Expanded(
                          flex: 5,
                          child: Container(
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: TextFormField(
                              initialValue: item.quantity == 0 ? '' : item.quantity.toStringAsFixed(0),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                              onChanged: (v) {
                                setState(() {
                                  item.quantity = double.tryParse(v) ?? 0;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Unit dropdown box
                        Expanded(
                          flex: 6,
                          child: Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: item.unit,
                                isDense: true,
                                icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 16),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                items: ['kg', 'gr', 'pcs', 'lt', 'box']
                                    .map((u) => DropdownMenuItem(
                                        value: u,
                                        child: Text(u)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => item.unit = v);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 65,
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: TextFormField(
                        initialValue: item.rate == 0 ? '' : item.rate.toStringAsFixed(0),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        onChanged: (v) {
                          setState(() {
                            item.rate = double.tryParse(v) ?? 0;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 65,
                    child: Container(
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.amount.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.delete_outline,
                          color: Colors.red[400], size: 20),
                      onPressed: _billItems.length > 1
                          ? () {
                              setState(() {
                                _billItems[i]
                                    .nameController
                                    .dispose();
                                _billItems.removeAt(i);
                              });
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),

          // Add item button
          OutlinedButton(
            onPressed: () {
              setState(() {
                _billItems.add(BillItemRow(
                    name: '', quantity: 1, unit: 'kg', rate: 0));
              });
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 16, color: AppTheme.primary),
                SizedBox(width: 4),
                Text('ADD ITEM',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Totals Right Aligned
          const Divider(thickness: 1),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 180,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textMid)),
                      Text('${_subtotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: _editGst,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('GST (5%)',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textMid)),
                            const SizedBox(width: 4),
                            Icon(Icons.edit_outlined,
                                size: 12, color: AppTheme.primary),
                          ],
                        ),
                        Text(
                          '${_gst.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _gstOverride != null
                                  ? Colors.orange
                                  : AppTheme.textDark),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Divider(thickness: 1.5, color: AppTheme.textDark),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark)),
                      Text(
                        '${_total.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Notes
          const Text('Notes',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Add notes (optional)',
              fillColor: Colors.grey[100],
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 16),

          // Attachment photo picker
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppTheme.primary, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(8),
                color: Colors.blue[50],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _attachedImageBytes != null
                        ? '📎 ${_attachedImageName ?? 'receipt.jpg'}'
                        : 'Attach Bill Receipt Photo',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons: Save Bill, Save & Print, Cancel
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _saveBill,
                    child: const Text('SAVE BILL',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      foregroundColor: AppTheme.primary,
                    ),
                    onPressed: () {
                      _saveBill();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Printing bill...'), backgroundColor: AppTheme.primary),
                      );
                    },
                    child: const Text('SAVE & PRINT',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red[400]!),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      foregroundColor: Colors.red[600],
                    ),
                    onPressed: () => setState(() => _activeTab = 0),
                    child: const Text('CANCEL',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark)),
      ],
    );
  }

  Widget _buildUtilityIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.grey[700], size: 18),
      ),
    );
  }

  // ── Transaction Overlay ────────────────────────────────────────────────────
  Widget _buildTransactionOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _isOverlayOpen = false),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black54,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _overlayIsPayment
                            ? 'Record Payment (Paid to Supplier)'
                            : 'Record Bill Amount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _overlayIsPayment
                              ? Colors.green[800]
                              : Colors.red[800],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            setState(() => _isOverlayOpen = false),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Amount (₹) *',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Enter amount',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Description / Notes',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Cash paid, Bank transfer',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: AppTheme.primary),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(6)),
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: () =>
                              setState(() => _isOverlayOpen = false),
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
                            backgroundColor: _overlayIsPayment
                                ? Colors.green[600]
                                : Colors.red[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(6)),
                            minimumSize: const Size(0, 48),
                            elevation: 0,
                          ),
                          onPressed: _saveLedgerTransaction,
                          child: const Text('SAVE',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold)),
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
