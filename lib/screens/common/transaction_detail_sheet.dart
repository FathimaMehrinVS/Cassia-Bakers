import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/core.dart';

/// Generic transaction detail model – works for Supplier, Customer and Staff.
class TxDetail {
  final double amount;
  final bool isPayment;
  final String description;
  final String date; // full "DD Mon YYYY at HH:MM AM/PM" string
  final double runningBalance;
  final String balanceLabel; // e.g. "Due", "Advance", "Salary Due"
  final Uint8List? attachedImageBytes;
  final String? attachedImageName;
  /// For supplier bill transactions – the linked bill number, if any.
  final String? linkedBillNo;
  /// Colour context: the "positive" colour for this ledger type.
  final Color positiveColor;

  const TxDetail({
    required this.amount,
    required this.isPayment,
    required this.description,
    required this.date,
    required this.runningBalance,
    required this.balanceLabel,
    this.attachedImageBytes,
    this.attachedImageName,
    this.linkedBillNo,
    this.positiveColor = Colors.green,
  });
}

/// Call this to show a modal bottom-sheet with full transaction details.
void showTransactionDetailSheet(BuildContext context, TxDetail tx) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TransactionDetailSheet(tx: tx),
  );
}

class _TransactionDetailSheet extends StatelessWidget {
  final TxDetail tx;
  const _TransactionDetailSheet({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isPositive = tx.isPayment;
    final accentColor = isPositive ? tx.positiveColor : Colors.red[700]!;
    final bgColor = isPositive ? Color(0xFFE8F5E9) : Color(0xFFFFEBEE);
    final typeLabel = isPositive ? 'Payment Made' : 'Amount Added';
    final parts = tx.date.split(' at ');
    final datePart = parts.isNotEmpty ? parts[0] : tx.date;
    final timePart = parts.length > 1 ? parts[1] : '';

    return DraggableScrollableSheet(
      initialChildSize: 0.60,
      minChildSize: 0.40,
      maxChildSize: 0.90,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Header banner
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accentColor.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    // Type icon circle
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: accentColor.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: accentColor, size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹ ${tx.amount % 1 == 0 ? tx.amount.toStringAsFixed(0) : tx.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Balance chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accentColor.withAlpha(80)),
                      ),
                      child: Text(
                        tx.runningBalance <= 0
                            ? 'Settled'
                            : '₹${tx.runningBalance.toStringAsFixed(0)}\n${tx.balanceLabel}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),

              // Details list
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    // Date & Time
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      iconColor: Colors.teal,
                      label: 'Date',
                      value: datePart,
                    ),
                    if (timePart.isNotEmpty)
                      _DetailRow(
                        icon: Icons.access_time_outlined,
                        iconColor: Colors.indigo,
                        label: 'Time',
                        value: timePart,
                      ),
                    const SizedBox(height: 4),

                    // Notes / Description
                    _DetailRow(
                      icon: Icons.notes_outlined,
                      iconColor: Colors.orange[700]!,
                      label: 'Notes',
                      value: tx.description.isEmpty ? '—' : tx.description,
                    ),

                    // Linked bill
                    if (tx.linkedBillNo != null) ...[
                      const SizedBox(height: 4),
                      _DetailRow(
                        icon: Icons.receipt_long_outlined,
                        iconColor: Colors.purple,
                        label: 'Bill No',
                        value: tx.linkedBillNo!,
                      ),
                    ],

                    // Attachment
                    if (tx.attachedImageBytes != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.attach_file, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            tx.attachedImageName ?? 'Attachment',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Full-width image with rounded corners
                      GestureDetector(
                        onTap: () => _showFullImage(context, tx.attachedImageBytes!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            tx.attachedImageBytes!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'Tap image to expand',
                          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Balance summary card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Balance after this entry',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                          Text(
                            tx.runningBalance <= 0
                                ? 'Settled / Advance'
                                : '₹ ${tx.runningBalance.toStringAsFixed(0)} ${tx.balanceLabel}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: tx.runningBalance <= 0
                                  ? Colors.green[700]
                                  : Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Close button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFullImage(BuildContext context, Uint8List bytes) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8, right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
