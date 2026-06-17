import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/invoice_record.dart';

class InvoiceService {
  final CollectionReference _invoicesCollection =
      FirebaseFirestore.instance.collection('invoices');
  final CollectionReference _ordersCollection =
      FirebaseFirestore.instance.collection('orders');

  /// Saves invoice metadata in Firestore (does not upload PDF to Storage anymore)
  Future<void> saveInvoice(InvoiceRecord record, Uint8List pdfBytes) async {
    // Save metadata to Firestore under collection 'invoices' with billNo as doc ID
    final updatedRecord = InvoiceRecord(
      billNo: record.billNo,
      date: record.date,
      time: record.time,
      subtotal: record.subtotal,
      discount: record.discount,
      gst: record.gst,
      total: record.total,
      pdfUrl: '', // Storage upload is disabled
      createdAt: record.createdAt,
      items: record.items,
    );

    await _invoicesCollection.doc(record.billNo).set(updatedRecord.toFirestore());
  }

  /// Returns a stream of past invoices ordered by creation date descending
  Stream<List<InvoiceRecord>> getInvoicesStream() {
    return _invoicesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => InvoiceRecord.fromFirestore(doc))
          .toList();
    });
  }

  /// Generates the invoice PDF on-the-fly from the stored record details
  Future<Uint8List> generateInvoicePdf(InvoiceRecord record) async {
    final pdf = pw.Document();
    
    // Load the real Cassia Bakers logo from assets
    final logoData = await rootBundle.load('assets/images/cassia_logo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Container(
              width: 390,
              constraints: const pw.BoxConstraints(minHeight: 540),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 2.2),
              ),
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Image(
                        logoImage,
                        width: 72,
                        height: 72,
                        fit: pw.BoxFit.contain,
                      ),
                      pw.SizedBox(width: 16),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              'Cassia Bakers',
                              style: pw.TextStyle(
                                fontSize: 26,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'The Art of Baking',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontStyle: pw.FontStyle.italic,
                                color: PdfColors.black,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Aluva , Kerala',
                              style: const pw.TextStyle(
                                fontSize: 11,
                                color: PdfColors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 72), // balance for centering
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  // ── Metadata ─────────────────────────────────────────────
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Bill No: ${record.billNo}', style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                      pw.Text('Date: ${record.date}', style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                      pw.Text('Time : ${record.time}', style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 2.0, color: PdfColors.black),
                  pw.SizedBox(height: 6),
                  // ── Items Table ───────────────────────────────────────────
                  pw.Table(
                    columnWidths: const {
                      0: pw.FlexColumnWidth(3.2),
                      1: pw.FlexColumnWidth(1.0),
                      2: pw.FlexColumnWidth(1.2),
                      3: pw.FlexColumnWidth(1.2),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                          ),
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.black)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.black)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.black)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Text('Amt', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.black)),
                          ),
                        ],
                      ),
                      ...record.items.map((item) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6),
                            child: pw.Text('${item['name']} (${item['size'] ?? 'Standard'})', style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6),
                            child: pw.Text('${item['quantity'] ?? item['qty']}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6),
                            child: pw.Text((item['rate'] as num? ?? 0.0).toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6),
                            child: pw.Text((item['amount'] as num? ?? 0.0).toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                          ),
                        ],
                      )),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 2.0, color: PdfColors.black),
                  pw.SizedBox(height: 8),
                  // ── Totals ────────────────────────────────────────────────
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Subtotal', style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                        pw.Text(record.subtotal.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Discount', style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                        pw.Text(record.discount.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('GST', style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                        pw.Text(record.gst.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(thickness: 2.0, color: PdfColors.black),
                  pw.SizedBox(height: 8),
                  // ── TOTAL ─────────────────────────────────────────────────
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'TOTAL',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.black),
                        ),
                        pw.Text(
                          record.total.toStringAsFixed(0),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.black),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 1.2, color: PdfColors.black),
                  pw.SizedBox(height: 8),
                  // ── Thank You Footer ──────────────────────────────────────
                  pw.Center(
                    child: pw.Text(
                      'Thank you for choosing Cassia Bakers!',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColor.fromHex('#C8960C'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return pdf.save();
  }

  /// Calculates the next unique bill number by checking the maximum bill number
  /// present in both 'orders' and 'invoices' collections.
  Future<String> getNextBillNumber() async {
    // Check orders
    final orderQuery = await _ordersCollection
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    // Check invoices
    final invoiceQuery = await _invoicesCollection
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    int maxBillNum = 1024; // Baseline starting from 1025

    if (orderQuery.docs.isNotEmpty) {
      final billNoStr = orderQuery.docs.first.data() != null
          ? (orderQuery.docs.first.data() as Map<String, dynamic>)['billNo'] as String?
          : null;
      if (billNoStr != null) {
        final val = int.tryParse(billNoStr);
        if (val != null && val > maxBillNum) {
          maxBillNum = val;
        }
      }
    }

    if (invoiceQuery.docs.isNotEmpty) {
      final billNoStr = invoiceQuery.docs.first.id;
      final val = int.tryParse(billNoStr);
      if (val != null && val > maxBillNum) {
        maxBillNum = val;
      }
    }

    return (maxBillNum + 1).toString();
  }
}
