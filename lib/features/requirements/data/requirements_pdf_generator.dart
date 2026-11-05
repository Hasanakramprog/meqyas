import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/requirement_line.dart';

class RequirementsPdfGenerator {
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  static Future<void> _ensureFontsLoaded() async {
    if (_regularFont != null && _boldFont != null) return;
    final regularData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    _regularFont = pw.Font.ttf(regularData);
    _boldFont = pw.Font.ttf(boldData);
  }

  static String _formatQty(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  /// Generates a clean, formal Arabic RTL PDF of the project's required materials
  /// (`toBuyQty > 0` and `!dismissed`), grouped by material category.
  static Future<Uint8List> generate({
    required String workshopName,
    String workshopPhone = '',
    String workshopLocation = '',
    required String projectName,
    String clientName = '',
    String? supplierName,
    String? generalNote,
    required List<RequirementLine> lines,
  }) async {
    await _ensureFontsLoaded();
    final regular = _regularFont!;
    final bold = _boldFont!;

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
      ),
    );

    final toBuyLines = lines
        .where((l) => !l.dismissed && l.toBuyQty > 0)
        .toList();

    final grouped = <String, List<RequirementLine>>{};
    for (final line in toBuyLines) {
      grouped.putIfAbsent(line.category, () => []).add(line);
    }
    final categories = grouped.keys.toList()
      ..sort(
        (a, b) => RequirementLine.categorySortOrder(a)
            .compareTo(RequirementLine.categorySortOrder(b)),
      );

    final dateStr = intl.DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'منصة مقياس لإدارة ورش الألمنيوم والزجاج — صفحة ${context.pageNumber} من ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          // 1. Header Banner
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey900,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      supplierName != null && supplierName.isNotEmpty
                          ? 'طلب تسعير وتوريد مواد مشروع'
                          : 'كشف احتياجات المشروع من المواد المطلوبة للشراء',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 15,
                        color: PdfColors.amber300,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'الورشة: ${workshopName.isNotEmpty ? workshopName : "ورشة ألمنيوم"}',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.white,
                      ),
                    ),
                    if (workshopLocation.isNotEmpty || workshopPhone.isNotEmpty)
                      pw.Text(
                        [
                          if (workshopLocation.isNotEmpty) workshopLocation,
                          if (workshopPhone.isNotEmpty) 'هاتف: $workshopPhone',
                        ].join(' • '),
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey300,
                        ),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'المشروع: $projectName',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 12,
                        color: PdfColors.white,
                      ),
                    ),
                    if (clientName.isNotEmpty)
                      pw.Text(
                        'العميل: $clientName',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey300,
                        ),
                      ),
                    pw.Text(
                      'التاريخ: $dateStr',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey300,
                      ),
                    ),
                    pw.Text(
                      'إجمالي الأصناف المطلوبة: ${toBuyLines.length} صنف',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 10,
                        color: PdfColors.amber200,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // 2. Supplier Box (if addressed to a specific supplier)
          if (supplierName != null && supplierName.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.amber50,
                border: pw.Border.all(color: PdfColors.amber700, width: 0.8),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'موجه إلى السادة / المورد: $supplierName',
                    style: pw.TextStyle(font: bold, fontSize: 11),
                  ),
                  pw.Text(
                    'يرجى تزويدنا بالأسعار وتوفر الأصناف الموضحة أدناه',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
          ],

          // 3. Category Sections & Tables
          for (final cat in categories) ...[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey800,
                borderRadius: const pw.BorderRadius.vertical(
                  top: pw.Radius.circular(6),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    RequirementLine.categoryLabelArabic(cat),
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 11,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'عدد الأصناف: ${grouped[cat]!.length}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.amber200,
                    ),
                  ),
                ],
              ),
            ),
            pw.TableHelper.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              headerStyle: pw.TextStyle(font: bold, fontSize: 9.5),
              cellStyle: const pw.TextStyle(fontSize: 9.5),
              cellAlignment: pw.Alignment.centerRight,
              headers: [
                'ملاحظات',
                'الوحدة',
                'الكمية المطلوبة للشراء',
                'الكود',
                'الصنف والوصف',
                '#',
              ],
              data: List.generate(grouped[cat]!.length, (index) {
                final item = grouped[cat]![index];
                return [
                  item.note.isNotEmpty ? item.note : '-',
                  item.unitArabic,
                  _formatQty(item.toBuyQty),
                  item.engineItemCode.isNotEmpty ? item.engineItemCode : '-',
                  item.nameArabic,
                  '${index + 1}',
                ];
              }),
            ),
            pw.SizedBox(height: 14),
          ],

          // 4. General Note & Signature Footer
          if (generalNote != null && generalNote.trim().isNotEmpty) ...[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'ملاحظات الورشة: ${generalNote.trim()}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
            pw.SizedBox(height: 12),
          ],
        ],
      ),
    );

    return doc.save();
  }
}

