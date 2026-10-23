# Phase 4 — Admin Rules Management: Implementation Plan

**DoD (spec §15):** Adding a rule in admin changes results **without an app release**; conflicts are blocked.

## Your decisions
| Topic | Decision |
|---|---|
| Approval | Single-step: any admin can approve their own draft |
| Conflicts | Block approval if same system + itemCode + priority **and** both match a unit in an automatic test matrix |
| Admin UI | Same Flutter app, wide layout for tablet/web (editor + sandbox side by side), still usable on phone |
| Old projects | Keep pinned rule versions; show "newer rules available" banner + "Recalculate with latest rules" |
| Owner Customization | Owner uses admin rules by default, can tweak formulas for their own workshop, and can restore to admin defaults at any time |
| Cut Optimizer Settings | Dynamic: Admin defines global defaults (660/4/0.5/50); Owner can override for their workshop machinery and restore to default at any time |

---

## Gap found in the current code
> [!IMPORTANT]
> The engine **hardcodes** the item list (`track`, `u_profile`, `kaab`…), Arabic names, profile types and cut angles in `calculator_engine.dart`.
> A new item added in admin would be ignored. This must change first, or the DoD can't be met.

---

## 1. Engine (`packages/maqyas_engine`) — pure Dart
- **`CalculationRule`**: add display metadata
  - `nameArabic`, `outputKind` (`profile` | `glass_height` | `glass_width` | `intermediate`), `profileType`, `cutAngleLeft/Right`, `notes`, `createdBy`, `approvedBy`
  - `RuleStatus`: `draft`, `approved`, `archived`
  - `fromMap` / `toMap` (no Firebase types inside the engine)
- **`CalculatorEngine`**: target items = every distinct `itemCode` in the approved rules for the unit's system (no hardcoded list). Names/angles come from the rule.
  - Screen items still only apply when `hasScreen` (via rule conditions).
- **New `RuleValidator`**:
  - Syntax check of conditions + formulas (existing AST parser, no eval)
  - Unknown-variable check against the allowed list (`W`, `H`, `N`, options, `*_len`, `*_qty`)
  - Cycle check across the system's rules (existing `DependencyGraph`)
  - Returns Arabic messages per field
- **New `ConflictDetector`**: runs a candidate rule + approved rules over a test matrix
  - Sizes: W/H ∈ {40, 90, 120, 129, 180, 250, 400}
  - × window/facade × single/double × sash 2/3/4 × screen on/off × sharh options
  - Conflict = same system + itemCode + priority and both rules match one case
- **New `RuleSandbox`**: run a draft against a test unit and diff it vs the current approved result
- **Tests**: validator, conflict detector, dynamic items, existing §8.9 vectors still pass

## 2. Firestore data model
```
profileSystems/{systemId}      nameArabic, active, createdAt, updatedAt
calculationRules/{ruleId}      one doc per VERSION (immutable once approved)
  ruleKey      "system_2000_beaded:kaab"   (groups versions)
  version, status, priority, effectiveAt, conditions[], quantityFormula,
  lengthFormula, dependsOn[], nameArabic, outputKind, profileType, cut angles,
  createdBy, approvedBy, approvedAt, createdAt, updatedAt
auditLogs/{logId}              action, ruleId, ruleKey, actorUid, before, after, at
workshops/{workshopId}/ruleOverrides/{ruleKey}
  ruleKey, baseRuleVersionId, lengthFormula, quantityFormula, updatedAt, updatedBy
systemConfigs/cuttingOptimizer
  barLengthCm, trimLossCm, kerfPerCutCm, minRemnantCm, updatedAt, updatedBy
workshops/{workshopId}/settings/cutting
  barLengthCm, trimLossCm, kerfPerCutCm, minRemnantCm, isCustomized, updatedAt, updatedBy
```
- Editing an approved rule = **new draft version**. Approving it archives the previous approved version (kept forever, so pinned projects still reproduce).
- **Workshop overrides**: stored per-workshop. If present, replaces the admin formula for that workshop only. Deleting the override reverts immediately to the official admin rule.
- **Dynamic Cutting Settings**: platform defaults stored in `systemConfigs`, overridable per workshop.

## 3. Security rules (`firestore.rules`)
- Owners/suppliers: read `calculationRules` **only where `status == 'approved' || 'archived'`** (archived needed for pinned projects). No drafts.
- Workshop overrides & settings: owner can read and write **only under `workshops/{theirWorkshopId}/**`**.
- Platform settings (`systemConfigs`): readable by all authenticated users; writable by admins only.
- Admin: read all; client writes only to **drafts**. Status changes to `approved`/`archived` only via Cloud Functions.
- `auditLogs`: server-only writes (unchanged).
- Rules unit tests for the above.

## 4. Cloud Functions (`functions/src`)
| Function | Does |
|---|---|
| `approveRule(ruleId)` | Admin only. Transaction: draft → approved, previous approved version → archived, audit log |
| `archiveRule(ruleId)` | Admin only. approved → archived + audit log |
| `logRuleDraftChange` | Firestore trigger on draft create/update/delete → audit log |

> [!NOTE]
> Formula validation + conflict detection run in Dart (client) before calling `approveRule`. The function re-checks the structural parts it can (role, status, same-key/priority clash, single approved version per key). Full formula parsing stays in the Dart engine to avoid two parsers.

- Seed script `scripts/seed_rules.ts`: writes the 7 approved "2000 بحاجب" rules + `profileSystems/system_2000_beaded` into the emulator.

## 5. App-side rule & settings sync (owner side)
- `rulesRepositoryProvider`: streams global approved rules + current workshop's `ruleOverrides`.
  - Merges them: if a workshop override exists for `ruleKey`, apply its customized formulas over the base admin rule.
- `cuttingSettingsProvider`: streams workshop's cutting settings $\rightarrow$ falls back to global `systemConfigs/cuttingOptimizer` $\rightarrow$ falls back to standard defaults (660.0 / 4.0 / 0.5 / 50.0).
- `calculatorEngineProvider`: builds `CalculatorEngine(rules: effectiveMergedRules)`; falls back to `SeedRules` if nothing is cached yet.
- Replace every `const CalculatorEngine()` and `const CutOptimizer()` with dynamic instances fed from providers.
- **Pinned versions**: units already store `ruleVersionIdsUsed`.
  - Show results using those exact versions (loaded by id, incl. archived).
  - Banner: «تتوفر قواعد أحدث» + button «إعادة الحساب بأحدث القواعد».

## 6. Workshop Owner Rule & Optimizer Customization UI (`lib/features/workshop/`)
- Accessible under Workshop Settings $\rightarrow$ «قواعد وتخصيصات الورشة»:
  - **Rule Formulas Tab**:
    - List of active rules grouped by profile system (e.g. System 2000).
    - Status tags per rule: `افتراضي (معتمد من الإدارة)` vs `مخصص للورشة (معدل)`.
    - **Edit Rule Dialog**: owner can adjust length formula or quantity formula with live validation.
    - **Multi-Workshop Sync Option**: checkbox «تطبيق التعديل على جميع الورش التابعة لي».
    - **Restore to Default Button («استعادة الافتراضي»)**: deletes the override document to instantly revert to the platform rule.
  - **Cutting Machine & Bars Tab («إعدادات المنشار والقضبان 660سم»)**:
    - Inputs for: طول القضيب الخام (`barLengthCm`), هدر التشذيب (`trimLossCm`), سماكة شفرة المنشار (`kerfPerCutCm`), عتبة الفضلة الصالحة (`minRemnantCm`).
    - «تطبيق على جميع الورش التابعة لي» checkbox.
    - «استعادة إعدادات المنصة الافتراضية» button.

## 7. Admin UI (`lib/features/admin/`)
- **Profile systems list** → **Rules list** grouped by itemCode, status chips (مسودة / معتمد / مؤرشف), filter by status
- **Rule editor** (wide: editor left, sandbox right; phone: tabs)
  - Fields above; live inline validation in Arabic as you type
  - Variable helper chips (`W`, `H`, `sashCount`, `kaab_len`…) to insert into formulas
- **Global Cutting Optimizer Settings**: Admin form to configure platform-wide default cutting parameters (`systemConfigs/cuttingOptimizer`).
- **Live sandbox**: inputs W/H/options → shows this rule's result, the full cutting list, and a diff vs current approved
- **Approve dialog**: shows validation ✓, conflict check ✓ (or the conflicting rule + the test case), then calls `approveRule`
- **Version history** per rule key + **audit log** view
- Admin dashboard gets a «إدارة القواعد» entry. Routes under `/dashboard/admin/rules/**`.
- Arabic strings go in ARB files.

## 8. Verification
- `dart test` (engine), `flutter analyze`, rules unit tests, functions build
- Manual on emulator, by DoD:
  1. Seed rules → owner's 120×150 still matches §8.9
  2. Admin edits `track` to `W - 3.5` → approve → owner's unit editor shows 116.5 **without a rebuild**
  3. Admin adds a new item (e.g. `interlock`, `H - 6`) → appears in owner's cutting list and bar layout
  4. Create an equal-priority overlapping rule → approval blocked with the conflicting case shown
  5. Formula with a cycle / unknown variable → blocked with Arabic message
  6. Old saved unit → shows pinned result + "newer rules" banner → recalculate updates it
  7. Owner account can't read drafts (rules test)
  8. Workshop override: Owner A tweaks `track` to `W - 3.2` → Owner A's cuts use 116.8, while Owner B still uses official admin rule (isolation verified)
  9. Restore to default: Owner A taps «استعادة الافتراضي» → override is deleted, immediately reverting back to admin default rule
  10. Dynamic Cutting Settings: Owner updates saw kerf to `0.3 cm` → bar optimization calculations immediately use the new kerf, showing updated scrap and remnant lengths.

## Out of scope (later phases)
- Accessories stay hardcoded for now (spec has unconfirmed quantities); moving them into rules is a follow-up.
- Unconfirmed items (handle, shankal, side/جنب, double glazing) are **not** seeded as approved — per spec they stay missing until you give formulas.

