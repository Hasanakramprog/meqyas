import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class QrLabelPdfGenerator {
  /// Generates an A4 sheet of adhesive QR labels (3 columns x 8 rows = 24 labels/page).
  static Future<Uint8List> generate({
    required String projectName,
    required String projectId,
    required OptimizationResult result,
  }) async {
    final pdf = pw.Document();

    // Load Arabic Font
    pw.Font fontRegular;
    pw.Font fontBold;
    try {
      final regData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      fontRegular = pw.Font.ttf(regData);
      fontBold = pw.Font.ttf(boldData);
    } catch (_) {
      fontRegular = await PdfGoogleFonts.cairoRegular();
      fontBold = await PdfGoogleFonts.cairoBold();
    }

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    // Flatten all cuts across all bars
    final allCuts = <_LabelData>[];
    for (final bar in result.barPlans) {
      for (final cut in bar.cuts) {
        allCuts.add(
          _LabelData(
            barNumber: bar.barNumber,
            isFromRemnant: bar.isFromRemnant,
            itemCode: bar.itemCode,
            cut: cut,
          ),
        );
      }
    }

    // Chunk into pages of 24 labels (3 x 8)
    const labelsPerPage = 24;
    for (var i = 0; i < allCuts.length; i += labelsPerPage) {
      final end = (i + labelsPerPage < allCuts.length) ? i + labelsPerPage : allCuts.length;
      final pageCuts = allCuts.sublist(i, end);

      pdf.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            theme: theme,
            textDirection: pw.TextDirection.rtl,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          build: (context) {
            return pw.GridView(
              crossAxisCount: 3,
              childAspectRatio: 1.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: pageCuts.map((item) {
                return _buildLabel(item, projectName, projectId);
              }).toList(),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildLabel(
    _LabelData item,
    String projectName,
    String projectId,
  ) {
    final qrData = jsonEncode({
      'v': 1,
      'p': projectId,
      'u': item.cut.unitTag ?? '',
      'i': item.itemCode,
      'n': item.cut.nameArabic,
      'l': item.cut.lengthCm,
      'b': item.barNumber,
      'r': item.isFromRemnant,
    });

    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: item.isFromRemnant ? PdfColors.purple50 : PdfColors.white,
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Text Details
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Top Tag: Project & Unit
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        item.cut.unitTag?.isNotEmpty == true
                            ? item.cut.unitTag!
                            : projectName,
                        maxLines: 1,
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                      ),
                    ),
                    pw.Text(
                      'قضيب #${item.barNumber}',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: item.isFromRemnant ? PdfColors.purple800 : PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
                // Piece Name
                pw.Text(
                  item.cut.nameArabic,
                  maxLines: 1,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                // Big Length
                pw.Row(
                  children: [
                    pw.Text(
                      '${item.cut.lengthCm}',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.amber900,
                      ),
                    ),
                    pw.SizedBox(width: 2),
                    pw.Text('سم', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                    if (item.isFromRemnant) ...[
                      pw.SizedBox(width: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 0.5),
                        decoration: const pw.BoxDecoration(color: PdfColors.purple200),
                        child: pw.Text('فضلة', style: const pw.TextStyle(fontSize: 6, color: PdfColors.purple900)),
                      ),
                    ],
                  ],
                ),
                // Bottom small notes
                pw.Text(
                  '45° / 45° · مقياس',
                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 4),
          // QR Code
          pw.Container(
            width: 42,
            height: 42,
            alignment: pw.Alignment.center,
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrData,
              width: 42,
              height: 42,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelData {
  final int barNumber;
  final bool isFromRemnant;
  final String itemCode;
  final PlannedCut cut;

  const _LabelData({
    required this.barNumber,
    required this.isFromRemnant,
    required this.itemCode,
    required this.cut,
  });
}
