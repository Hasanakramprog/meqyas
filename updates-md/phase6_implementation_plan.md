# Phase 6 — Catalog, Pricing, Suppliers, Cart & Orders: Implementation Plan

**Branch:** `feature/phase-6-catalog-orders`  
**Spec §:** 2 (roles), 6 (data model), 7 (security rules), 10 (catalog/inventory), 11 (cart/suppliers/orders), 12 (reports), 13 (UI/UX), 15 (DoD)  
**DoD (spec §15):** Preview never changes stock; confirm deducts once; retry doesn't double-deduct; insufficient stock changes nothing.

---

## 1. Owner Decisions & Defaults

| Topic | Decision Needed | Default Used If No Answer | Spec Reference |
|---|---|---|---|
| **Order Confirmation Authority** | Who can trigger `confirmOrder` to deduct stock? | Supplier or Admin (pluggable check) | §11, §17 |
| **Order Status Workflow** | Full lifecycle steps | `draft` → `sent` → `confirmed` → `preparing` → `completed` (or `cancelled`) | §6, §11 |
| **Stock Deduction Trigger** | When is stock deducted? | Only on explicit callable function `confirmOrder` execution (never on cart/draft/WhatsApp/PDF) | §0.4, §11, §15 |
| **Cart Material Aggregation** | How are project materials pooled into cart? | One-tap button from Project/CutPlan to populate aluminum bars, glass panes, and accessories | §11, §13 |
| **Currency** | Default currency for pricing & orders | SAR (ريال سعودي) with configurable string field | §6, §17 |
| **Excel Format** | Columns for Catalog import/export | `code`, `arabicName`, `categoryId`, `unit`, `color`, `thickness`, `status` | §10 |
| **WhatsApp Message** | Direct link format | `https://wa.me/{phone}?text={encodedSummary}` with workshop header & items table | §11 |

---

## 2. What Already Exists ✅ (No Rebuild Needed)

| Component | Location | Current State |
|---|---|---|
| **Firestore Security Rules Schema** | [firestore.rules](file:///Users/macbook/Desktop/codingrepo/meqyas/firestore.rules#L78-L136) | Structure defined for `catalogItems`, `suppliers`, `suppliers/{id}/prices`, `suppliers/{id}/stock`, `suppliers/{id}/lots`, `orders`, `inventoryMovements` |
| **Create Supplier Cloud Function** | [functions/src/index.ts](file:///Users/macbook/Desktop/codingrepo/meqyas/functions/src/index.ts#L108-L156) | `createSupplierUser` callable function creates Auth user + `suppliers/{id}` + claims `{role: 'supplier', supplierId}` |
| **Dashboard Shells** | [supplier_dashboard_screen.dart](file:///Users/macbook/Desktop/codingrepo/meqyas/lib/features/dashboard/presentation/supplier_dashboard_screen.dart), [owner_dashboard_screen.dart](file:///Users/macbook/Desktop/codingrepo/meqyas/lib/features/dashboard/presentation/owner_dashboard_screen.dart), [admin_dashboard_screen.dart](file:///Users/macbook/Desktop/codingrepo/meqyas/lib/features/dashboard/presentation/admin_dashboard_screen.dart) | UI cards and tiles present for Supplier Portal, Admin Catalog & Orders |
| **Role-Based Routing** | [app_router.dart](file:///Users/macbook/Desktop/codingrepo/meqyas/lib/app/router/app_router.dart#L76-L103) | Guards for `/dashboard/owner`, `/dashboard/supplier`, and `/dashboard/admin` |
| **PDF Generation Base** | `pdf` + `printing` packages + bundled Cairo font | Verified in Phase 5; can be reused for Purchase Order PDFs |
| **Materials Computation** | `maqyas_engine` | Calculates required profile lengths, glass panes, and accessory counts from unit measurements |

---

## 3. Gaps in Current Codebase (What Must Be Built)

1. **No Catalog Feature (`lib/features/catalog/`):**
   - No repository, models, or screens for managing `catalogItems` (Admin CRUD, search, filter).
   - No Excel import/export capability for catalog items.
2. **No Supplier Management & Portal (`lib/features/suppliers/`, `lib/features/supplier_portal/`):**
   - Admin cannot view/edit suppliers list in UI.
   - Supplier dashboard cards are static placeholders without screens for incoming orders, pricing, or stock.
3. **No Pricing Repository (`lib/features/pricing/`):**
   - No data layer for `suppliers/{supplierId}/prices/{itemId}` or price history tracking.
4. **No Workshop Cart (`lib/features/cart/`):**
   - No cart model, repository, or screen to aggregate bars, glass, and accessories across project units.
   - No auto-add feature from `CutPlanScreen` or `ProjectDetailScreen`.
5. **No Orders Feature (`lib/features/orders/`):**
   - No order creation flow from cart (grouped by supplier).
   - No WhatsApp order generation (`wa.me` links).
   - No Arabic Purchase Order PDF generator.
   - No order tracking screens for owner and supplier.
6. **No `confirmOrder` Cloud Function (Core DoD Requirement):**
   - Transactional callable function missing in `functions/src/index.ts`.
   - No idempotent stock deduction, rollback, or `inventoryMovements` recording.

---

## 4. Architecture & Feature Modules

```
lib/features/
  ├── catalog/                    # Catalog items, categories, Excel import/export
  │   ├── data/                   # catalog_repository.dart, excel_service.dart
  │   ├── domain/                 # catalog_item.dart, catalog_category.dart
  │   └── presentation/           # catalog_list_screen.dart, catalog_item_form_dialog.dart
  ├── suppliers/                  # Directory of suppliers (Owner & Admin)
  │   ├── data/                   # suppliers_repository.dart
  │   ├── domain/                 # supplier.dart
  │   └── presentation/           # suppliers_list_screen.dart, supplier_form_dialog.dart
  ├── pricing/                    # Supplier pricing per catalog item
  │   ├── data/                   # pricing_repository.dart
  │   └── domain/                 # item_price.dart
  ├── inventory/                  # Stock balances & Lots (read-only for clients, managed by Cloud Functions)
  │   ├── data/                   # inventory_repository.dart
  │   └── domain/                 # stock_item.dart, lot_item.dart, inventory_movement.dart
  ├── cart/                       # Workshop material requirements cart
  │   ├── data/                   # cart_repository.dart
  │   ├── domain/                 # cart_item.dart
  │   └── presentation/           # cart_screen.dart, add_to_cart_dialog.dart
  ├── orders/                     # Orders to suppliers, WhatsApp, Purchase Order PDF
  │   ├── data/                   # orders_repository.dart
  │   ├── domain/                 # order_model.dart, order_status.dart
  │   └── presentation/           # orders_list_screen.dart, order_detail_screen.dart
  └── supplier_portal/            # Screens for logged-in supplier user
      └── presentation/           # supplier_orders_screen.dart, supplier_prices_screen.dart, supplier_stock_screen.dart
```

---

## 5. Detailed Component Specifications

### 5.1 Catalog Feature (`lib/features/catalog/`)
- **Model `CatalogItem`**:
  - `id`, `code` (unique uppercase, e.g. `AL-TRK-2000`), `arabicName`, `categoryId`, `unit` (`bar`, `roll`, `piece`, `m`, `cm`, `mm`), `color`, `thickness`, `status` (`active`/`inactive`), `createdAt`, `updatedAt`.
- **Predefined Categories**:
  - `aluminum` (مقاطع ألمنيوم), `accessories` (إكسسوارات), `glass` (زجاج), `fiber` (شبك منخل), `plastic` (بلاستيك وربر), `tools` (براغي وتثبيت).
- **Admin Catalog Screen (`/dashboard/admin/catalog`)**:
  - Search bar (by code or Arabic name), category filter chips.
  - Add/Edit Item Modal with validation (code must be alphanumeric and unique).
  - Excel Import Button: parses uploaded `.xlsx` file, validates columns, checks for duplicate codes, batch writes to Firestore.
  - Excel Export Button: downloads active catalog items formatted in UTF-8 Arabic `.xlsx`.

### 5.2 Suppliers & Supplier Portal (`lib/features/suppliers/` & `lib/features/supplier_portal/`)
- **Model `Supplier`**:
  - `id`, `name`, `phone`, `whatsappPhones` (list of strings for multi-line support), `address`, `createdAt`, `updatedAt`.
- **Admin Supplier Management (`/dashboard/admin/suppliers`)**:
  - List of registered suppliers, create new supplier with login account (calling `createSupplierUser`).
- **Owner Suppliers Directory (`/dashboard/owner/suppliers`)**:
  - Cards showing supplier name, phone, WhatsApp buttons, catalog items they carry.
- **Supplier Portal (`/dashboard/supplier/**`)**:
  - `/dashboard/supplier/orders`: incoming purchase orders assigned to this supplier.
  - `/dashboard/supplier/prices`: editable price list for catalog items.
  - `/dashboard/supplier/stock`: current balances and inventory replenishment.

### 5.3 Pricing & Inventory Models
- **`ItemPrice`**:
  - `itemId`, `supplierId`, `price`, `currency` (default `SAR`), `validFrom`, `updatedAt`.
- **`StockItem`**:
  - `itemId`, `supplierId`, `balance`, `unit`, `reservedQty`, `updatedAt`.
- **`InventoryMovement`**:
  - `movementId`, `itemId`, `supplierId`, `qty`, `unit`, `movementType` (`deduction` | `restock` | `adjustment`), `orderId`, `idempotencyKey`, `createdAt`, `actorUid`.

### 5.4 Workshop Cart (`lib/features/cart/`)
- **Path in Firestore:** `workshops/{workshopId}/cart/{cartItemId}`
- **Model `CartItem`**:
  - `id`, `itemId`, `nameArabic`, `qty`, `unit`, `category`, `sourceProjectId`, `sourceProjectName`, `note`, `suggestedSupplierId`.
- **Cart Aggregation Engine (`CartService.aggregateFromProject`)**:
  - Tapping «إضافة المواد للسلة» from a project/cut plan computes:
    1. **Aluminum Bars:** converts `BarCuttingPlan` count into bar items (e.g. 5 bars of `track`, 4 bars of `kaab`).
    2. **Glass Panes:** calculates glass pane count and m² area per glass type.
    3. **Accessories:** computes handles, rollers, gasket, corners, plugs, and screws based on unit specifications (per spec §8.6).
- **Cart Screen (`/dashboard/owner/cart`)**:
  - Group items by Supplier or Category.
  - Edit quantities, add notes, delete items.
  - Checkout Button: splits cart items by supplier and creates draft/sent Orders.

### 5.5 Orders & Supplier Communication (`lib/features/orders/`)
- **Model `OrderModel`**:
  - `id`, `orderNumber` (e.g. `PO-2026-0001`), `workshopId`, `workshopName`, `workshopPhone`, `workshopLocation`, `supplierId`, `supplierName`, `status` (`draft`, `sent`, `confirmed`, `preparing`, `completed`, `cancelled`), `items`, `notes`, `idempotencyKey`, `totalAmount`, `currency`, `confirmedBy`, `confirmedAt`, `createdAt`, `updatedAt`, `statusHistory`.
- **Purchase Order PDF Generator (`PurchaseOrderPdfGenerator`)**:
  - Formal Arabic RTL document with Cairo font.
  - Workshop header + Supplier details.
  - Order items table with quantities, units, and optional prices.
  - Delivery instructions and notes.
- **WhatsApp Order Dispatcher**:
  - Formats clean Arabic text:
    ```
    *طلب توريد مواد — ورشة {workshopName}*
    رقم الطلب: {orderNumber}
    المشروع: {projectName}
    -------------------------
    • {qty} {unit} — {nameArabic}
    • ...
    -------------------------
    الموقع: {workshopLocation}
    هاتف: {workshopPhone}
    ```
  - Launches `https://wa.me/{supplierPhone}?text={encodedText}`.
- **Critical Policy:** Stock is **NEVER** deducted when viewing cart, generating PDF, or launching WhatsApp!

---

## 6. The `confirmOrder` Cloud Function (Core DoD)

To satisfy the spec §15 Definition of Done:
> *Preview never changes stock; confirm deducts once; retry doesn't double-deduct; insufficient stock changes nothing.*

### Function Implementation Plan (`functions/src/index.ts`):
```typescript
export const confirmOrder = onCall(async (request) => {
  // 1. Authentication & Authorization Check
  if (!request.auth) throw new HttpsError("unauthenticated", "Auth required");
  const callerUid = request.auth.uid;
  const callerRole = request.auth.token.role;
  const callerSupplierId = request.auth.token.supplierId;

  const { orderId, idempotencyKey } = request.data || {};
  if (!orderId || !idempotencyKey) {
    throw new HttpsError("invalid-argument", "Missing orderId or idempotencyKey");
  }

  const orderRef = db.collection("orders").doc(orderId);

  return await db.runTransaction(async (transaction) => {
    // 2. Read Order Document
    const orderDoc = await transaction.get(orderRef);
    if (!orderDoc.exists) throw new HttpsError("not-found", "Order not found");
    const order = orderDoc.data()!;

    // Authorization: Only the assigned supplier or admin can confirm
    if (callerRole !== "admin" && callerSupplierId !== order.supplierId) {
      throw new HttpsError("permission-denied", "Only assigned supplier can confirm order");
    }

    // 3. Idempotency Check: Already confirmed with same idempotencyKey?
    if (order.status === "confirmed" && order.idempotencyKey === idempotencyKey) {
      return { success: true, alreadyConfirmed: true, orderId };
    }
    if (order.status !== "sent" && order.status !== "draft") {
      throw new HttpsError("failed-precondition", `Order cannot be confirmed in status ${order.status}`);
    }

    const supplierId = order.supplierId;
    const items = order.items as Array<{ itemId: string; qty: number; nameArabic: string; unit: string }>;

    // 4. Pre-read ALL stock items
    const stockRefs = items.map((item) => db.doc(`suppliers/${supplierId}/stock/${item.itemId}`));
    const stockDocs = await Promise.all(stockRefs.map((ref) => transaction.get(ref)));

    // 5. Atomic Stock Verification (All or Nothing)
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const stockDoc = stockDocs[i];
      const currentBalance = stockDoc.exists ? (stockDoc.data()?.balance || 0) : 0;

      if (currentBalance < item.qty) {
        // ABORT: Insufficient stock changes NOTHING!
        throw new HttpsError(
          "failed-precondition",
          `الرصيد غير كافٍ للصنف «${item.nameArabic}». المتوفر: ${currentBalance}، المطلوب: ${item.qty}. لم يتم خصم أي كمية.`
        );
      }
    }

    // 6. Deduct Stock & Write Inventory Movements
    const now = FieldValue.serverTimestamp();
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const stockRef = stockRefs[i];
      const currentBalance = stockDocs[i].data()?.balance || 0;
      const newBalance = currentBalance - item.qty;

      transaction.update(stockRef, {
        balance: newBalance,
        updatedAt: now,
      });

      // Write inventory movement log
      const movementRef = db.collection("inventoryMovements").doc();
      transaction.set(movementRef, {
        movementId: movementRef.id,
        itemId: item.itemId,
        supplierId,
        qty: item.qty,
        unit: item.unit,
        movementType: "deduction",
        orderId,
        idempotencyKey,
        actorUid: callerUid,
        createdAt: now,
      });
    }

    // 7. Update Order Status
    const statusHistory = order.statusHistory || [];
    statusHistory.push({
      status: "confirmed",
      changedBy: callerUid,
      changedAt: now,
      note: "تم تأكيد الطلب وخصم الكميات من مستودع المورد بنجاح",
    });

    transaction.update(orderRef, {
      status: "confirmed",
      confirmedBy: callerUid,
      confirmedAt: now,
      idempotencyKey,
      statusHistory,
      updatedAt: now,
    });

    // 8. Write Audit Log
    const auditRef = db.collection("auditLogs").doc();
    transaction.set(auditRef, {
      action: "order_confirmed",
      orderId,
      supplierId,
      actorUid: callerUid,
      itemsCount: items.length,
      at: now,
    });

    return { success: true, orderId, confirmedAt: now };
  });
});
```

---

## 7. Cloud Function: Restock / Adjust Stock (`adjustStock`)
Allows the supplier or admin to add inventory balances safely through server transactions:
- `adjustStock({ supplierId, itemId, qty, reason })`
- Transaction updates `suppliers/{supplierId}/stock/{itemId}` balance.
- Creates `inventoryMovements` record with `movementType: 'restock'` or `'adjustment'`.

---

## 8. Routing Additions (`app_router.dart`)

```dart
// Owner Routes:
GoRoute(path: 'cart', builder: (_, _) => const CartScreen()),
GoRoute(path: 'orders', builder: (_, _) => const OrdersListScreen(), routes: [
  GoRoute(path: ':orderId', builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['orderId']!)),
]),
GoRoute(path: 'suppliers', builder: (_, _) => const SuppliersDirectoryScreen()),

// Supplier Routes:
GoRoute(path: '/dashboard/supplier/orders', builder: (_, _) => const SupplierOrdersScreen()),
GoRoute(path: '/dashboard/supplier/prices', builder: (_, _) => const SupplierPricesScreen()),
GoRoute(path: '/dashboard/supplier/stock', builder: (_, _) => const SupplierStockScreen()),

// Admin Routes:
GoRoute(path: 'catalog', builder: (_, _) => const AdminCatalogScreen()),
GoRoute(path: 'suppliers', builder: (_, _) => const AdminSuppliersScreen()),
GoRoute(path: 'orders', builder: (_, _) => const AdminOrdersOverviewScreen()),
```

---

## 9. Definition of Done (DoD) Verification Matrix

| # | Check / Test Vector | Expected Behavior |
|---|---|---|
| **1** | Open Cart & View Draft | Stock balances in `suppliers/{id}/stock` remain **100% unchanged**. |
| **2** | Generate & Share WhatsApp / PDF | Zero writes to `stock` or `inventoryMovements`. |
| **3** | Single `confirmOrder` on sufficient stock | Stock balance decreases by exact item quantity; `inventoryMovements` created; order status becomes `confirmed`. |
| **4** | Retry `confirmOrder` with same idempotency key | Returns success; **NO double deduction** occurs; balances stay identical. |
| **5** | `confirmOrder` with insufficient stock | Transaction aborts completely; Arabic error returned; **no partial deductions**. |
| **6** | Catalog Excel Import | Imports Arabic item names and units; duplicate codes rejected with line number. |
| **7** | Supplier Portal Isolation | Supplier A cannot see or edit Supplier B's orders, prices, or stock (verified by security rules). |
| **8** | Material Aggregation | Clicking "Add to Cart" from project adds correct aluminum bars, glass panes, and accessories. |
| **9** | Code Analysis & Tests | `flutter analyze` passes with zero errors; engine and unit tests pass. |

---

## 10. Estimated Build Order

| Step | Milestone | Est. Time |
|---|---|---|
| **1** | Add `excel` & `url_launcher` dependencies to `pubspec.yaml` | 15 min |
| **2** | Catalog Feature (Models, Repository, Admin UI + Excel Import/Export) | 2–3 hrs |
| **3** | Suppliers & Pricing Feature (Repository, Admin Suppliers, Price List) | 2 hrs |
| **4** | Stock & Inventory Repository + `adjustStock` Cloud Function | 1–2 hrs |
| **5** | Cart Feature (Model, Repository, Screen + Material Aggregation from Cut Plan) | 2 hrs |
| **6** | Orders Feature (Model, Repository, WhatsApp Dispatcher, Purchase Order PDF) | 2–3 hrs |
| **7** | `confirmOrder` Callable Cloud Function (Transaction, Idempotency, Deduction) | 2 hrs |
| **8** | Supplier Portal Screens (Incoming Orders, Price Editor, Stock Overview) | 2 hrs |
| **9** | Navigation & Router Integration | 30 min |
| **10** | End-to-End DoD Testing on Firebase Emulators | 1–2 hrs |
| **Total** | | **~14–18 hrs** |
