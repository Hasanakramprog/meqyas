import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CutPlanPdfGenerator {
  /// Generates a complete, beautiful Arabic RTL Cut List PDF for the workshop floor.
  static Future<Uint8List> generate({
    required String workshopName,
    required String projectName,
    required OptimizationResult result,
    DateTime? date,
  }) async {
    final pdf = pw.Document();

    // 1. Load Arabic Cairo Font
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

    final formattedDate = DateFormat('yyyy/MM/dd - hh:mm a')
        .format(date ?? DateTime.now());

    // 2. Group bars by itemCode
    final groupedBars = <String, List<BarCuttingPlan>>{};
    for (final bar in result.barPlans) {
      groupedBars.putIfAbsent(bar.itemCode, () => []).add(bar);
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          textDirection: pw.TextDirection.rtl,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        ),
        header: (context) => _buildHeader(
          workshopName: workshopName,
          projectName: projectName,
          formattedDate: formattedDate,
          pageNumber: context.pageNumber,
          totalPages: context.pagesCount,
        ),
        footer: (context) => _buildFooter(context.pageNumber, context.pagesCount),
        build: (context) => [
          pw.SizedBox(height: 12),

          // ── Executive Summary Box ─────────────────────────────────────
          _buildSummaryBox(result.summary),
          pw.SizedBox(height: 16),

          // ── Oversized Warning (if any) ───────────────────────────────
          if (result.hasOversizedCuts) ...[
            _buildOversizedCutsBox(result.oversizedCuts),
            pw.SizedBox(height: 16),
          ],

          // ── Bars By Profile Item ──────────────────────────────────────
          ...groupedBars.entries.map((entry) {
            final itemCode = entry.key;
            final bars = entry.value;
            final itemName = bars.isNotEmpty && bars.first.cuts.isNotEmpty
                ? bars.first.cuts.first.nameArabic
                : itemCode;

            return _buildItemGroup(itemName, itemCode, bars);
          }),
        ],
      ),
    );

    return pdf.save();
  }

  // ---------------------------------------------------------------------------
  // Header & Footer
  // ---------------------------------------------------------------------------

  static pw.Widget _buildHeader({
    required String workshopName,
    required String projectName,
    required String formattedDate,
    required int pageNumber,
    required int totalPages,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.amber700, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'مِقْيَاس · تقرير وجداول خطة القص',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.amber900,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'الورشة: $workshopName | المشروع: $projectName',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                formattedDate,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'صفحة $pageNumber من $totalPages',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(int pageNumber, int totalPages) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'طُبع عبر منصة مِقْيَاس لإدارة ورش الألمنيوم',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
          pw.Text(
            '$pageNumber / $totalPages',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Summary Box
  // ---------------------------------------------------------------------------

  static pw.Widget _buildSummaryBox(OptimizationSummary summary) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildStatCell('قضبان جديدة (660سم)', '${summary.totalBarsNeeded}', PdfColors.blue800),
              _buildStatCell('فضلات مسترجعة للمخزن', '${summary.totalReusableRemnantsCm.toStringAsFixed(1)} سم', PdfColors.green800),
              _buildStatCell('نسبة الهدر الحقيقي', '${summary.scrapPercentage.toStringAsFixed(1)}%', PdfColors.orange800),
              if (summary.remnantsReused > 0)
                _buildStatCell('فضلات أعيد استخدامها', '${summary.remnantsReused}', PdfColors.purple800),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'إجمالي أطوال القص: ${summary.totalCutLengthCm.toStringAsFixed(1)} سم',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.Text(
                'هدر التشذيب: ${summary.totalTrimLossCm.toStringAsFixed(0)} سم | هدر المنشار: ${summary.totalKerfLossCm.toStringAsFixed(1)} سم',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.Text(
                'الهدر الصافي التالف: ${summary.totalScrapCm.toStringAsFixed(1)} سم',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.red800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStatCell(String title, String val, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          val,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Oversized Cuts Warning
  // ---------------------------------------------------------------------------

  static pw.Widget _buildOversizedCutsBox(List<PlannedCut> oversized) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.red50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColors.red300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '⚠️ تنبيه: توجد قطع تتجاوز الطول الأقصى للقضيب ولم يتم تضمينها في خطة القص:',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red900,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Wrap(
            spacing: 8,
            runSpacing: 4,
            children: oversized
                .map((c) => pw.Text(
                      '• ${c.nameArabic}: ${c.lengthCm} سم (${c.unitTag})',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.red800),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Item Group & Bar Tables
  // ---------------------------------------------------------------------------

  static pw.Widget _buildItemGroup(
    String itemName,
    String itemCode,
    List<BarCuttingPlan> bars,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Item Title Bar
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '$itemName ($itemCode)',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey900,
                  ),
                ),
                pw.Text(
                  'عدد القضبان: ${bars.length}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),

          // Bar Cards
          ...bars.map((bar) => _buildBarCard(bar)),
        ],
      ),
    );
  }

  static pw.Widget _buildBarCard(BarCuttingPlan bar) {
    final isRemnant = bar.isFromRemnant;
    final isUseful = bar.isRemnantUseful;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: isRemnant ? PdfColors.purple200 : PdfColors.grey300,
          width: 0.6,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: isRemnant ? PdfColors.purple50 : PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Bar Header Line
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Text(
                    'قضيب #${bar.barNumber}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: isRemnant ? PdfColors.purple900 : PdfColors.grey900,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  if (isRemnant)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.purple100,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      child: pw.Text(
                        'من فضلة مخزنة (${bar.sourceRemnantLengthCm?.toStringAsFixed(1) ?? bar.totalBarLengthCm} سم)',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.purple900),
                      ),
                    )
                  else
                    pw.Text(
                      'قضيب جديد (660 سم)',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                ],
              ),
              pw.Text(
                'المتبقي: ${bar.remainingLengthCm.toStringAsFixed(1)} سم · ${isUseful ? "فضلة صالحة للمخزن 🟢" : "هدر ⚪"}',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: isUseful ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: isUseful ? PdfColors.green900 : PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),

          // Cuts Table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),   // تسلسل
              1: pw.FlexColumnWidth(3),   // اسم القطعة
              2: pw.FlexColumnWidth(2),   // الطول
              3: pw.FlexColumnWidth(3),   // العنصر (الشباك)
              4: pw.FlexColumnWidth(1.5), // الزوايا
            },
            children: [
              // Table Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _tableCell('#', isHeader: true),
                  _tableCell('القطعة', isHeader: true),
                  _tableCell('الطول', isHeader: true),
                  _tableCell('الشباك / الوحدة', isHeader: true),
                  _tableCell('الزاوية', isHeader: true),
                ],
              ),
              // Table Rows
              ...bar.cuts.asMap().entries.map((e) {
                final idx = e.key + 1;
                final cut = e.value;
                return pw.TableRow(
                  children: [
                    _tableCell('$idx'),
                    _tableCell(cut.nameArabic),
                    _tableCell('${cut.lengthCm} سم', isBold: true),
                    _tableCell(cut.unitTag ?? '-'),
                    _tableCell('45° / 45°'),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 7.5,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.grey900 : PdfColors.grey800,
        ),
      ),
    );
  }
}
