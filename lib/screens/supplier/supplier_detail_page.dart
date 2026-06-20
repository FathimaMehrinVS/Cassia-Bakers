import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/core.dart';
import '../../core/models/supplier.dart';
import '../../core/services/supplier_service.dart';
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

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
              const SizedBox(width: 4),
            ],
          ),
          body: _buildLedgerTab(s),
        );
      },
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
                const Divider(height: 1, thickness: 1, color: AppTheme.divider),
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
                      const SizedBox(width: 8),
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
                        onPressed: () => _showSmsReminder(
                          context,
                          phone: widget.supplier.phone,
                          name: widget.supplier.name,
                          dueAmount: widget.supplier.netDue,
                          label: 'supplier',
                        ),
                        icon: const Icon(Icons.message, size: 14),
                        label: const Text('Remind',
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
                  padding: EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
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
                      // Purchase / Bill (credit added – launch TransactionEntryPage with isPayment: false)
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
                                  isPayment: false,
                                  avatarInitial: s.name.isNotEmpty
                                      ? s.name[0].toUpperCase()
                                      : 'S',
                                  avatarColor: Colors.deepOrange[100]!,
                                  onConfirm: (amount, notes, date, imageBytes, imageName) async {
                                    final formattedDesc = notes.isEmpty ? 'Purchase / Bill' : notes;

                                    final tx = SupplierTransaction(
                                      id: '',
                                      description: formattedDesc,
                                      date: date,
                                      amount: amount,
                                      isPayment: false,
                                      attachedImageUrl: null,
                                      attachedImageName: imageName,
                                    );

                                    try {
                                      await SupplierService().addTransaction(s.id, tx);
                                      widget.onChanged();
                                      _showSuccessSnackbar('Purchase recorded successfully!');
                                    } catch (e) {
                                      _showErrorSnackbar('Error recording purchase: $e');
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
                                Text('Purchase',
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

  // ─── SMS Reminder ─────────────────────────────────────────────────────
  Future<void> _showSmsReminder(
    BuildContext ctx, {
    required String phone,
    required String name,
    required double dueAmount,
    required String label,
  }) async {
    if (phone.trim().isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('No phone number saved for this $label.')),
      );
      return;
    }
    final defaultMsg =
        'Hello $name, this is a reminder from Cassia Bakers. '
        'You have an outstanding due of ₹${dueAmount.toStringAsFixed(0)}. '
        'Kindly clear the balance at your earliest convenience. Thank you!';
    final controller = TextEditingController(text: defaultMsg);
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.sms, color: Colors.green),
            const SizedBox(width: 8),
            Text('Remind $name'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('To: $phone', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              const Text('Message (editable):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('SEND SMS'),
            onPressed: () => Navigator.pop(dCtx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final msg = Uri.encodeComponent(controller.text.trim());
    final smsUri = Uri.parse('sms:${phone.trim()}?body=$msg');
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Could not open SMS app.')),
      );
    }
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
}
