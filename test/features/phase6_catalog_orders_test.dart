import 'package:flutter_test/flutter_test.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:meqyas/features/cart/data/cart_repository.dart';
import 'package:meqyas/features/catalog/data/excel_service.dart';
import 'package:meqyas/features/catalog/domain/catalog_item.dart';
import 'package:meqyas/features/orders/domain/order_model.dart';
import 'package:meqyas/features/projects/domain/models/project_unit.dart';

void main() {
  group('Phase 6 — Catalog, Excel, Cart Aggregation & Orders Tests', () {
    test('Spec §8.7 & §16.5: Fiber and brush catalog items require ROLL unit', () {
      const invalidMesh = CatalogItem(
        id: 'test_1',
        code: 'FB-MSH-BAD',
        arabicName: 'شبك منخل بالمتر',
        categoryId: 'fiber',
        unit: 'm', // Invalid: must be roll
      );
      expect(invalidMesh.validate(), isNotNull);

      const validMesh = CatalogItem(
        id: 'test_2',
        code: 'FB-MSH-OK',
        arabicName: 'لفة شبك منخل فيبر',
        categoryId: 'fiber',
        unit: 'roll',
      );
      expect(validMesh.validate(), isNull);
    });

    test('Catalog Excel export and import roundtrip + duplicate detection', () {
      final seedItems = SeedCatalog.getDefaultCatalogItems().take(4).toList();
      final bytes = CatalogExcelService.exportCatalogToExcel(seedItems);
      expect(bytes, isNotEmpty);

      // Importing into an empty catalog succeeds for all 4 items
      final result1 = CatalogExcelService.parseCatalogExcel(bytes);
      expect(result1.hasErrors, isFalse);
      expect(result1.validItems.length, equals(4));
      expect(result1.validItems.first.arabicName, equals(seedItems.first.arabicName));

      // Importing again when code already exists flags duplicate error
      final result2 = CatalogExcelService.parseCatalogExcel(
        bytes,
        existingCodes: {seedItems.first.code},
      );
      expect(result2.hasErrors, isTrue);
      expect(result2.validItems.length, equals(3));
    });

    test('CartRepository.aggregateFromProject pools bars, glass, accessories & rolls', () {
      final engine = CalculatorEngine(
        rules: SeedRules.getSystem2000BeadedRules(),
      );
      const optimizer = CutOptimizer();
      final catalog = SeedCatalog.getDefaultCatalogItems();

      final unit = ProjectUnit(
        id: 'u1',
        projectId: 'p1',
        name: 'شباك 120×150',
        location: 'غرفة',
        widthCm: 120,
        heightCm: 150,
        quantity: 1,
        unitType: 'window',
        profileSystemId: SeedRules.system2000Beaded,
        glazingMode: 'single',
        sharhOption: 'none',
        sashCount: 2,
        screenCount: 1,
        hasScreen: true,
        rollerType: 'slider',
        glassType: 'clear',
        glassThicknessMm: 6.0,
        hasCorners: true,
        hasGasket: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final cartItems = CartRepository.aggregateFromProject(
        projectId: 'p1',
        projectName: 'فيلا الياسمين',
        units: [unit],
        engine: engine,
        optimizer: optimizer,
        catalogItems: catalog,
      );

      expect(cartItems, isNotEmpty);

      // Verify aluminum bars are present in 'bar' unit
      final trackBar = cartItems.firstWhere((c) => c.engineItemCode == 'track');
      expect(trackBar.unit, equals('bar'));
      expect(trackBar.qty, greaterThan(0));

      // Verify glass is present in 'm2' unit (2 panes * 0.70584 = 1.41 m2)
      final glassItem = cartItems.firstWhere((c) => c.engineItemCode == 'glass_pane');
      expect(glassItem.unit, equals('m2'));
      expect(glassItem.qty, closeTo(1.41, 0.02));

      // Verify screen mesh roll is in 'roll' unit
      final meshRoll = cartItems.firstWhere((c) => c.engineItemCode == 'fiber_mesh_roll');
      expect(meshRoll.unit, equals('roll'));
    });

    test('OrderModel WhatsApp message & URI generation', () {
      const order = OrderModel(
        id: 'ord_1',
        orderNumber: 'PO-2026-AB12CD',
        workshopId: 'w1',
        workshopName: 'ورشة النور للألمنيوم',
        workshopPhone: '0501234567',
        workshopLocation: 'الرياض',
        supplierId: 'sup_1',
        supplierName: 'شركة التوريدات الوطنية',
        status: OrderStatus.sent,
        idempotencyKey: 'idem_ord_1',
        items: [
          OrderLineItem(
            itemId: 'cat_al_track_2000',
            nameArabic: 'سكة 2000 بحاجب',
            qty: 5,
            unit: 'bar',
            unitPrice: 140,
          ),
        ],
      );

      expect(order.computedTotal, equals(700.0));
      final msg = order.buildWhatsAppMessage();
      expect(msg, contains('ورشة النور للألمنيوم'));
      expect(msg, contains('PO-2026-AB12CD'));
      expect(msg, contains('سكة 2000 بحاجب'));

      final uri = order.buildWhatsAppUri('+966 50 000 0001');
      expect(uri.host, equals('wa.me'));
      expect(uri.path, equals('/966500000001'));
    });
  });
}
