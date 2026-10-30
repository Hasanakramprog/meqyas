import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../catalog/domain/catalog_item.dart';
import '../domain/order_model.dart';

class PurchaseOrderPdfGenerator {
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  static Future<void> _ensureFontsLoaded() async {
    if (_regularFont != null && _boldFont != null) return;
    final regularData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    _regularFont = pw.Font.ttf(regularData);
    _boldFont = pw.Font.ttf(boldData);
  }

  /// Generates an Arabic RTL Purchase Order PDF (Spec §11 & §12).
  /// Never modifies stock balances.
  static Future<Uint8List> generatePurchaseOrderPdf(OrderModel order) async {
    await _ensureFontsLoaded();
    final regular = _regularFont!;
    final bold = _boldFont!;

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
      ),
    );

    final dateStr = intl.DateFormat('yyyy-MM-dd HH:mm').format(
      order.createdAt ?? DateTime.now(),
    );

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
          // Header Banner
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey900,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'أمر شراء وتوريد مواد (Purchase Order)',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 16,
                        color: PdfColors.amber300,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'الورشة الطالبة: ${order.workshopName.isNotEmpty ? order.workshopName : "ورشة العمل"}',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.white,
                      ),
                    ),
                    if (order.workshopLocation.isNotEmpty ||
                        order.workshopPhone.isNotEmpty)
                      pw.Text(
                        '${order.workshopLocation}  ${order.workshopPhone.isNotEmpty ? "• هاتف: ${order.workshopPhone}" : ""}',
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
                      'رقم الطلب: ${order.orderNumber}',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 12,
                        color: PdfColors.white,
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
                      'الحالة: ${order.status.arabicLabel}',
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
          pw.SizedBox(height: 14),

          // Supplier Box
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'السادة / المورد: ${order.supplierName.isNotEmpty ? order.supplierName : order.supplierId}',
                  style: pw.TextStyle(font: bold, fontSize: 12),
                ),
                pw.Text(
                  'عدد البنود: ${order.items.length}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Items Table
          pw.TableHelper.fromTextArray(
            context: context,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headerStyle: pw.TextStyle(font: bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.centerRight,
            headers: [
              'الإجمالي',
              'سعر الوحدة',
              'الوحدة',
              'الكمية',
              'المشروع / ملاحظة',
              'الصنف والوصف',
              '#',
            ],
            data: List.generate(order.items.length, (index) {
              final item = order.items[index];
              final qtyStr = item.qty == item.qty.roundToDouble()
                  ? item.qty.toInt().toString()
                  : item.qty.toStringAsFixed(2);
              final priceStr = item.unitPrice > 0
                  ? '${item.unitPrice.toStringAsFixed(2)} ${order.currency}'
                  : '-';
              final totalStr = item.lineTotal > 0
                  ? '${item.lineTotal.toStringAsFixed(2)} ${order.currency}'
                  : '-';
              final noteStr = [
                if (item.projectName.isNotEmpty) item.projectName,
                if (item.note.isNotEmpty) item.note,
              ].join(' — ');

              return [
                totalStr,
                priceStr,
                CatalogUnit.arabicLabel(item.unit),
                qtyStr,
                noteStr.isEmpty ? '-' : noteStr,
                item.nameArabic,
                '${index + 1}',
              ];
            }),
          ),
          pw.SizedBox(height: 14),

          if (order.computedTotal > 0)
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  border: pw.Border.all(color: PdfColors.amber700),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'الإجمالي الكلي: ${order.computedTotal.toStringAsFixed(2)} ${order.currency}',
                  style: pw.TextStyle(font: bold, fontSize: 12),
                ),
              ),
            ),

          if (order.notes.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'ملاحظات وشروط التوريد: ${order.notes}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }
}

