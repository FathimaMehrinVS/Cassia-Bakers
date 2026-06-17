import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/invoice_record.dart';
import '../../core/services/invoice_service.dart';

class InvoiceHistoryPage extends StatefulWidget {
  const InvoiceHistoryPage({super.key});

  @override
  State<InvoiceHistoryPage> createState() => _InvoiceHistoryPageState();
}

class _InvoiceHistoryPageState extends State<InvoiceHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isDownloading = false;
  String? _downloadingBillNo;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _viewInvoicePdf(InvoiceRecord record) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadingBillNo = record.billNo;
    });

    try {
      final pdfBytes = await InvoiceService().downloadPdf(record.pdfUrl);
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Invoice_${record.billNo}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load PDF: $e'),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadingBillNo = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Invoice History'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by Bill No, date, or items...',
                hintStyle: const TextStyle(color: AppTheme.textSub, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textMid),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.cardBg.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Invoice List
          Expanded(
            child: StreamBuilder<List<InvoiceRecord>>(
              stream: InvoiceService().getInvoicesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red[800]),
                        const SizedBox(height: 12),
                        Text(
                          'Error loading invoices: ${snapshot.error}',
                          style: const TextStyle(color: AppTheme.textMid, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                final invoices = snapshot.data ?? [];
                if (invoices.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Invoices Yet',
                    subtitle: 'Generated bills will appear here in reverse chronological order.',
                  );
                }

                // Filter invoices
                final filtered = invoices.where((inv) {
                  if (_searchQuery.isEmpty) return true;

                  // Match bill number
                  if (inv.billNo.toLowerCase().contains(_searchQuery)) return true;

                  // Match date
                  if (inv.date.toLowerCase().contains(_searchQuery)) return true;

                  // Match item names
                  for (final item in inv.items) {
                    final name = item['name'] as String? ?? '';
                    if (name.toLowerCase().contains(_searchQuery)) return true;
                  }

                  return false;
                }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.search_off_outlined,
                    title: 'No Matching Invoices',
                    subtitle: 'Try searching by a different bill number or item name.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final record = filtered[index];
                    final isThisDownloading = _isDownloading && _downloadingBillNo == record.billNo;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.divider, width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _viewInvoicePdf(record),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // Circular Receipt Icon with subtle gradient
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.primary.withValues(alpha: 0.15),
                                        AppTheme.primary.withValues(alpha: 0.05),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long,
                                    color: AppTheme.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Metadata
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bill No: ${record.billNo}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${record.date} at ${record.time}',
                                        style: const TextStyle(
                                          color: AppTheme.textMid,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${record.items.length} ${record.items.length == 1 ? "item" : "items"}',
                                        style: const TextStyle(
                                          color: AppTheme.textSub,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Price tag and action indicator
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '₹${record.total.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    isThisDownloading
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.chevron_right,
                                            color: AppTheme.textSub,
                                            size: 20,
                                          ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: AppTheme.textSub),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textMid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
