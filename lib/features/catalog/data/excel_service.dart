import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../domain/catalog_item.dart';

class CatalogExcelImportResult {
  final List<CatalogItem> validItems;
  final List<String> errors;

  const CatalogExcelImportResult({
    required this.validItems,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
}

class CatalogExcelService {
  static const List<String> headers = [
    'code',
    'engineItemCode',
    'arabicName',
    'categoryId',
    'unit',
    'color',
    'thickness',
    'status',
  ];

  /// Exports catalog items to UTF-8 `.xlsx` bytes.
  static Uint8List exportCatalogToExcel(List<CatalogItem> items) {
    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Catalog';
    final sheet = excel[sheetName];

    // Header row
    sheet.appendRow(headers.map(TextCellValue.new).toList());

    // Data rows
    for (final item in items) {
      sheet.appendRow([
        TextCellValue(item.code),
        TextCellValue(item.engineItemCode),
        TextCellValue(item.arabicName),
        TextCellValue(item.categoryId),
        TextCellValue(item.unit),
        TextCellValue(item.color),
        TextCellValue(item.thickness),
        TextCellValue(item.status),
      ]);
    }

    final encoded = excel.encode();
    return Uint8List.fromList(encoded ?? const []);
  }

  /// Parses an `.xlsx` file, rejecting duplicate codes (both within the file and against `existingCodes`).
  static CatalogExcelImportResult parseCatalogExcel(
    Uint8List bytes, {
    Set<String> existingCodes = const {},
  }) {
    final validItems = <CatalogItem>[];
    final errors = <String>[];
    final seenCodesInFile = <String, int>{};
    final normalizedExisting =
        existingCodes.map((c) => c.trim().toUpperCase()).toSet();

    late final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      return CatalogExcelImportResult(
        validItems: const [],
        errors: ['تعذر قراءة ملف الإكسل: $e'],
      );
    }

    if (excel.tables.isEmpty) {
      return const CatalogExcelImportResult(
        validItems: [],
        errors: ['ملف الإكسل فارغ ولا يحتوي على أي أوراق عمل'],
      );
    }

    final sheet = excel.tables.values.first;
    final rows = sheet.rows;
    if (rows.length <= 1) {
      return const CatalogExcelImportResult(
        validItems: [],
        errors: ['لا توجد صفوف بيانات بعد صف العناوين'],
      );
    }

    // Map header positions dynamically if headers match, else use standard column order
    final headerRow = rows.first
        .map((c) => _cellToString(c).trim().toLowerCase())
        .toList();

    int idxOf(String name, int fallback) {
      final found = headerRow.indexOf(name.toLowerCase());
      return found >= 0 ? found : fallback;
    }

    final hasExtendedHeaders = headerRow.contains('engineitemcode');
    final codeIdx = idxOf('code', 0);
    final engineCodeIdx = hasExtendedHeaders ? idxOf('engineitemcode', 1) : -1;
    final nameIdx = idxOf('arabicname', hasExtendedHeaders ? 2 : 1);
    final categoryIdx = idxOf('categoryid', hasExtendedHeaders ? 3 : 2);
    final unitIdx = idxOf('unit', hasExtendedHeaders ? 4 : 3);
    final colorIdx = idxOf('color', hasExtendedHeaders ? 5 : 4);
    final thicknessIdx = idxOf('thickness', hasExtendedHeaders ? 6 : 5);
    final statusIdx = idxOf('status', hasExtendedHeaders ? 7 : 6);

    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      final rowNumber = r + 1;

      String cellAt(int index) {
        if (index < 0 || index >= row.length) return '';
        return _cellToString(row[index]).trim();
      }

      final code = cellAt(codeIdx).toUpperCase();
      final engineItemCode = engineCodeIdx >= 0 ? cellAt(engineCodeIdx) : '';
      final arabicName = cellAt(nameIdx);
      final categoryId =
          cellAt(categoryIdx).isNotEmpty ? cellAt(categoryIdx) : 'aluminum';
      final unit = cellAt(unitIdx).isNotEmpty ? cellAt(unitIdx) : 'piece';
      final color = cellAt(colorIdx);
      final thickness = cellAt(thicknessIdx);
      final status =
          cellAt(statusIdx).isNotEmpty ? cellAt(statusIdx) : 'active';

      // Skip completely empty rows
      if (code.isEmpty && arabicName.isEmpty) continue;

      if (code.isEmpty) {
        errors.add('صف $rowNumber: كود الصنف (code) فارغ');
        continue;
      }

      if (arabicName.isEmpty) {
        errors.add('صف $rowNumber: الاسم بالعربية (arabicName) فارغ للصنف $code');
        continue;
      }

      if (seenCodesInFile.containsKey(code)) {
        errors.add(
          'صف $rowNumber: كود الصنف مكرر داخل الملف ($code) — ظهر سابقاً في صف ${seenCodesInFile[code]}',
        );
        continue;
      }

      if (normalizedExisting.contains(code)) {
        errors.add('صف $rowNumber: كود الصنف ($code) مسجل مسبقاً في الكتالوج');
        continue;
      }

      final candidate = CatalogItem(
        id: 'cat_${code.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
        code: code,
        engineItemCode: engineItemCode,
        arabicName: arabicName,
        categoryId: categoryId,
        unit: unit,
        color: color,
        thickness: thickness,
        status: status == 'inactive' ? 'inactive' : 'active',
      );

      final validationError = candidate.validate();
      if (validationError != null) {
        errors.add('صف $rowNumber ($code): $validationError');
        continue;
      }

      seenCodesInFile[code] = rowNumber;
      validItems.add(candidate);
    }

    return CatalogExcelImportResult(
      validItems: validItems,
      errors: errors,
    );
  }

  static String _cellToString(Data? cell) {
    final val = cell?.value;
    if (val == null) return '';
    return switch (val) {
      TextCellValue(:final value) => value.text ?? value.toString(),
      IntCellValue(:final value) => value.toString(),
      DoubleCellValue(:final value) => value.toString(),
      BoolCellValue(:final value) => value.toString(),
      _ => val.toString(),
    };
  }
}

