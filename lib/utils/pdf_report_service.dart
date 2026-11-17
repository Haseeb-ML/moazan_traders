import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/ledger_provider.dart';
import '../theme/app_theme.dart';
import 'web_download_stub.dart'
    if (dart.library.js_interop) 'web_download_web.dart';

class PdfReportService {
  static final NumberFormat _amountFmt = NumberFormat('#,##0.00', 'en_US');

  /// Builds the "Dealer Balance" PDF matching the client's printed ledger format:
  /// Dealer Code | Name of Dealer | Debit Balance | Credit Balance + Totals.
  static Future<Uint8List> buildAllDealersBalancePdf(
    List<DealerSummary> summaries,
  ) async {
    final sorted = List<DealerSummary>.from(summaries)
      ..sort((a, b) => a.dealer.code.compareTo(b.dealer.code));

    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final timeStr = DateFormat('HH:mm:ss').format(now);

    double totalDebitBal = 0;
    double totalCreditBal = 0;
    for (final s in sorted) {
      if (s.balance > 0) {
        totalDebitBal += s.balance;
      } else if (s.balance < 0) {
        totalCreditBal += s.balance.abs();
      }
    }

    final doc = pw.Document(
      title: 'Dealer Balance - Moazan Traders Kamoke',
      author: 'Moazan Traders Kamoke',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(
                'Moazan Traders - Kamoke',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Dealer Balance',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '$dateStr    $timeStr',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1, height: 1),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            border: const pw.TableBorder(
              bottom: pw.BorderSide(width: 0.8),
              horizontalInside: pw.BorderSide(
                color: PdfColors.grey300,
                width: 0.4,
              ),
            ),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9.5,
            ),
            headerDecoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: 1),
              ),
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(72),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(95),
              3: const pw.FixedColumnWidth(95),
            },
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            headers: [
              'Dealer Code',
              'Name of Dealer',
              'Debit Balance',
              'Credit Balance',
            ],
            data: [
              for (final s in sorted)
                [
                  s.dealer.code,
                  s.dealer.name,
                  _amountFmt.format(s.balance > 0 ? s.balance : 0),
                  _amountFmt.format(s.balance < 0 ? s.balance.abs() : 0),
                ],
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(width: 1.2),
                bottom: pw.BorderSide(width: 1.2),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 72,
                  child: pw.Text(
                    'Total',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(
                    '${sorted.length} Dealers',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9.5,
                    ),
                  ),
                ),
                pw.SizedBox(
                  width: 95,
                  child: pw.Text(
                    _amountFmt.format(totalDebitBal),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                pw.SizedBox(
                  width: 95,
                  child: pw.Text(
                    _amountFmt.format(totalCreditBal),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static Future<void> openAllDealersBalancePdf(
    BuildContext context,
    List<DealerSummary> summaries,
  ) async {
    final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final filename = 'Moazan_Traders_Dealer_Balance_$stamp.pdf';

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DealerBalancePdfPreviewScreen(
          filename: filename,
          summaries: summaries,
        ),
      ),
    );
  }
}

class _DealerBalancePdfPreviewScreen extends StatefulWidget {
  final String filename;
  final List<DealerSummary> summaries;

  const _DealerBalancePdfPreviewScreen({
    required this.filename,
    required this.summaries,
  });

  @override
  State<_DealerBalancePdfPreviewScreen> createState() =>
      _DealerBalancePdfPreviewScreenState();
}

class _DealerBalancePdfPreviewScreenState
    extends State<_DealerBalancePdfPreviewScreen> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final bytes =
          await PdfReportService.buildAllDealersBalancePdf(widget.summaries);
      if (!mounted) return;
      await downloadBytesFile(
        context,
        filename: widget.filename,
        bytes: bytes,
        mimeType: 'application/pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dealer Balance PDF'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: _downloading ? null : _download,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download PDF'),
            ),
          ),
        ],
      ),
      body: PdfPreview(
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: widget.filename,
        build: (_) =>
            PdfReportService.buildAllDealersBalancePdf(widget.summaries),
      ),
    );
  }
}
