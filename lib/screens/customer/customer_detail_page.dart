import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/core.dart';
import '../../core/models/customer.dart';
import '../../core/services/customer_service.dart';
import '../common/transaction_entry_page.dart';
import '../common/transaction_detail_sheet.dart';

class CustomerDetailPage extends StatefulWidget {
  final CustomerData customer;
  final VoidCallback onChanged;

  const CustomerDetailPage({
    super.key,
    required this.customer,
    required this.onChanged,
  });

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  final CustomerService _customerService = CustomerService();

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
  List<double> _calculateRunningBalances(List<CustomerDueTransaction> transactions) {
    final balances = <double>[];
    double current = 0.0;
    for (final tx in transactions) {
      if (tx.isPayment) {
        current -= tx.amount;
      } else {
        current += tx.amount;
      }
      balances.add(current);
    }
    return balances;
  }

  void _navigateToEntry({required bool isPayment}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TransactionEntryPage(
          title: widget.customer.name,
          phone: widget.customer.phone,
          currentDue: widget.customer.netDue,
          dueLabel: 'Due',
          isPayment: isPayment,
          avatarInitial: widget.customer.name.isNotEmpty
              ? widget.customer.name[0].toUpperCase()
              : 'C',
          avatarColor: Colors.orange[300]!,
          onConfirm: (amount, notes, date, imageBytes, imageName) async {
            final formattedDesc = notes.isEmpty
                ? (isPayment ? 'Cash received' : 'Items on credit')
                : notes;

            final tx = CustomerDueTransaction(
              id: '',
              description: formattedDesc,
              date: date,
              amount: amount,
              isPayment: isPayment,
              attachedImageUrl: null,
              attachedImageName: imageName,
            );

            try {
              await _customerService.addTransaction(widget.customer.id, tx);
              widget.onChanged();
              _showSuccessSnackbar('Transaction recorded successfully!');
            } catch (e) {
              _showErrorSnackbar('Failed to save transaction. Please try again.');
            }
          },
        ),
      ),
    );
  }

  void _showSuccessSnackbar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.positive,
      ),
    );
  }

  void _showErrorSnackbar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[800],
      ),
    );
  }

  // ── Build Method ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final initials = widget.customer.name.isNotEmpty ? widget.customer.name[0].toUpperCase() : 'C';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leadingWidth: 44,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 24, color: AppTheme.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            // Circular Avatar with Status Badge
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.orange[300],
                  child: Text(
                    initials,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.check, size: 9, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            // Name & Profile Clickable Subtext
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.customer.name} (${widget.customer.phone.replaceAll('+91 ', '')})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'View Profile',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long, size: 24, color: AppTheme.textDark),
            tooltip: 'Statement',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 24, color: AppTheme.textDark),
            tooltip: 'Search Ledger',
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.divider),
        ),
      ),
      body: StreamBuilder<List<CustomerDueTransaction>>(
        stream: _customerService.getTransactions(widget.customer.id),
        builder: (context, snapshot) {
          final transactions = snapshot.data ?? [];
          final runningBalances = _calculateRunningBalances(transactions);

          return Stack(
            children: [
              // ── Timeline & Scrollable Content ──
              Column(
                children: [
                  Expanded(
                    child: transactions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                const Text(
                                  'No transactions recorded yet',
                                  style: TextStyle(color: Colors.grey, fontSize: 14, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            itemCount: transactions.length,
                            itemBuilder: (context, index) {
                              final tx = transactions[index];
                              final balance = runningBalances[index];
                              final isPayment = tx.isPayment;

                              // Show Date badge for the first transaction or if date changes
                              bool showDateHeader = false;
                              final datePart = _formatDateOnly(tx.date);
                              if (index == 0) {
                                showDateHeader = true;
                              } else {
                                final prevDatePart = _formatDateOnly(transactions[index - 1].date);
                                if (datePart != prevDatePart) {
                                  showDateHeader = true;
                                }
                              }

                              // Build the formatted full date string for TxDetail
                              final formattedFullDate = _formatDateTime(tx.date);
                              final timeStr = _formatTimeOnly(tx.date);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (showDateHeader) ...[
                                    const SizedBox(height: 8),
                                    Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.cyan[50],
                                          border: Border.all(color: Colors.cyan[100]!),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          datePart,
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.cyan[800]),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  // Chat Bubble Container
                                  Align(
                                    alignment: isPayment ? Alignment.centerLeft : Alignment.centerRight,
                                    child: GestureDetector(
                                      onTap: () => showTransactionDetailSheet(
                                        context,
                                        TxDetail(
                                          amount: tx.amount,
                                          isPayment: isPayment,
                                          description: tx.description,
                                          date: formattedFullDate,
                                          runningBalance: balance,
                                          balanceLabel: balance < 0 ? 'Advance' : 'Due',
                                          attachedImageBytes: null,
                                          attachedImageName: tx.attachedImageName,
                                          positiveColor: Colors.green,
                                        ),
                                      ),
                                      child: Container(
                                        constraints: BoxConstraints(
                                          maxWidth: MediaQuery.sizeOf(context).width * 0.70,
                                        ),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(color: Colors.grey[200]!, width: 1.5),
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: const [
                                            BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isPayment ? Icons.arrow_downward : Icons.arrow_upward,
                                                      color: isPayment ? Colors.green[800] : Colors.red,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '₹ ${tx.amount.toStringAsFixed(0)}',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(width: 16),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      timeStr,
                                                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Icon(Icons.check, size: 12, color: Colors.blue[600]),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              tx.description,
                                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                            ),
                                            // Note: attachedImageUrl support (network image) can be added here if needed.
                                            // attachedImageBytes is no longer available (model uses URL now).
                                            if (tx.attachedImageName != null) ...[
                                              const SizedBox(height: 4),
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

                                  // Under-bubble Running balance indicator
                                  Align(
                                    alignment: isPayment ? Alignment.centerLeft : Alignment.centerRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4, bottom: 12, left: 4, right: 4),
                                      child: Text(
                                        balance < 0
                                            ? '₹ ${(-balance).toStringAsFixed(0)} Advance'
                                            : '₹ ${balance.toStringAsFixed(0)} Due',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),

                  // ── BOTTOM BARS STACK ──
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(height: 1, thickness: 1, color: AppTheme.divider),
                      // Row 1: circular utility options bar
                      Container(
                        color: Colors.grey[200],
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                  Text('More', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[700])),
                                  const SizedBox(width: 2),
                                  Icon(Icons.more_horiz, color: Colors.grey[700], size: 20),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Row 2: Call / Remind / Due Date bar
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            // Due date pill button
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.teal),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                foregroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: () {},
                              icon: const Icon(Icons.calendar_today, size: 14),
                              label: const Text('Due Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            const Spacer(),
                            // Call button
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[800],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                elevation: 0,
                              ),
                              onPressed: () async {
                                final phone = widget.customer.phone.trim();
                                if (phone.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('No phone number saved for this customer.')),
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
                              label: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            // Remind button
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[800],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                elevation: 0,
                              ),
                              onPressed: () => _showSmsReminder(
                                context,
                                phone: widget.customer.phone,
                                name: widget.customer.name,
                                dueAmount: widget.customer.netDue,
                                label: 'customer',
                              ),
                              icon: const Icon(Icons.message, size: 14),
                              label: const Text('Remind', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),

                      // Row 3: Net Outstanding Balance due row
                      Container(
                        color: Colors.grey[100],
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Balance Due',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textMid),
                            ),
                            Row(
                              children: [
                                Text(
                                  '₹ ${widget.customer.netDue.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: widget.customer.netDue > 0 ? Colors.red : Colors.green[800],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 12,
                                  color: widget.customer.netDue > 0 ? Colors.red : Colors.green[800],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Row 4: Primary Action Received & Given Buttons
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
                            // Received Button (Left)
                            Expanded(
                              child: InkWell(
                                onTap: () => _navigateToEntry(isPayment: true),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: Colors.green[500]!, width: 1.5),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_downward, color: Colors.green[800], size: 20),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Received',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green[800]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Given Button (Right)
                            Expanded(
                              child: InkWell(
                                onTap: () => _navigateToEntry(isPayment: false),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: Colors.red[500]!, width: 1.5),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_upward, color: Colors.red[800], size: 20),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Given',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red[800]),
                                      ),
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
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── SMS Reminder ──────────────────────────────────────────────────────────
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
              Text(
                'To: $phone',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              const Text(
                'Message (editable):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
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
