import 'dart:convert';
import '../models/scanned_piece_info.dart';

class QrParseResult {
  final bool isValid;
  final ScannedPieceInfo? pieceInfo;
  final String? errorMessage;

  const QrParseResult.success(this.pieceInfo)
      : isValid = true,
        errorMessage = null;

  const QrParseResult.failure(this.errorMessage)
      : isValid = false,
        pieceInfo = null;
}

class QrCutPayloadParser {
  /// Local dictionary mapping standard item codes to Arabic names.
  /// Used for offline fallback and backward compatibility with older QR labels.
  static const Map<String, String> _itemCodeArabicNames = {
    'track': 'سكة 2000 بحاجب',
    'u_profile': 'يو 2000',
    'kaab': 'كعب 2000 مفرد',
    'screen_vertical': 'درفة منخل عامودي',
    'screen_horizontal': 'درفة منخل أفقي',
    'side': 'جنب 2000 بحاجب',
    'handle': 'مسكة 2000 مفرد',
    'shankal': 'شنكل 2000 مفرد',
    'interlock': 'إنترلوك 2000',
  };

  /// Parses a raw scanned string safely without throwing exceptions.
  static QrParseResult parse(String rawContent) {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) {
      return const QrParseResult.failure('الرمز الممسوح فارغ');
    }

    // Fast check: Must be JSON object
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
      return const QrParseResult.failure('الرمز الممسوح ليس ملصق قص خاص بتطبيق مقياس');
    }

    try {
      final dynamic decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        return const QrParseResult.failure('تنسيق الرمز غير صالح');
      }

      final map = decoded;

      // Validate signature: Must have either 'p' & 'l' OR 'projectId' & 'lengthCm'
      final hasProject = map.containsKey('p') || map.containsKey('projectId');
      final hasLength = map.containsKey('l') || map.containsKey('lengthCm');
      final hasItem = map.containsKey('i') || map.containsKey('itemCode');

      if (!hasProject || !hasLength || !hasItem) {
        return const QrParseResult.failure('بيانات ملصق مقياس غير مكتملة');
      }

      var piece = ScannedPieceInfo.fromMap(map, raw: trimmed);

      // If Arabic name is empty, resolve from local fallback dictionary
      if (piece.nameArabic.isEmpty) {
        final fallbackName = _itemCodeArabicNames[piece.itemCode.toLowerCase()] ??
            piece.itemCode.toUpperCase();
        piece = piece.copyWith(nameArabic: fallbackName);
      }

      // Infer cut angles if not provided
      final is90Degree = piece.itemCode.toLowerCase().contains('screen') ||
          piece.itemCode.toLowerCase() == 'track';

      piece = piece.copyWith(
        cutAngleLeft: is90Degree ? '90°' : '45°',
        cutAngleRight: is90Degree ? '90°' : '45°',
      );

      return QrParseResult.success(piece);
    } catch (e) {
      return QrParseResult.failure('تعذر قراءة محتوى الرمز: $e');
    }
  }
}
