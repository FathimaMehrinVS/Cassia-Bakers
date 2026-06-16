import 'package:flutter/material.dart';
import '../../core/core.dart';
import 'staff_page.dart';
import '../common/transaction_entry_page.dart';
import '../common/transaction_detail_sheet.dart';

class StaffDetailPage extends StatefulWidget {
  final StaffData staff;
  final VoidCallback onChanged;

  const StaffDetailPage({
    super.key,
    required this.staff,
    required this.onChanged,
  });

  @override
  State<StaffDetailPage> createState() => _StaffDetailPageState();
}

class _StaffDetailPageState extends State<StaffDetailPage> {
  // ── Calculation Helpers ────────────────────────────────────────────────────
  List<double> _calculateRunningBalances() {
    final balances = <double>[];
    double current = 0.0;
    for (final tx in widget.staff.transactions) {
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
          title: widget.staff.name,
          phone: widget.staff.phone,
          currentDue: widget.staff.balance,
          dueLabel: 'Salary Due',
          isPayment: isPayment,
          avatarInitial: widget.staff.name.isNotEmpty
              ? widget.staff.name[0].toUpperCase()
              : 'S',
          avatarColor: Colors.indigo[300]!,
          onConfirm: (amount, notes, date, imageBytes, imageName) {
            final now = DateTime.now();
            final timeStr =
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
            final dateStr = '${date.day} ${_getMonthName(date.month)} ${date.year}';
            final formattedDesc = notes.isEmpty
                ? (isPayment ? 'Salary paid' : 'Monthly salary')
                : notes;
            setState(() {
              widget.staff.transactions.add(StaffTransaction(
                description: formattedDesc,
                date: '$dateStr at $timeStr',
                amount: amount,
                isPayment: isPayment,
                attachedImageBytes: imageBytes,
                attachedImageName: imageName,
              ));
            });
            widget.onChanged();
            _showSuccessSnackbar('Transaction recorded successfully!');
          },
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return 'Jun';
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
    final runningBalances = _calculateRunningBalances();
    final initials = widget.staff.name.isNotEmpty ? widget.staff.name[0].toUpperCase() : 'S';

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
                    '${widget.staff.name} (${widget.staff.phone.replaceAll('+91 ', '')})',
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
            tooltip: 'Salary Statement',
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
      body: Stack(
        children: [
          // ── Timeline & Scrollable Content ──
          Column(
            children: [
              Expanded(
                child: widget.staff.transactions.isEmpty
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
                        itemCount: widget.staff.transactions.length,
                        itemBuilder: (context, index) {
                          final tx = widget.staff.transactions[index];
                          final balance = runningBalances[index];
                          final isPayment = tx.isPayment;

                          // Show Date badge for the first transaction or if date changes
                          bool showDateHeader = false;
                          final datePart = tx.date.split(' at ')[0];
                          if (index == 0) {
                            showDateHeader = true;
                          } else {
                            final prevDatePart = widget.staff.transactions[index - 1].date.split(' at ')[0];
                            if (datePart != prevDatePart) {
                              showDateHeader = true;
                            }
                          }

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

                              // Chat Bubble Container (Payments on left, Salary credits on right)
                              Align(
                                alignment: isPayment ? Alignment.centerLeft : Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () => showTransactionDetailSheet(
                                    context,
                                    TxDetail(
                                      amount: tx.amount,
                                      isPayment: isPayment,
                                      description: tx.description,
                                      date: tx.date,
                                      runningBalance: balance,
                                      balanceLabel: balance < 0 ? 'Advance' : 'Salary Due',
                                      attachedImageBytes: tx.attachedImageBytes,
                                      attachedImageName: tx.attachedImageName,
                                      positiveColor: Colors.indigo,
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
                                                  tx.date.contains(' at ') ? tx.date.split(' at ')[1] : '',
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
                                        if (tx.attachedImageBytes != null) ...[
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: Image.memory(
                                              tx.attachedImageBytes!,
                                              height: 100,
                                              width: 150,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '📎 ${tx.attachedImageName ?? "photo.jpg"}',
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
                                        : '₹ ${balance.toStringAsFixed(0)} Salary Due',
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

                  // Row 2: Salary Date & Call shortcuts
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        // Salary date pill button
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.teal),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            foregroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: () {},
                          icon: const Icon(Icons.calendar_today, size: 14),
                          label: const Text('Salary Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                          onPressed: () {},
                          icon: const Icon(Icons.phone, size: 14),
                          label: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                          'Salary Outstanding',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textMid),
                        ),
                        Row(
                          children: [
                            Text(
                              widget.staff.balance >= 0
                                  ? '₹ ${widget.staff.balance.toStringAsFixed(0)} Salary Due'
                                  : '₹ ${(-widget.staff.balance).toStringAsFixed(0)} Advance',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: widget.staff.balance >= 0 ? Colors.green[800] : Colors.blue[800],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: widget.staff.balance >= 0 ? Colors.green[800] : Colors.blue[800],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Row 4: Primary Action Received & Given Buttons
                  Container(
                    color: Colors.grey[50],
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Row(
                      children: [
                        // Paid Button (Left)
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
                                    'Paid',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green[800]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Salary Button (Right)
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
                                    'Salary',
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
      ),
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

}

