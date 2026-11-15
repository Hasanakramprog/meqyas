# Meqyas (مقياس) — Project Handoff & Architecture Guide

Welcome to **Meqyas (مقياس)** — an Arabic-first (RTL), offline-capable Flutter & Firebase application for **aluminum & glass fabrication workshops**, featuring a pure-Dart parametric calculation engine, 1D bar-cutting optimizer, shelf remnant tracking, material requirements planning, and supplier procurement workflows.

This document is designed for **both human developers and AI coding agents** picking up the codebase.

---

## 1. Tech Stack & Key Dependencies

| Layer | Technology / Package | Version / Notes |
|---|---|---|
| **Framework** | Flutter (Dart SDK) | Dart `^3.13.5` (`pubspec.yaml`) |
| **State Management** | `flutter_riverpod` | `^3.4.3` |
| **Navigation** | `go_router` | `^18.1.0` (`lib/app/router/app_router.dart`) |
| **Core Math & Engine** | `maqyas_engine` (local package) | `packages/maqyas_engine` — **Pure Dart** (zero Flutter/Firebase imports) |
| **Backend / Auth / DB** | Firebase (`meqyas-app-2026`) | `firebase_core ^5.0.0`, `firebase_auth ^7.0.0`, `cloud_firestore ^7.0.0`, `cloud_functions ^7.0.0`, `firebase_storage ^14.0.0` |
| **PDF & Printing** | `pdf`, `printing` | `pdf ^3.13.1`, `printing ^5.15.1` |
| **QR Scanning** | `mobile_scanner` | `^7.4.2` |
| **Excel / Files / Links** | `excel`, `file_picker`, `url_launcher` | `excel ^4.0.6`, `file_picker ^11.0.2`, `url_launcher ^6.3.1` |
| **Typography & Locale** | `Cairo` font (`assets/fonts/`), `intl` | `^0.20.3`, RTL (`TextDirection.rtl`) |

---

## 2. Repository Structure

```text
meqyas/
├── lib/
│   ├── main.dart                         # App entry point & Firebase initialization
│   ├── firebase_options.dart             # FlutterFire config for meqyas-app-2026
│   ├── app/
│   │   ├── router/app_router.dart        # GoRouter routes (owner, supplier, admin, scanner)
│   │   └── theme/app_colors.dart         # Dark/light theme palette
│   ├── core/                             # Offline Firestore helpers, sync banners, shared widgets
│   └── features/
│       ├── admin/                        # Admin dashboard & rule approval
│       ├── auth/                         # Firebase Auth & role routing
│       ├── cart/                         # Step 3: Project-scoped cart & supplier ordering
│       ├── catalog/                      # SeedCatalog & workshop material catalog (Excel import/export)
│       ├── cut_optimization/             # Step 4: CutPlanScreen, RemnantsScreen, ItemGroupSection
│       ├── cut_scanner/                  # QR scanner & QrCutPayloadParser
│       ├── dashboard/                    # OwnerDashboardScreen (Projects, Supply, Tools, Remnants tabs)
│       ├── home/                         # Home / entry shell
│       ├── inventory/                    # Workshop stock tracking
│       ├── orders/                       # Supplier orders & WhatsApp / in-app quote flows
│       ├── pricing/                      # Material & project pricing
│       ├── projects/                     # Step 1: ProjectDetailScreen, ProjectUnit, ProjectStepperBar
│       ├── reports/                      # PDF & QR label generators
│       ├── requirements/                 # Step 2: ProjectRequirementsScreen & RequirementsService
│       ├── rules/                        # WorkshopRulesScreen, AdminRulesScreen, RulesRepository
│       ├── supplier_portal/              # Supplier quote & order fulfillment UI
│       └── suppliers/                    # Supplier directory & price lists
├── packages/
│   └── maqyas_engine/                    # Pure-Dart calculation & optimization library
│       ├── lib/
│       │   ├── maqyas_engine.dart        # Barrel exports
│       │   └── src/
│       │       ├── ast/                  # Expression tokenizer, parser, evaluator
│       │       ├── engine/               # CalculatorEngine (formulas + accessories + glass)
│       │       ├── graph/                # DependencyGraph for rule ordering
│       │       ├── models/               # CalculationRule, UnitSpecification, CutPiece, OptimizationModels
│       │       ├── optimizer/            # CutOptimizer (1D FFD + remnant-first) & MeshOptimizer
│       │       └── rules/                # SeedRules, RuleValidator, ConflictDetector, RuleSandbox
│       └── test/                         # 30 pure-Dart unit tests
├── functions/                            # Firebase Cloud Functions
├── scripts/                              # Emulator & Firestore seed scripts (seed_cloud.mjs, seed_rules.ts, etc.)
├── firestore.rules                       # Cloud Firestore Security Rules
├── firestore.indexes.json                # Composite indexes
├── firebase.json                         # Firebase project & emulator ports (Auth 9099, Firestore 8085, Functions 5001)
└── test/                                 # 27 Flutter unit & widget tests
```

---

## 3. Core Domain Flows & Business Rules

### A. The 4-Step Project Wizard
Every project follows a 4-step workflow tracked by `ProjectStepperBar` (`lib/features/projects/presentation/widgets/project_stepper_bar.dart`):

1. **`1 · القياسات` (`ProjectDetailScreen`)**
   - Add/edit windows/facades (`ProjectUnit`), dimensions (`W`, `H`, `quantity`), profile system, color, glass specs, and per-window overrides (`unit_accessories_mesh_section.dart` for rollers, corners, gasket, putty, mesh type/width).
   - Project-level defaults live in `ProjectDefaults` (`Project`); per-unit overrides are resolved via `ProjectUnit.toEngineSpec(defaults)` and `ProjectUnit.resolveEffectiveRules(...)`.
   - Inline width/height inputs use a `FocusNode` + 450 ms debounce so typing multi-digit numbers never triggers premature reloads.

2. **`2 · مراجعة البضاعة` (`ProjectRequirementsScreen`)**
   - **Auto-syncs in the background**: Watches `projectDetailProvider`, `projectUnitsProvider`, `savedCutPlanProvider`, and `remnantsProvider`.
   - Whenever units, colors, or shelf remnants change, `RequirementsService.computeProjectRequirements` runs `CutOptimizer` silently (`forceLiveCut: true`, `availableRemnants: ...`) to compute exact new 660 cm bars needed after subtracting usable shelf remnants.
   - Allows entering `inStockQty` (workshop inventory) and editing `toBuyQty`, exporting requirements PDF, and advancing to Step 3 (`upsertProjectCartItems`).

3. **`3 · السلة والطلب` (`CartScreen`)**
   - Currently scoped to the **single active project** (`sourceProjectId == widget.projectId`) when opened from a project wizard.
   - Lets the owner select a supplier, review/send an in-app quote order or WhatsApp order, and proceed to Step 4.

4. **`4 · القصّ` (`CutPlanScreen`)**
   - Automatically recomputes `CutOptimizer.optimize(...)` whenever units, piece colors, optimizer settings, or `availableRemnants` (`remnantsSignature`) change.
   - Minimal AppBar (back + title only). Footer has two actions:
     - **`قص`** (`_savePlan`): Saves the plan to Firestore, marks consumed remnants as `used`, and creates new reusable shelf remnants (`>= minRemnantCm`).
     - **`الانتقال إلى قائمة المشاريع`**: Navigates to `/dashboard/owner` (`OwnerDashboardScreen`).

---

### B. Color Matching Rules (Strict Isolation)
- Colors are stored as English codes (`'white'`, `'black'`, `'champagne'`, `'bronze'`, `'grey'`, `'wood'`) on `Project` / `ProjectUnit`, and sometimes in Arabic (`'أبيض'`, `'أسود'`, etc.) on manual `RemnantDoc` entries.
- **`normalizeProfileColor(raw)`** and **`profileColorLabelAr(raw)`** in `packages/maqyas_engine/lib/src/models/optimization_models.dart` normalize all aliases to canonical keys.
- **`CutOptimizer.optimize`** groups both `CutPiece`s and `RemnantStock`s by **`(canonicalBarItemCode, normalizedColor)`**:
  - A white window can **only** consume white remnants and never shares a 660 cm bar with a black window.
- **`RequirementsService`** groups:
  - Aluminum bars by `(canonicalBarItemCode, normalizedColor)` (`auto_al_<itemCode>_<color>`).
  - Visible/colored accessories (`glass_handle`, `screen_handle`, `shankal_plug`, `water_plug`, `rakilaj_plug`, `fixed_plug`) by `(code, normalizedColor)`.
  - Neutral internal hardware (`short_screws`, `long_screws`, rollers, `corners`, `gasket`, `putty`) project-wide without color splitting.
  - Mesh brush rolls (`brush_450`, `brush_900`) by `unit.brushColor`.

---

### C. Shared Profile Bar: `screen_vertical` + `screen_horizontal` → `screen_sash`
- In `SeedRules` & `CalculatorEngine`, **`screen_vertical`** (`درفة منخل عامودي`, `H - 4.1`) and **`screen_horizontal`** (`درفة منخل أفقي`, `kaab_len + 2`) remain **two separate rules** because their length formulas differ.
- In `CutOptimizer`, `RequirementsService`, `SeedCatalog`, and `RemnantsScreen`, **`canonicalBarItemCode(itemCode)`** maps both to **`'screen_sash'`** (`درفة منخل`):
  - Vertical and horizontal screen pieces (of the same color) share the **same 660 cm bars** and the **same shelf remnants**.
  - `ItemGroupSection` displays the group header as **`درفة منخل — <color>`**, while each individual cut chip keeps its direction tag (**`عامودي`** or **`أفقي`**) so the workshop technician knows which cut is vertical vs. horizontal.
  - In `2 · مراجعة البضاعة` and `3 · السلة والطلب`, they appear as one unified bar item: **`درفة منخل 2000 (قضيب 6.6م) — <color>`**.

---

### D. Remnants Tab in Owner Dashboard
- `OwnerDashboardScreen` (`lib/features/dashboard/presentation/owner_dashboard_screen.dart`) hosts 4 in-place tabs via `IndexedStack`:
  - `0`: المشاريع والقياسات
  - `1`: التوريد والموردين
  - `2`: أدوات وإعدادات الورشة
  - `3`: مخزن الفضلات (`RemnantsScreen(workshopId: activeWorkshopId, embedded: true)`)

---

## 4. Setup, Commands & Verification

### Install Dependencies
```bash
flutter pub get
cd packages/maqyas_engine && dart pub get && cd ../..
```

### Run Tests & Static Analysis
Always run all three checks before committing:
```bash
# 1. Pure-Dart engine tests (30 tests)
cd packages/maqyas_engine && dart test

# 2. Flutter static analyzer (must be 0 issues)
flutter analyze

# 3. Flutter unit & widget tests (27 tests)
flutter test
```

### Local Firebase Emulators & Cloud Seeding
- Emulator ports configured in `firebase.json`: Auth (`9099`), Functions (`5001`), Firestore (`8085`), Storage (`9199`), UI (`4000`).
- Helper scripts in `scripts/`:
  - `./scripts/start_emulators.sh` — start local Firebase emulators
  - `./scripts/seed_rules.sh` / `node scripts/seed_cloud.mjs` — seed rules and default data

---

## 5. Rules & Guidelines for Future AI Agents

1. **Keep `packages/maqyas_engine` 100% Pure Dart**: Never import `flutter/*`, `cloud_firestore`, or Firebase packages inside `packages/maqyas_engine`.
2. **Keep Rules & Seed Scripts Synchronized**: If you add/modify default calculation rules in `SeedRules` (`packages/maqyas_engine/lib/src/rules/seed_rules.dart`), also update `scripts/seed_cloud.mjs` and `scripts/seed_rules.ts`.
3. **Never Break `canonicalBarItemCode` or `normalizeProfileColor`**:
   - Any new profile or remnant matching must pass through `canonicalBarItemCode(...)` and `normalizeProfileColor(...)`.
   - Keep `screen_vertical` and `screen_horizontal` distinct in `SeedRules`/`CalculatorEngine` so formulas stay editable independently, while `CutOptimizer` and `RequirementsService` merge them via `screen_sash`.
4. **Firestore Security Rules**: Edit `firestore.rules` carefully and test against emulators; keep `workshopId` scoping intact.
5. **Verify Before Finishing**: Always run `cd packages/maqyas_engine && dart test`, `flutter analyze`, and `flutter test` after your final edit.
