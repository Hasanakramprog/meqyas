import 'package:flutter_test/flutter_test.dart';
import 'package:meqyas/features/cut_scanner/domain/services/qr_cut_payload_parser.dart';

void main() {
  group('QrCutPayloadParser Tests', () {
    test('Successfully parses enriched payload v1', () {
      const payload = '{"v":1,"p":"project_123","u":"شباك الصالون #1","i":"kaab","n":"كعب 2000 مفرد","l":58.75,"b":1,"r":false}';
      final result = QrCutPayloadParser.parse(payload);

      expect(result.isValid, isTrue);
      expect(result.pieceInfo, isNotNull);
      final piece = result.pieceInfo!;
      expect(piece.projectId, 'project_123');
      expect(piece.unitTag, 'شباك الصالون #1');
      expect(piece.itemCode, 'kaab');
      expect(piece.nameArabic, 'كعب 2000 مفرد');
      expect(piece.lengthCm, 58.75);
      expect(piece.barNumber, 1);
      expect(piece.isFromRemnant, isFalse);
      expect(piece.cutAngleLeft, '45°');
    });

    test('Successfully parses legacy payload and resolves fallback Arabic name', () {
      const legacyPayload = '{"p":"project_456","u":"واجهة #2","i":"track","l":117.0,"b":2}';
      final result = QrCutPayloadParser.parse(legacyPayload);

      expect(result.isValid, isTrue);
      expect(result.pieceInfo, isNotNull);
      final piece = result.pieceInfo!;
      expect(piece.projectId, 'project_456');
      expect(piece.itemCode, 'track');
      expect(piece.nameArabic, 'سكة 2000 بحاجب'); // Resolved from fallback dict
      expect(piece.lengthCm, 117.0);
      expect(piece.barNumber, 2);
      expect(piece.cutAngleLeft, '90°'); // track is 90 degrees
    });

    test('Gracefully handles remnant piece flag', () {
      const remnantPayload = '{"p":"proj_7","u":"شباك غرفة","i":"kaab","l":55.0,"b":3,"r":true}';
      final result = QrCutPayloadParser.parse(remnantPayload);

      expect(result.isValid, isTrue);
      expect(result.pieceInfo!.isFromRemnant, isTrue);
    });

    test('Rejects non-JSON strings without crashing', () {
      final result = QrCutPayloadParser.parse('https://example.com/qr?test=123');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('ليس ملصق قص'));
    });

    test('Rejects empty or whitespace strings', () {
      final result = QrCutPayloadParser.parse('   ');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('فارغ'));
    });

    test('Rejects external JSON without Maqyas keys', () {
      final result = QrCutPayloadParser.parse('{"wifi_ssid":"my_workshop","pass":"123456"}');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('غير مكتملة'));
    });

    test('Rejects malformed JSON syntax gracefully', () {
      final result = QrCutPayloadParser.parse('{invalid_json: true,}');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('تعذر قراءة'));
    });
  });
}
