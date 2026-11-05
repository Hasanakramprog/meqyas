# Phase 6 — Project Requirements (§5.4), Suppliers & Interactive Order Quotations (§5.5): Implementation Plan

**Branch:** `feature/phase-6-catalog-orders`  
**Core Scope:**
- **No Pre-set Catalog Prices, No Supplier Stock Tracking, No Cart Intermediary:**
  - The app does **not** use pre-stored supplier price lists or supplier warehouse stock/inventory tracking.
  - Instead, all material needs originate from the **Project Materials Requirements** table (`ProjectRequirementsScreen` — §5.4).
  - From that table, the **Workshop Owner** has **3 direct actions** (§5.5), and the **Supplier** receives incoming order requests in-app, marks which items are available, edits quantities they can supply, enters unit prices and notes manually, and sends the quote back to the owner.

---

## 1. Whole-App Capabilities by Role (Owner vs. Supplier)

### A. Workshop Owner (`owner`) Capabilities
1. **Manage Workshops & Branches (`OwnerDashboardScreen`):**
   - Create one or more workshops/branches and switch between them from the top header.
   - Customize workshop engineering rules & 660 cm saw settings (`WorkshopRulesScreen`).
   - Manage usable aluminum bar remnants (`RemnantsScreen`) and scan cut pieces via QR (`QrPieceScannerScreen`).
2. **Manage Projects & Measurement Units (`ProjectDetailScreen` & `UnitEditorScreen`):**
   - Create/edit/delete projects (with full cascade deletion of all related units, requirements, cut plans, remnants, and draft orders).
   - Add window/door units with exact dimensions, profile system, glazing mode, screen mesh, and accessories.
   - Run 1D 660 cm bar cut optimization (`CutPlanScreen`), reuse workshop remnants, and export cutting/sticker PDFs.
3. **Review & Edit Project Materials Requirements (`ProjectRequirementsScreen` — §5.4):**
   - Auto-generate the project's required materials from its units and saved cut plan (new 660 cm aluminum bars, glass $\text{m}^2$, accessories, and commercial `roll` units for mesh/brush).
   - Enter workshop stock (`inStockQty` — «لدي في الورشة») so `toBuyQty` («الكمية المطلوب شراؤها») computes automatically as $\max(\text{requiredQty} - \text{inStockQty}, 0)$.
   - Manually override `toBuyQty`, add custom manual lines (`source = manual`), or delete/dismiss lines, with safe regeneration merge if project units change later.
4. **Execute the 3 Post-Requirements Actions (`ProjectRequirementsScreen` — §5.5):**
   - **Option 1 — Download Requirements PDF (`RequirementsPdfGenerator`):** Download/print a formal Arabic RTL PDF grouped by category for items with `toBuyQty > 0`.
   - **Option 2 — Send In-App Request to Supplier (`OrdersRepository.createOrder`):** Select a supplier from the directory and send an in-app order (`status: sent`) with `unitPrice = 0` for the supplier to review and price.
   - **Option 3 — Send PDF & Summary via WhatsApp:** Select a supplier, launch WhatsApp (`wa.me`) pre-filled with the formatted order summary, and share/attach the generated PDF file.
5. **Track Orders & Approve Supplier Quotes (`OrdersListScreen` & `OrderDetailScreen` — §5.5):**
   - Track all sent orders in real time (`sent` $\to$ `quoted` $\to$ `confirmed` $\to$ `preparing` $\to$ `completed` / `cancelled`).
   - When a supplier responds (`status: quoted`), inspect the item-by-item availability (`متوفر` / `غير متوفر`), modified quantities (`المتوفر` vs `المطلوب`), manual unit prices, item notes, general supplier note, and total amount.
   - Approve & confirm the quote (`status: confirmed`), cancel the order (`status: cancelled`), or download the priced Purchase Order PDF (`PurchaseOrderPdfGenerator`).

---

### B. Supplier (`supplier`) Capabilities (No Stock / No Price Lists)
1. **Receive Incoming Workshop Order Requests (`SupplierDashboardScreen` & `SupplierOrdersScreen`):**
   - View all incoming requests sent by workshops (`status: sent`, `quoted`, `confirmed`, `preparing`, `completed`).
2. **Interactive Line-by-Line Review, Quantity Modification & Manual Pricing (`OrderDetailScreen`):**
   - Toggle availability per item (**`متوفر`** / **`غير متوفر`** — `isAvailable`).
   - Modify the supplied quantity (`qty`) if only partial quantity is available compared to `requestedQty`.
   - Enter the unit price manually (`unitPrice` in `SAR`) for each available item; the app calculates each `lineTotal` and the order's `totalAmount` live.
   - Write per-item notes (`supplierNote`) and a general order note (`supplierResponseNote`).
   - Submit the quote back to the workshop owner (`status: quoted`).
3. **Update Fulfilment Status After Owner Approval:**
   - Once the owner approves the quote (`status: confirmed`), update the status to `preparing` («قيد التجهيز») and `completed` («مكتمل») or export the Purchase Order PDF.

---

## 2. Detailed Specifications (§5.4 & §5.5)

### 2.1 Project Materials Requirements (`lib/features/requirements/`) — §5.4
- **Path:** `workshops/{workshopId}/projects/{projectId}/requirements/{lineId}`
- **Model `RequirementLine`:**
  - `id`, `itemId`, `engineItemCode`, `nameArabic`, `category`, `requiredQty`, `inStockQty`, `toBuyQty`, `isToBuyOverridden`, `needsReviewAfterRegen`, `unit`, `note`, `source` (`auto` | `manual`), `dismissed`, `createdAt`, `updatedAt`.
- **Safe Regeneration Merge (`RequirementsService.mergeRegeneratedLines`):**
  - Preserves owner's `inStockQty`, `note`, manual lines (`source = manual`), and dismissed lines (`dismissed = true`).
  - Recomputes `toBuyQty = max(newRequiredQty - inStockQty, 0)` for non-overridden lines, and flags overridden lines with `needsReviewAfterRegen = true`.

### 2.2 Post-Requirements 3-Option Flow & Supplier Interactive Quoting (`lib/features/orders/`) — §5.5
- **Path:** `orders/{orderId}`
- **Model `OrderModel` & `OrderLineItem`:**
  - `OrderStatus`: `draft`, `sent`, `quoted`, `confirmed`, `preparing`, `completed`, `cancelled`.
  - `OrderLineItem`: `itemId`, `nameArabic`, `category`, `requestedQty`, `qty`, `unit`, `isAvailable`, `unitPrice`, `note`, `supplierNote`, `effectiveQty`, `lineTotal`.
  - `OrderModel`: `id`, `orderNumber`, `projectId`, `projectName`, `workshopId`, `workshopName`, `workshopPhone`, `workshopLocation`, `supplierId`, `supplierName`, `status`, `items`, `currency`, `totalAmount`, `supplierResponseNote`, `statusHistory`.

### 2.3 Emulator Seed Script (`scripts/seed_phase6.ts`)
- Seeds:
  1. **Workshop Owner (`owner@meqyas.com` / `Owner123`)** and active workshop `w_al_noor` («ورشة النور للألمنيوم والزجاج»).
  2. **Suppliers (`supplier@meqyas.com` / `Supplier123`)** in `suppliers` collection with contact info & WhatsApp numbers (no catalog prices or stock subcollections).
  3. **Sample Project (`p_villa_yasmin` — «مشروع فيلا الياسمين»)** with window units and finalized `requirements` lines.
  4. **Sample Orders (`ord_yasmin_sent` & `ord_yasmin_quoted`)** to test both the Supplier pricing workflow and the Owner quote approval workflow immediately.
