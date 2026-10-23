# Phase 5 — Cut Optimization, Labels & PDF: Implementation Plan

**Branch:** `feature/phase-5-cut-optimization`
**Spec §:** 8.8, 8.9 (optimizer), 12 (reports), 13 (UI/UX)
**DoD (spec §15):** Optimizer respects `660 / 0.5 / 4 / 50`; Arabic PDF renders correctly on device/web.

---

## Your Decisions (Answer Before Full Implementation)

| Topic | Decision Needed | Default Used If No Answer |
|---|---|---|
| PDF header logo | Upload via Firebase Storage, or text-only header? | Text-only |
| PDF prices | Show unit prices on cut list, or quantities only? | Quantities only (prices in Phase 6) |
| Label format | Thermal (ZPL) or A4 sheet with multiple labels? | A4 grid (3×8 = 24 labels/page) |
| Barcode type | QR only, or Code128 barcode + QR? | QR only |
| Cutting settings scope | Apply to current workshop only, or all owner's workshops? | Current workshop only |
| Remnant lifecycle | Mark remnant as "used" manually or auto when a cut plan consumes it? | Manual by owner |
| Cut plan save policy | Save every generated plan, or only on explicit owner tap? | Explicit save only |

> **None of these block development.** Defaults shown above will be used until you decide.

---

## What Already Exists ✅ (No Rebuild Needed)

| Component | File | Notes |
|---|---|---|
| `CutOptimizer` — First-Fit-Decreasing algorithm | `packages/maqyas_engine/lib/src/optimizer/cut_optimizer.dart` | Complete, needs dynamic wiring |
| `OptimizationResult`, `BarCuttingPlan`, `PlannedCut`, `OptimizationSummary` | `packages/maqyas_engine/lib/src/models/optimization_models.dart` | Complete |
| `BarLayoutView` widget — visual bar with sequential cut chips | `lib/features/projects/presentation/widgets/bar_layout_view.dart` | Complete |
| `cuttingSettingsProvider(workshopId)` — streams cutting settings from Firestore | `lib/features/rules/data/rules_repository.dart` | Complete |
| Firestore: `workshops/{id}/settings/cutting` + `systemConfigs/cuttingOptimizer` | Data model | Complete |

---

## Gaps Found in Current Code

> **Gap 1 — Remnants are computed but never persisted**
> `BarCuttingPlan.isRemnantUseful` is computed correctly, but remnants are never written to Firestore.
> They disappear when the screen is closed.

> **Gap 2 — Cut plan is never saved to Firestore**
> Generated fresh every time. The owner cannot view a past plan or generate a PDF from a saved plan.

> **Gap 3 — "Newer rules available" banner is missing**
> The engine records `ruleVersionIdsUsed` on each result, but no banner is shown in the UI when newer rules exist.

~~Gap 4 (Cutting Machine Settings tab) — ✅ Already built in `WorkshopRulesScreen` as `_CuttingSettingsForm` (lines 1082–1450)~~
~~Gap 5 (Admin Global Cutting Optimizer form) — ✅ Already built in `AdminRulesScreen` as `_GlobalOptimizerSettingsView` (lines 930–1040)~~

---

## 1. Engine (`packages/maqyas_engine`) — Minor Additions Only

The core algorithm is complete. Only two small additions needed:

- **`CutPiece.color`** — each piece needs its own color so pieces of different colors are grouped into separate bars.
- **`BarSource`** — a new concept: a bar can be either a `full_bar` (new 660cm bar) or a `remnant` (an existing piece from the stock shelf). The optimizer must know which remnants are available before packing.
- **`PlannedCut.fromRemnantId`** — nullable field. If a cut was satisfied by a remnant, this holds the remnant document ID.
- **`BarCuttingPlan.source`** — either `full_bar` or `remnant:{remnantId}:{lengthCm}cm`.

### Remnant-Aware Optimization Algorithm (NEW — Core Feature)

Before the standard First-Fit-Decreasing runs, the optimizer checks available remnants:

```
1. Load available remnants from Firestore for this workshopId
   (state == 'available', grouped by itemCode + color)

2. For each item group:
   a. Sort available remnants descending by length (longest first)
   b. For each needed cut piece (largest first):
      - Check if any available remnant can fit this cut (remnant.lengthCm >= cut.lengthCm + kerf)
      - If yes → assign cut to that remnant bar, mark remnant as 'pending' (reserved for this plan)
      - If no → fall through to standard FFD with full bars

3. Remaining unassigned cuts → standard First-Fit-Decreasing on new full bars

4. Result contains BOTH:
   - Bars sourced from remnants (labeled: «من فضلة مخزنة»)
   - Bars sourced from new full 660cm bars
```

**Summary card shows:**
- «قضبان جديدة مستخدمة: 3»
- «فضلات مُعاد استخدامها: 2» (saves buying new bars)
- «تم توفير: 2 قضيب (1320 سم)»

**This is NOT optional — it is the core value of the remnants feature.**

---

## 2. Firestore — New Collections

```
workshops/{workshopId}/cutPlans/{planId}
  projectId          string
  projectName        string
  generatedAt        timestamp
  generatedBy        string (uid)
  pdfUrl             string? (null until PDF is uploaded)
  summary {
    totalBarsNeeded, totalCutLengthCm, totalTrimLossCm,
    totalKerfLossCm, totalScrapCm, totalReusableRemnantsCm, scrapPercentage
  }
  itemGroups: [
    {
      itemCode, nameArabic, color,
      bars: [
        {
          barNumber,
          sourceKind: 'full_bar' | 'remnant',   // NEW
          sourceRemnantId: string?,              // NEW — which remnant doc was used
          sourceRemnantLengthCm: double?,        // NEW — original remnant length
          cuts: [
            {
              nameArabic, lengthCm, pieceIndex, unitTag,
              fromRemnantId: string?             // NEW — same as bar's sourceRemnantId
            }
          ],
          totalCutsLengthCm, kerfLossCm, remainingLengthCm, isRemnantUseful
        }
      ]
    }
  ]
  oversizedCuts: [{nameArabic, lengthCm, unitTag}]

workshops/{workshopId}/remnants/{remnantId}
  itemCode           string
  nameArabic         string
  color              string
  lengthCm           double
  sourceBarNumber    int
  sourcePlanId       string
  sourceProjectId    string
  state              'available' | 'used'
  createdAt          timestamp
  usedAt             timestamp?
```

> **Note:** `cutPlans` and `remnants` live under the workshop (not under a project) because a remnant from Project A can be reused in Project B.

---

## 3. Firestore Security Rules — Additions

```js
// Cut plans: owner read/write under own workshop
match /workshops/{workshopId}/cutPlans/{planId} {
  allow read, write: if isOwnerOf(workshopId) && isActive();
}

// Remnants: owner read/write under own workshop
match /workshops/{workshopId}/remnants/{remnantId} {
  allow read, write: if isOwnerOf(workshopId) && isActive();
}
```

---

## 4. Fix: Dynamic `CutOptimizer` via Provider

### Files to fix:
- `lib/features/projects/presentation/screens/unit_editor_screen.dart`
- `lib/features/projects/presentation/screens/project_detail_screen.dart`
- Any other file calling `CutOptimizer()` or `const CutOptimizer()`

### Pattern to use everywhere:
```dart
// In any widget/controller that has ref access:
final settings = ref.watch(cuttingSettingsProvider(workshopId));
final optimizer = CutOptimizer(
  barLengthCm:  settings.barLengthCm,
  trimLossCm:   settings.trimLossCm,
  kerfPerCutCm: settings.kerfPerCutCm,
  minRemnantCm: settings.minRemnantCm,
);
final result = optimizer.optimize(pieces: cutPieces);
```

---

## 5. New Feature: Cut Optimization UI (`lib/features/cut_optimization/`)

### Folder structure:
```
lib/features/cut_optimization/
  data/
    cut_plan_repository.dart       # Firestore save/load for cutPlans & remnants
  presentation/
    screens/
      cut_plan_screen.dart         # Main cut plan view for a project
      remnants_screen.dart         # View & manage all workshop remnants
      cutting_settings_screen.dart # Bar length / kerf / trim inputs (owner)
    widgets/
      cut_summary_card.dart        # Summary strip: bars, waste %, remnants
      item_group_section.dart      # Expandable per-item section with BarLayoutView
      remnant_tile.dart            # Single remnant card (length, source, state chip)
      oversized_cuts_panel.dart    # Warning panel for cuts that exceed bar length
```

### 5.1 `CutPlanScreen` — route: `/workshop/:workshopId/projects/:projectId/cut-plan`

Triggered from `ProjectDetailScreen` via «خطة القص» button.

Layout:
1. **Summary card** at top: total bars, waste %, reusable remnants length.
2. **Per-item expandable sections**: each shows all bars for that item using `BarLayoutView`.
3. **Oversized cuts warning** (if any piece > usable bar length).
4. **Action buttons** row:
   - «حفظ الخطة» → writes `cutPlans` document + `remnants` documents to Firestore.
   - «تصدير PDF» → generates PDF, uploads to Storage, updates `pdfUrl`.
   - «طباعة بطاقات» → generates QR label sheet PDF.

### 5.2 `RemnantsScreen` — "مخزن الفضلات" — route: `/workshop/:workshopId/remnants`

> **This is a stock/shelf screen** — the owner sees all leftover aluminum pieces currently available on the workshop floor, exactly like a mini inventory. The goal: before opening a new full 660cm bar, the worker checks here first.

Accessible from Workshop Dashboard sidebar or from the cut plan screen directly.

#### Layout — Stock View:

**Top summary bar:**
- Total available remnants count
- Total available length (cm) grouped by item code
- e.g. «سكة 2000: 3 فضلات — 243 سم متاح»

**Per-item-code section (grouped, collapsible):**
Each group (e.g. "سكة 2000 بحاجب") shows:

| Column | Content |
|---|---|
| الطول | e.g. `76.5 سم` (large, prominent) |
| اللون | color chip |
| المصدر | project name it came from |
| التاريخ | when it was saved |
| الحالة | `متاح` (green chip) / `مستخدم` (grey chip) |
| Action | «تم استخدامها» button → marks as used |

**Filter/Search bar:**
- Filter by item code (dropdown)
- Filter by color
- Toggle: show only «متاح» / show all

**Empty state:**
- «لا توجد فضلات متاحة حالياً» with icon

#### Firestore data shown:
Each tile = one document from `workshops/{workshopId}/remnants/{id}`:
```
itemCode, nameArabic, color, lengthCm,
sourceProjectId, sourceProjectName, sourcePlanId,
state: 'available' | 'used',
createdAt, usedAt?
```

#### Behavior:
- When owner taps «تم استخدامها» → updates `state: 'used'` + `usedAt: now` in Firestore
- Used remnants are greyed out and moved to bottom (or hidden by default)
- A remnant marked as used **cannot be un-used** (physical material is gone)
- Total available stock per item is computed client-side from `state == 'available'` docs

### 5.3 `CuttingSettingsScreen` — inside Workshop Settings

Inputs:
| Field | Arabic Label | Default |
|---|---|---|
| `barLengthCm` | طول القضيب الخام (سم) | 660 |
| `trimLossCm` | هدر التشذيب من الطرفين (سم) | 4 |
| `kerfPerCutCm` | سماكة شفرة المنشار (سم) | 0.5 |
| `minRemnantCm` | أقل طول فضلة صالحة (سم) | 50 |

- **Live preview**: «الطول الصالح للقص = barLengthCm − trimLossCm = X سم»
- **«تطبيق على جميع الورش التابعة لي»** checkbox.
- **«استعادة الإعدادات الافتراضية»** button → deletes `workshops/{workshopId}/settings/cutting`, provider falls back to `systemConfigs/cuttingOptimizer`.
- Writes to `workshops/{workshopId}/settings/cutting`.

### 5.4 Admin: Global Cutting Optimizer Form

Add inside `AdminRulesScreen` (fill the existing `TODO` placeholder):
- Same 4 fields as above.
- Writes to `systemConfigs/cuttingOptimizer`.
- Visible only to admins.

---

## 6. Fix: "Newer Rules Available" Banner

Add to `ProjectDetailScreen` and `UnitEditorScreen`.

**Logic:**
```dart
// After loading unit result:
final usedVersionIds = unit.result?.ruleVersionIdsUsed ?? [];
final currentApprovedIds = ref.watch(effectiveRulesProvider(workshopId))
    .asData?.value.map((r) => '${r.id}_v${r.version}').toSet() ?? {};
final hasNewerRules = usedVersionIds.any((id) => !currentApprovedIds.contains(id));
```

**Banner UI (when `hasNewerRules == true`):**
- Arabic text: «تتوفر قواعد حساب أحدث لهذه الوحدة»
- Button: «إعادة الحساب بأحدث القواعد» → recalculates and saves a new result snapshot.

---

## 7. Arabic PDF Export (`lib/features/reports/`)

Use the `pdf` package (`^3.x`) — already in spec §3.

### Add to `pubspec.yaml`:
```yaml
dependencies:
  pdf: ^3.10.0
  printing: ^5.12.0
  barcode_widget: ^2.0.0   # for QR labels
```

### PDF 1: Cut List (`pdf_generator.dart`)

Pages:
1. **Header** — workshop name, logo (if available), project name, date, document number.
2. **Summary table** — item | bars needed | total length (cm) | waste % | reusable remnants (cm).
3. **Per-item detail** — bar number | cuts in order | length each | kerf | remaining length.
4. **Footer** — «طُبع بتطبيق مقياس» + page number.

### PDF 2: QR Labels (`label_generator.dart`)

- A4 grid: 3 columns × 8 rows = 24 labels per page.
- Each label contains:
  - Project name + unit tag
  - Item Arabic name
  - Length in cm (large font)
  - Bar number
  - QR code: `{"p":"projectId","u":"unitId","i":"itemCode","l":117.0,"b":1}`

### Arabic RTL rendering notes:
- **Font**: Bundle Cairo TTF font (spec §3). Load via `TtfFont` in the `pdf` package.
- **Direction**: Use `pw.Directionality(textDirection: pw.TextDirection.rtl)` as wrapper.
- **Numbers**: Arabic numerals mixed with Arabic text work fine; avoid embedding raw bidi text inside non-RTL containers.
- **All strings** must come from ARB files — no hardcoded Arabic in Dart.

### Upload flow:
```dart
final ref = FirebaseStorage.instance
    .ref('workshops/$workshopId/cut-plans/$planId/cut_plan.pdf');
await ref.putData(pdfBytes);
final url = await ref.getDownloadURL();
// Update Firestore: cutPlans/{planId}.pdfUrl = url
```

---

## 8. Routing — New Routes

Add to `app_router.dart`:

```dart
GoRoute(
  path: '/workshop/:workshopId/projects/:projectId/cut-plan',
  builder: (context, state) => CutPlanScreen(
    workshopId: state.pathParameters['workshopId']!,
    projectId: state.pathParameters['projectId']!,
  ),
),
GoRoute(
  path: '/workshop/:workshopId/remnants',
  builder: (context, state) => RemnantsScreen(
    workshopId: state.pathParameters['workshopId']!,
  ),
),
GoRoute(
  path: '/workshop/:workshopId/settings/cutting',
  builder: (context, state) => CuttingSettingsScreen(
    workshopId: state.pathParameters['workshopId']!,
  ),
),
```

---

## 9. Verification — DoD Checklist

| # | Check | Expected Result |
|---|---|---|
| 1 | Run optimizer for 120×150 window — no remnants in stock | Correct bar count; no oversized pieces; waste % shown |
| 2 | Change kerf to 0.3 in cutting settings | Optimizer immediately uses 0.3; bar usage updates |
| 3 | Piece > 656 cm | Shown in oversized warning panel; not packed into any bar |
| 4 | Remnant ≥ 50 cm after plan save | Saved to `remnants` collection with `state: available` |
| 5 | Remnant < 50 cm | Shown as «هدر» (scrap); NOT saved to remnants collection |
| 6 | Save cut plan | `cutPlans` document written with correct structure |
| 7 | **Remnant reuse** — add a 100cm «سكة» remnant to stock, then generate a plan needing a 95cm cut | The 95cm cut is assigned to the remnant bar, labeled «من فضلة مخزنة»; no new full bar opened for it |
| 8 | Remnant bar label | Bar chip shows «فضلة: 100سم → استُخدم 95سم + 0.5 kerf = 4.5سم متبقي» |
| 9 | Mark remnant as used in RemnantsScreen | `state: used`, `usedAt` written; remnant no longer appears as available |
| 10 | Summary card comparison | Shows «قضبان جديدة: X» vs «فضلات مُعاد استخدامها: Y — وُفِّر Z قضيب» |
| 11 | Generate PDF | Arabic RTL renders; Cairo font used; remnant-sourced bars labeled differently |
| 12 | Print labels | QR codes decode correctly; label shows «من فضلة» tag when applicable |
| 13 | «تتوفر قواعد أحدث» banner | Appears after admin approves a new rule version for a saved unit |
| 14 | `flutter analyze` | Zero errors |
| 15 | `dart test` (engine package) | All existing test vectors still pass |

---

## 10. Suggestions (Not in Spec — Optional Improvements)

~~Suggestion 1 (Remnant Reuse) — ✅ Promoted to CORE feature. See Section 1 engine algorithm and Section 5.2 RemnantsScreen.~~

### 💡 Suggestion 2 — Share via WhatsApp
Add a share button that opens `wa.me` link with a plain-text summary of bars needed per item. Useful for workers without the app.

### 💡 Suggestion 3 — Multi-project Cut Plan
Batch multiple projects into one cut plan to pool same-color + same-item pieces. Reduces bar count for large workshop days.

### 💡 Suggestion 4 — Barcode Scanner (Future Phase)
Scan a QR label → open the unit it belongs to. Good for workshop floor traceability.

### 💡 Suggestion 5 — Cut Plan History
List all saved cut plans per workshop. Owner can reopen any past plan and regenerate its PDF.

---

## 11. Out of Scope for Phase 5

- Stock deduction when a cut plan is executed (→ Phase 6, requires `confirmOrder`).
- Supplier PDF with prices (→ Phase 6).
- Push notification when PDF is ready (→ Phase 8).
- Other profile systems (→ Phase 8).
- Remnant auto-reservation from cut plan (Suggestion 1 above — optional).

---

## Estimated Build Order

| Step | Task | Est. Time |
|---|---|---|
| 1 | Fix `const CutOptimizer()` → dynamic provider everywhere | 30 min |
| 2 | `CuttingSettingsScreen` + Admin global cutting form | 1–2 hrs |
| 3 | `CutPlanRepository` (Firestore save/load for cutPlans & remnants) | 1 hr |
| 4 | `CutPlanScreen` with `BarLayoutView` + save button | 2–3 hrs |
| 5 | `RemnantsScreen` | 1 hr |
| 6 | Cairo font setup + Arabic PDF cut list | 2–4 hrs |
| 7 | QR label sheet PDF | 1–2 hrs |
| 8 | «تتوفر قواعد أحدث» banner | 1 hr |
| 9 | Add new routes to `app_router.dart` | 30 min |
| 10 | DoD verification (all 12 checks above) | 1–2 hrs |
| **Total** | | **~12–17 hrs** |
