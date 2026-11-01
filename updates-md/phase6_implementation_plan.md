# Phase 6 — Catalog, Pricing, Suppliers, Cart & Orders: Implementation Plan

**Branch:** `feature/phase-6-catalog-orders`  
**Spec §:** 2 (roles), 6 (data model), 7 (security rules), 10 (catalog/inventory), 11 (cart/suppliers/orders), 12 (reports), 13 (UI/UX), 15 (DoD)  
**DoD (spec §15):** Preview never changes stock; confirm deducts once; retry doesn't double-deduct; insufficient stock changes nothing.

> [!IMPORTANT]
> **Plan revision (2026-11-01):**
> - **Step 1 (§5.4 — DONE ✅):** Owner reviews and edits the **Project Materials Requirements** table (`inStockQty`, `toBuyQty`, manual CRUD).
> - **Step 2 (§5.5 — NEW PLAN):** From the finalized requirements table (`toBuyQty > 0`), the owner has **3 direct actions**, and the supplier has an **interactive in-app order review & pricing workflow** (mark availability, edit quantities they have, enter manual unit prices, write notes, and send back to the owner).
> - **No Supplier Stock Tracking:** The supplier does **not** manage warehouse stock/inventory in the app; they simply review incoming workshop orders, indicate which items/quantities they have, enter prices and notes manually, and send the quote back to the workshop owner.

---

## 1. Owner Decisions & Defaults

| Topic | Decision Needed | Default Used If No Answer | Spec Reference |
|---|---|---|---|
| **Order Confirmation Authority** | Who can trigger `confirmOrder` to deduct stock? | Supplier or Admin (pluggable check) | §11, §17 |
| **Order Status Workflow** | Full lifecycle steps | `sent` (مرسل للمورد) → `quoted` (تم التسعير/التعديل من المورد) → `confirmed` (معتمد) → `preparing` (قيد التجهيز) → `completed` (مكتمل) (or `cancelled`) | §6, §11 |
| **Stock Deduction Trigger** | When is stock deducted? | Only on explicit callable function `confirmOrder` execution (never on requirements preview, PDF download, WhatsApp share, or initial quote) | §0.4, §11, §15 |
| **Post-Requirements Flow** | How do project requirements become orders? | **REVISED (§5.4 → §5.5):** After finalizing the *Project Materials Requirements* table (`toBuyQty > 0`), the owner chooses from **3 options**: (1) Download nice Requirements PDF, (2) Select Supplier & Send In-App Order Request, or (3) Select Supplier & Send PDF/Summary via WhatsApp. | §11, §13 |
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
  - `id`, `code` (unique uppercase, e.g. `AL-TRK-2000`), `engineItemCode` (links to `maqyas_engine` item codes like `track`, `u_profile`, `kaab`, `glass_handle`, `water_plug`, etc.), `arabicName`, `categoryId`, `unit` (`bar`, `roll`, `piece`, `m`, `cm`, `mm`), `color`, `thickness`, `status` (`active`/`inactive`), `createdAt`, `updatedAt`.
  - **Commercial Unit Rule (Spec §8.7 & §16.5):** Items in `fiber` (mesh) or `brush` categories must use `roll` (`لفة`) as their commercial pricing/stock/order unit.
- **Predefined Categories**:
  - `aluminum` (مقاطع ألمنيوم), `accessories` (إكسسوارات), `glass` (زجاج), `fiber` (شبك منخل وفرش), `plastic` (بلاستيك وربر), `tools` (براغي وتثبيت).
- **Admin Catalog Screen (`/dashboard/admin/catalog`)**:
  - Search bar (by code, engineItemCode, or Arabic name), category filter chips.
  - Add/Edit Item Modal with validation (code must be alphanumeric and unique; `fiber`/`brush` enforces `roll` unit).
  - Excel Import Button (`file_picker` + `excel`): parses uploaded `.xlsx` file, validates columns, checks for duplicate codes with row numbers, batch writes to Firestore.
  - Excel Export Button: downloads/shares active catalog items formatted in UTF-8 Arabic `.xlsx`.

### 5.2 Suppliers & Supplier Portal (`lib/features/suppliers/` & `lib/features/supplier_portal/`)
- **Model `Supplier`**:
  - `id`, `name`, `phone`, `whatsappPhones` (list of strings for multi-line support), `address`, `createdAt`, `updatedAt`.
- **Admin Supplier Management (`/dashboard/admin/suppliers`)**:
  - List of registered suppliers, create new supplier with login account (calling `createSupplierUser`).
- **Owner Suppliers Directory (`/dashboard/owner/suppliers`)**:
  - Cards showing supplier name, phone, WhatsApp buttons.
- **Supplier Portal (`/dashboard/supplier/**`) — Orders & Quotations Only (No Stock Management)**:
  - The supplier does **not** track or care about warehouse stock balances in the app.
  - `/dashboard/supplier` & `/dashboard/supplier/orders`: view incoming order requests from workshops, open any order to mark which items are available, edit quantities, enter unit prices and notes manually, and send the priced order back to the workshop owner.

### 5.3 Pricing & Inventory Models
- **`ItemPrice`**:
  - `itemId`, `supplierId`, `price`, `currency` (default `SAR`), `validFrom`, `updatedAt`.
- **`StockItem`**:
  - `itemId`, `supplierId`, `balance`, `unit`, `reservedQty`, `updatedAt`.
- **`InventoryMovement`**:
  - `movementId`, `itemId`, `supplierId`, `qty`, `unit`, `movementType` (`deduction` | `restock` | `adjustment`), `orderId`, `idempotencyKey`, `createdAt`, `actorUid`.

### 5.4 Project Materials Requirements — Owner Step 1 (NEW, replaces direct "Add to Cart")

> [!IMPORTANT]
> **Revised owner flow (this step is the scope for now; everything after it is TBD).**
> The owner must **first review what the project needs**, and only then decide what to order. Nothing is sent to a supplier, and nothing goes to a cart/order automatically, at this stage.

#### Flow
```
Add units to project → Run Cut Optimization (save cut plan)
        ↓
«احتياجات المشروع من المواد» (Materials Requirements screen)
        ↓
Owner reviews the table → edits / adds / deletes lines manually
        ↓
(next step: TBD — to be defined by owner later)
```

#### End-to-End Owner Scenario (From Creating a Project to Finalizing the Requirements Table)
1. **Create Project:** Owner creates a project (e.g., «فيلا السيد أحمد») with client info and default aluminum color/thickness.
2. **Add Units (Windows & Doors):** Owner adds project units (`200 × 150 cm` sliding window with mesh, `120 × 120 cm` window, etc.). The calculation engine computes cutting lists, glass panes/m², accessories, and mesh/brush rolls.
3. **Run Cut Optimization (`CutPlanScreen`):** Owner runs 1D bin-packing optimization, optionally assigns workshop shelf remnants (قصاصات الرف), and saves the cut plan.
4. **Open «احتياجات المشروع من المواد» (`ProjectRequirementsScreen`):**
   - Tapping «احتياجات المشروع من المواد» opens `/dashboard/owner/projects/:projectId/requirements`.
   - On first visit, the app snapshots all calculated materials for the project into `workshops/{workshopId}/projects/{projectId}/requirements/{lineId}`:
     - **Aluminum bars:** only *new* 660 cm bars (`!bar.isFromRemnant`) from the saved cut plan.
     - **Glass:** m² and pane count per glass type.
     - **Accessories:** handles, rollers, plugs, screws, corners, gasket (spec §8.6).
     - **Mesh / brush:** commercial `roll` (`لفة`) units only (spec §8.7).
5. **Owner Reviews & Edits the Table (Full CRUD):**
   - **Record Workshop Stock (`inStockQty`):** Owner enters how much they already have in the workshop; `toBuyQty` automatically updates to `max(requiredQty - inStockQty, 0)` unless manually overridden.
   - **Override `toBuyQty`:** Owner can directly type a custom `toBuyQty` (e.g., rounding up to a full box or buying extra spares), which sets `isToBuyOverridden = true`.
   - **Add Manual Line (`source = manual`):** Owner adds extra items from the Catalog or free-text custom items.
   - **Delete / Dismiss Line:** Deleting a manual line removes it; deleting an `auto` line marks `dismissed = true` so regeneration won't re-add it unless restored via «استعادة المحذوفات».
6. **Later Changes to Project Units / Cut Plan (Safe Regeneration Merge Rules):**
   - Editing units or re-saving the cut plan **never** silently overwrites the owner's table.
   - Instead, when `project.updatedAt > project.requirementsGeneratedAt`, a warning banner appears: **«تغيرت وحدات المشروع — إعادة التوليد»**.
   - If the owner ignores the banner, nothing changes.
   - If the owner taps **«إعادة التوليد»**, the app merges the newly calculated quantities per item:
     - `requiredQty` updates to the new calculated value.
     - `inStockQty` and `note` entered by the owner are **preserved**.
     - If `isToBuyOverridden == false`, `toBuyQty` recomputes as `max(newRequiredQty - inStockQty, 0)`.
     - If `isToBuyOverridden == true`, the owner's manual `toBuyQty` is **kept** and the row is highlighted with a badge («تغيرت الكمية المحسوبة — راجع الكمية») until reviewed or reset.
     - Manual lines (`source = manual`) are **preserved** untouched.
     - Dismissed auto lines (`dismissed = true`) stay hidden unless the owner taps «استعادة المحذوفات».
7. **Stop Point (Current Scope Boundary):** The flow stops here with the finalized list of items where `toBuyQty > 0`. How those items proceed to suppliers/orders (§5.5) will be defined next by the owner.

#### Entry points
- Button «احتياجات المشروع من المواد» in `ProjectDetailScreen` and `CutPlanScreen` (replaces the current one-tap «إضافة المواد للسلة» that pushed items straight to the cart).
- Route: `/dashboard/owner/projects/:projectId/requirements?workshopId=...`

#### How the table is generated
- On first open, the screen **auto-generates** the requirement lines from the project's units + saved cut plan (existing `CartRepository.aggregateFromProject` logic, moved to a dedicated `RequirementsService`):
  1. **Aluminum bars:** new 660 cm bars per item from the saved cut plan (shelf remnants consumed are excluded).
  2. **Glass:** m² and pane count per glass type.
  3. **Accessories:** handles, rollers, plugs, screws, corners, gasket (spec §8.6).
  4. **Mesh / brush:** rolls only (spec §8.7).
- Auto-generated lines are saved once as a **snapshot**; later changes to units do not silently overwrite the owner's manual edits. A banner «تغيرت وحدات المشروع — إعادة التوليد» lets the owner regenerate explicitly using the safe merge rules above.

#### Requirements table (nice, readable, RTL)
| Column | Notes |
|---|---|
| الصنف (name + engine code) | Grouped by category: ألمنيوم / زجاج / إكسسوارات / شبك وفراشة / براغي |
| الكمية المطلوبة (calculated) | Read-only, from engine/cut plan |
| لدي في الورشة (in stock at workshop) | Owner-editable; the owner may already own some items |
| الكمية المطلوب شراؤها (to buy) | `max(required − inStock, 0)` by default, manually overridable |
| الوحدة | bar / m² / piece / roll … (roll-only for mesh/brush) |
| ملاحظة | Free text per line |
| المصدر | `auto` (calculated) or `manual` (added by owner) badge |
| إجراءات | Edit / Delete |

- Group header rows with per-category subtotal counts; summary bar at top (total lines, lines to buy, lines already covered).
- Mobile: each line is a card with the same fields; desktop/tablet: data table.
- A line with `to buy = 0` is shown as «متوفر — لا يحتاج شراء» (dimmed) and excluded from the next step.

#### CRUD on lines (owner)
- **Create:** «إضافة صنف» → pick from catalog (search by name/code) or free-text custom item; qty + unit + note.
- **Read:** the table above.
- **Update:** inline edit of `inStock`, `toBuy`, `note`; edit dialog for name/unit of manual lines. Calculated `required` stays read-only on auto lines (but can be reset via «إعادة الحساب»).
- **Delete:** remove a line (confirm dialog). Deleting an auto line stores it as `dismissed` so regeneration does not bring it back unless the owner chooses «استعادة المحذوفات».
- Undo snackbar after delete.

#### Data model
- Path: `workshops/{workshopId}/projects/{projectId}/requirements/{lineId}` (inside the owner's workshop subtree; already covered by existing security rules).
- **`RequirementLine`**: `id`, `itemId` (catalog id, nullable for custom), `engineItemCode`, `nameArabic`, `category`, `requiredQty` (calculated), `inStockQty`, `toBuyQty`, `isToBuyOverridden` (bool), `needsReviewAfterRegen` (bool), `unit`, `note`, `source` (`auto` | `manual`), `dismissed` (bool), `createdAt`, `updatedAt`.
- Project doc gets `requirementsGeneratedAt` to detect staleness vs. units / cut plan.

#### Rules
- **No stock deduction and no supplier writes** happen on this screen (spec §0.4, §11).
- Works offline (Firestore persistence), per spec §14.
- All strings in Arabic via ARB.

#### Code impact (when implemented)
- New: `lib/features/requirements/{domain/requirement_line.dart, data/requirements_repository.dart, data/requirements_service.dart, presentation/project_requirements_screen.dart}`.
- Change: `ProjectDetailScreen` / `CutPlanScreen` buttons now navigate to the requirements screen instead of writing to the cart.
- Router: add `requirements` child route under `projects/:projectId`.

---

### 5.5 Post-Requirements Flow (3 Owner Options) & Supplier Interactive Order Review (NEW)

#### Complete Flow Diagram
```
«احتياجات المشروع من المواد» (ProjectRequirementsScreen — items with toBuyQty > 0)
        │
        ├──► [Option 1] تحميل PDF للاحتياجات (Download/Print Nice Requirements PDF)
        │       └─ Generates formal RTL Arabic PDF grouped by category with workshop & project header
        │
        ├──► [Option 2] إرسال طلب للمورد داخل التطبيق (Select Supplier → Send In-App Request)
        │       ├─ 1. Owner picks a Supplier & sends items (toBuyQty > 0) → creates Order (status: `sent`)
        │       ├─ 2. Supplier receives order in `/dashboard/supplier/orders`
        │       ├─ 3. Supplier reviews line-by-line:
        │       │      • Accepts all items as-is, OR modifies each line:
        │       │        - Toggle Available / Unavailable (`isAvailable`)
        │       │        - Edit Available Quantity (`suppliedQty` if partial stock)
        │       │        - Enter Unit Price manually (`unitPrice` per item)
        │       │        - Write item note (`supplierNote`) + general order note (`supplierResponseNote`)
        │       ├─ 4. Supplier taps «إرسال الرد والتسعيرة للورشة» → status becomes `quoted` (or `confirmed`)
        │       └─ 5. Owner sees the priced/modified order in `/dashboard/owner/orders/:orderId`
        │              with full breakdown, supplier notes, and total price, and can approve/confirm or export PDF
        │
        └──► [Option 3] اختيار مورد وإرسال PDF عبر واتساب (Select Supplier → Share PDF & WhatsApp)
                ├─ 1. Owner selects a Supplier (or enters WhatsApp number)
                ├─ 2. Generates the Arabic Requirements PDF (with supplier name in header)
                └─ 3. Opens WhatsApp (`wa.me/{phone}?text=...`) with formatted summary + shares PDF file
```

---

#### 5.5.1 Action Bar on `ProjectRequirementsScreen` (The 3 Owner Options)
At the bottom of [`ProjectRequirementsScreen`](file:///Users/macbook/Desktop/codingrepo/meqyas/lib/features/requirements/presentation/project_requirements_screen.dart), when there is at least 1 active item with `toBuyQty > 0`, a persistent action bar offers **3 clear buttons**:

1. **Option 1 — «تحميل PDF للاحتياجات» (`RequirementsPdfGenerator`)**:
   - Generates a clean, printable Arabic RTL PDF (`lib/features/requirements/data/requirements_pdf_generator.dart`) using the Cairo font:
     - **Header:** Workshop name, phone, location, Project name, Client name, Date, and summary counts (Total items to buy).
     - **Grouped Tables:** Separate sections per category (`مقاطع ألمنيوم`, `زجاج`, `إكسسوارات`, `شبك وفراشة`, etc.) showing `#`, `الصنف`, `الكود`, `الكمية المطلوب شراؤها`, `الوحدة`, and `ملاحظات`.
     - **Footer:** Page numbers and signature/stamp area.
   - Opens `Printing.layoutPdf` so the owner can save/download/print the PDF directly.

2. **Option 2 — «إرسال للمورد بالتطبيق» (Select Supplier & Send In-App Order)**:
   - Opens a **Select Supplier Dialog** (`_showSelectSupplierDialog`):
     - Lists active suppliers from `suppliers` collection (showing name, phone, address).
     - Optional field for `ملاحظات الورشة للمورد` (general delivery/project note).
   - When the owner confirms:
     - Filters active requirement lines where `toBuyQty > 0`.
     - Creates an `OrderModel` in `orders/{orderId}` with:
       - `status: OrderStatus.sent` (`بانتظار رد وتسعير المورد`)
       - `projectId` & `projectName` linked to the project
       - Each `OrderLineItem` initialized with `requestedQty = line.toBuyQty`, `qty = line.toBuyQty`, `isAvailable = true`, `unitPrice = 0` (to be filled manually by the supplier), and `note = line.note`.
     - Navigates or shows a snackbar linking to `/dashboard/owner/orders/:orderId`.

3. **Option 3 — «إرسال PDF عبر واتساب» (Select Supplier & Send to WhatsApp + PDF)**:
   - Opens the **Select Supplier for WhatsApp Dialog**:
     - Owner picks a supplier from the directory (or types a custom WhatsApp phone number).
     - If the supplier has multiple WhatsApp numbers (`whatsappPhones`), lets the owner pick which number to message.
   - Generates the Requirements PDF addressed to that supplier and gives the owner two immediate actions in one step:
     - Launches `https://wa.me/{phone}?text={encodedArabicSummary}` with the project's required items.
     - Opens `Printing.sharePdf(bytes: pdfBytes, filename: 'طلب_مواد_{projectName}.pdf')` so the owner can attach the generated PDF file directly into the WhatsApp chat.

---

#### 5.5.2 Supplier In-App Order Review, Modification & Manual Pricing
When a Supplier logs in (`/dashboard/supplier/orders`) and opens an incoming order (`OrderDetailScreen` or dedicated `SupplierOrderReviewScreen`):

1. **Line-by-Line Interactive Table / Cards for Supplier:**
   For every item requested by the owner, the supplier sees:
   - **الصنف والكمية المطلوبة من الورشة (`requestedQty` + `unit`)** + owner's `note`.
   - **التوفر لدى المورد (`isAvailable` toggle/checkbox):**
     - Supplier can mark an item as **«متوفر»** (`true`) or **«غير متوفر لدى المورد»** (`false`).
     - If marked unavailable (`isAvailable = false`), `suppliedQty` becomes `0` and its line total becomes `0`.
   - **الكمية المتوفرة للتوريد (`qty` / `suppliedQty`):**
     - Defaults to `requestedQty`.
     - Supplier can edit it manually (e.g., owner requested `10` bars, supplier only has `6` bars in stock → enters `6`).
     - If `qty < requestedQty` and `qty > 0`, badge shows **«متوفر جزئياً»**.
   - **سعر الوحدة (`unitPrice` — Manual Input by Supplier):**
     - Text field where the supplier types the price per unit manually (in `SAR`).
     - Automatically calculates and displays **إجمالي البند (`qty × unitPrice`)**.
   - **ملاحظة المورد على الصنف (`supplierNote`):**
     - Free-text note per item (e.g., *"متوفر لون بديل"*, *"سيتوفر الأسبوع القادم"*).

2. **Supplier General Note & Live Total Bar:**
   - Field for **«ملاحظات المورد العامة على الطلب» (`supplierResponseNote`)** (e.g., delivery time, payment terms).
   - Live summary showing:
     - Available items count vs. Unavailable items count.
     - **الإجمالي الكلي للتسعيرة (`totalAmount = sum(qty * unitPrice)`)**.

3. **Supplier Submit Actions:**
   - **«قبول الطلب بالكامل وإرسال التسعيرة»** or **«حفظ التعديلات وإرسال التسعيرة للورشة»**:
     - Saves all updated `items` (`isAvailable`, `qty`, `unitPrice`, `supplierNote`), `supplierResponseNote`, and `totalAmount`.
     - Transitions order `status` from `sent` $\to$ `quoted` («تم التسعير والرد من المورد»).
     - Appends a `StatusHistoryEntry` recording the supplier's response timestamp and summary.

---

#### 5.5.3 Owner View of Supplier's Priced / Modified Order
When the owner opens `/dashboard/owner/orders` or `/dashboard/owner/orders/:orderId`:
- Sees a status badge:
  - `sent`: «مرسل للمورد — بانتظار التسعير»
  - `quoted`: «وصل رد وتسعيرة المورد — بانتظار اعتمادك»
  - `confirmed`: «معتمد ومؤكد»
- Sees a clear comparison per line:
  - **الكمية المطلوبة (`requestedQty`)** vs **الكمية المتوفرة من المورد (`qty`)** (highlighted if partial or unavailable `غير متوفر`).
  - **سعر الوحدة (`unitPrice`)** and **إجمالي الصنف (`lineTotal`)** entered by the supplier.
  - **ملاحظة المورد (`supplierNote`)** per item + **ملاحظة المورد العامة (`supplierResponseNote`)**.
- **Owner Actions on a `quoted` Order:**
  - **«اعتماد التسعيرة وتأكيد الطلب»**: Owner approves the supplier's quote/modifications (`status: confirmed`).
  - **«تحميل عرض السعر / أمر الشراء PDF»**: Downloads the formal Arabic PDF including the supplier's prices, availability status, notes, and total amount.
  - **«التواصل مع المورد عبر واتساب»**: Opens WhatsApp chat with the supplier.
  - **«إلغاء الطلب»**: Cancels the order if the owner doesn't want to proceed.

---

#### 5.5.4 Updated `OrderModel` & `OrderLineItem` Fields (`lib/features/orders/domain/order_model.dart`)
- **`OrderStatus` enum**:
  - `draft` (مسودة)
  - `sent` (مرسل للمورد — بانتظار الرد)
  - `quoted` (تم التسعير/التعديل من المورد)
  - `confirmed` (مؤكد ومعتمد)
  - `preparing` (قيد التجهيز)
  - `completed` (مكتمل)
  - `cancelled` (ملغي)
- **`OrderLineItem` additions**:
  - `requestedQty` (`double`): Original quantity requested by the workshop owner from the requirements table.
  - `qty` (`double`): Quantity the supplier can actually supply (`0` if unavailable, or modified by supplier).
  - `isAvailable` (`bool`, default `true`): Whether the supplier has this item.
  - `unitPrice` (`double`): Manual unit price entered by the supplier.
  - `note` (`String`): Workshop owner's note on the item.
  - `supplierNote` (`String`): Supplier's note on the item.
- **`OrderModel` additions**:
  - `projectId` (`String`) & `projectName` (`String`): Links the order to the source project.
  - `supplierResponseNote` (`String`): Overall note written by the supplier when sending the quote/response.

---

#### 5.5.5 Security Rules Update (`firestore.rules` via `firestore-rules-author` subagent)
- In `match /orders/{orderId}`:
  - Allow the assigned **Supplier (`isSupplier(resource.data.supplierId)`)** when `resource.data.status in ['sent', 'quoted', 'confirmed', 'preparing']` to update:
    - `items` (to set `isAvailable`, `qty`, `unitPrice`, `supplierNote`),
    - `totalAmount`,
    - `supplierResponseNote`,
    - `status` (to `'quoted'`, `'confirmed'`, `'preparing'`, `'completed'`, or `'cancelled'`),
    - `statusHistory`, `updatedAt`.
  - Allow the **Workshop Owner (`isOwnerOf(resource.data.workshopId)`)** when `resource.data.status in ['draft', 'sent', 'quoted']` to update `status` (e.g. `'confirmed'` or `'cancelled'`), `statusHistory`, `updatedAt`.

---

## 6. The `confirmOrder` Cloud Function (Core DoD)

To satisfy the spec §15 Definition of Done:
> *Preview never changes stock; confirm deducts once; retry doesn't double-deduct; insufficient stock changes nothing.*

### Function Implementation Plan (`functions/src/index.ts`):
- **Aggregates quantities by `itemId`** before checking or deducting balances so multiple lines referencing the same `itemId` never overwrite each other.
- **Enforces Firestore 500-op transaction limit** by rejecting orders with $>150$ unique items.
- **Idempotent check**: if `order.status === "confirmed"` and `order.idempotencyKey === idempotencyKey`, returns `{ success: true, alreadyConfirmed: true, orderId }` without deducting stock again.
- **All-or-nothing stock verification**: pre-reads all `suppliers/{supplierId}/stock/{itemId}` docs; if any `currentBalance < requiredQty`, aborts the entire transaction and changes nothing.
- **Writes `inventoryMovements` and `auditLogs`** atomically inside the same transaction.

---

## 7. Cloud Functions: `adjustStock` & `updateOrderStatus`
1. **`adjustStock({ supplierId, itemId, qty, movementType, unit, reason })`**:
   - Allows the supplier or admin to restock or adjust inventory balances safely through server transactions.
   - Prevents negative stock balances (`newBalance < 0` throws `failed-precondition`).
   - Creates `inventoryMovements` record (`restock` or `adjustment`) and `auditLogs` entry.
2. **`updateOrderStatus({ orderId, newStatus, note })`** (Spec §11 line 340):
   - Enforces post-confirmation status transition table:
     - `confirmed` $\to$ `preparing` | `cancelled`
     - `preparing` $\to$ `completed`
     - `draft` / `sent` $\to$ `cancelled`
   - Appends to `statusHistory` and writes `auditLogs`.

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
