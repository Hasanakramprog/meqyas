# مقياس (Maqyas) — AI Agent Development Spec

> Build brief for an AI coding agent. Stack: **Flutter + Firebase**. UI: **Arabic RTL**. Code, identifiers, comments and commit messages: **English**.
> Source of truth for business rules is the owner's `requirements.md`; this file restates everything an agent needs.

---

## 0. Rules of engagement (read first)

1. **Never invent manufacturing formulas, items, quantities or business decisions.** If a value is not in this file, create a rule/field as `draft` / `TODO(owner)` and show "rule missing" in the UI. Do not guess.
2. **Formulas are data, not code.** Calculation rules live in Firestore and are editable by the admin. The engine only evaluates them.
3. **The calculation engine is a pure Dart package** with no Flutter or Firebase imports, fully unit-tested.
4. **Stock changes only happen server-side** in a Cloud Function transaction. Never from the client.
5. Every user-facing string goes through localization (ARB files). Arabic is the default locale.
6. Build in the phases of section 15. Do not start a later phase before the earlier one's "Definition of done" passes.
7. All lengths are in **centimeters** unless a field name says `_mm` or `_m`.
8. Validate on the client for UX **and** on the server (Security Rules / Cloud Functions) for safety.

---

## 1. Product summary

An app for aluminum and glass workshops. The workshop owner (المعلم) enters window/facade measurements; the app calculates aluminum cut lengths, glass sizes, accessories, brush strips and mesh; optimizes cutting from 660 cm bars; collects needs into a cart; sends orders to suppliers (WhatsApp / PDF); and tracks pricing, inventory and reports.

**Goals:** less time and fewer errors in measuring, cutting and ordering; track waste and remnants; organize projects, suppliers, stock and reports.

---

## 2. Users and roles

| Role | Code | Capabilities |
|---|---|---|
| Workshop owner (المعلم) | `owner` | Register/login, workshop settings, clients, projects, units/measurements, calculations, cut plans, cart, orders to suppliers, reports |
| Supplier (المورد) | `supplier` | Own account: manage own items, prices, stock, incoming orders, order status. Sees only own data |
| Admin (الأدمن) | `admin` | Users, suppliers, catalog, prices, inventory, calculation rules (versioned), permissions, audit logs |

**Open (TODO(owner)):** is the measurement technician a separate role? Does the customer need a login? Keep the roles model extensible (add roles without rewriting).

Role is stored in **two places**: `users/{uid}.role` (display/admin) and a **Firebase custom claim** `role` (authoritative for Security Rules). Only Cloud Functions set claims.

---

## 3. Tech stack

**Client (single Flutter codebase → Android, iOS, Web)**
- State: `flutter_riverpod`
- Routing: `go_router` (role-based redirect guards)
- Models: plain Dart classes or `freezed` + `json_serializable`
- Firebase: `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `firebase_storage`; `firebase_messaging` later
- Localization: `flutter_localizations`, `intl`, ARB files, force `TextDirection.rtl` for `ar`
- Font: Cairo or Noto Naskh Arabic (bundle it; also needed for PDF)
- PDF: `pdf` + `printing`. Barcode/QR: `barcode_widget` / `pdf` barcode. Excel: `excel`
- Formula evaluation: `math_expressions` or a small custom parser (see section 8). **Never** use dynamic code execution on formula text.
- Use latest compatible versions; do not pin to outdated ones.

**Backend (Firebase)**
- Auth (email/password now; phone later)
- Firestore (cache/offline persistence on)
- Cloud Functions (TypeScript, callable functions) — needs Blaze plan
- Cloud Storage (logos, PDFs, label files)
- Hosting (Flutter Web: admin + supplier dashboards)
- Emulator Suite for local dev and tests (Auth, Firestore, Functions)

**Out of scope for MVP:** Microsoft Access sync (use Excel import/export instead — pending owner confirmation), CAD/DXF import, other profile systems, doors.

---

## 4. Authentication

### Phase 1 — Email + password (build now)

**Registration (owner):**
- Fields: full name, email, password, phone (collected, **not verified yet**), workshop name, workshop location.
- Flow: `createUserWithEmailAndPassword` → send email verification → call callable `bootstrapOwner` which (a) creates `users/{uid}`, (b) creates `workshops/{workshopId}`, (c) sets custom claims `{role:'owner', workshopId}`. Client force-refreshes the ID token.
- Verified email required before using the app (show a "verify your email" screen with resend).
- Admin-approval policy is **undecided** (TODO(owner)). Implement `users/{uid}.status` = `active | pending | disabled` and a single config flag `requireAdminApproval` (default `false`). Security Rules and router guard must respect `status`.

**Login:** email + password. Persist session securely (Firebase default). Role-based redirect after login:
- `owner` → workshop dashboard
- `supplier` → supplier dashboard
- `admin` → admin panel

**Reset password:** Firebase `sendPasswordResetEmail`.

**Supplier and admin accounts are NOT self-registered.**
- Admin creates suppliers via callable `createSupplierUser` (creates auth user, `suppliers/{id}`, claims `{role:'supplier', supplierId}`).
- First admin is created by a one-off script setting claim `{role:'admin'}`.

**Rate limiting / abuse:** rely on Firebase Auth built-ins; show friendly Arabic errors; no custom attempt counters in Phase 1.

### Phase 2 — Phone / SMS (later; design for it now)

Requirements from the spec: verification code via WhatsApp or SMS at signup, login with phone + password, reset password via code, code expiry, attempt limits.

Design now so Phase 2 doesn't force a rewrite:
- Keep `users/{uid}.phone` and `phoneVerifiedAt` (null in Phase 1).
- Put auth behind an interface:
  ```dart
  abstract class AuthRepository {
    Stream<AppUser?> authState();
    Future<void> signUp(SignUpData data);
    Future<void> signIn(SignInData data);   // email now; phone later
    Future<void> sendPasswordReset(String identifier);
    Future<void> verifyPhone(String code);  // no-op/unsupported in Phase 1
    Future<void> signOut();
  }
  ```
- Phase 2 approach (default): after email signup, **link a phone credential** (`PhoneAuthProvider` + `linkWithCredential`) and set `phoneVerifiedAt`. Phone + password login then needs a callable `resolveEmailByPhone` (rate-limited, no account enumeration). WhatsApp OTP needs a custom Cloud Function + paid provider — **provider undecided** (TODO(owner)); keep a `VerificationProvider` interface (`sms_firebase`, `whatsapp_custom`).
- SMS costs money and routes can be unreliable: verify once at signup and keep the session; don't require a code on every login.

---

## 5. Architecture

```
lib/
  main.dart
  app/                    # app shell, router, theme, localization
  core/                   # utils, errors, validators, constants
  features/
    auth/                 # data/ domain/ presentation/
    workshop_settings/
    clients/
    projects/
    units/                # measurements, options, divisions, quick entry
    calculation/          # UI for results (uses engine package)
    cut_optimization/
    catalog/
    pricing/
    inventory/
    cart/
    suppliers/
    orders/
    reports/              # PDF, Excel, labels
    admin/                # users, rules, catalog, audit
    supplier_portal/
packages/
  maqyas_engine/          # PURE DART: rule evaluation, BOM, cut optimizer
    lib/ test/
functions/                # Cloud Functions (TypeScript)
firestore.rules
firestore.indexes.json
firebase.json
```

Layering per feature: `presentation` (widgets, controllers) → `domain` (entities, use-cases) → `data` (Firestore repositories). The engine package knows nothing about Firebase.

---

## 6. Firestore data model

Denormalize for reads (no joins). Copy rarely-changing display fields (names, unit price at order time) into documents where history must be frozen. All docs: `createdAt`, `updatedAt` (server timestamps).

```
users/{uid}
  fullName, email, phone, phoneVerifiedAt, role, status, workshopId?, supplierId?

workshops/{workshopId}
  name, phone, location, logoUrl, defaultColor, defaultGlazing('single'|'double'), ownerUid
  clients/{clientId}            name, phone, location
  projects/{projectId}          name, location, notes, clientId?, clientName?, status
    units/{unitId}
      name, widthCm, heightCm, quantity, place,
      unitType('window'|'facade'), profileSystemId, glazingMode('single'|'double'),
      color, sharhOption('none'|'one_side'|'two_sides'),
      screen{enabled, frameColor, meshType, meshColor, rollerType},
      glass{typeId, thicknessMm}, accessoriesOptions{corners, gasket, putty},
      divisions{sashCount, screenCount, customWidths?},
      overridesFromWorkshopDefaults[]   // for the review summary
      result{ ruleVersionIds{}, items[], glassPanes[], computedAt }   // snapshot
  carts/{cartId}  items[{itemId, name, qty, unit, projectId, unitId, note}]
  cutPlans/{planId}  projectId, itemCode, bars[], wasteCm, remnants[]

profileSystems/{id}             name, code, status
calculationRules/{ruleId}       profileSystemId, itemCode, status('draft'|'approved'|'archived'),
                                 priority, version, effectiveAt,
                                 conditions[], quantityFormula, lengthFormula, params{}
  (versions are separate docs: never overwrite an approved rule)
catalogItems/{itemId}           code(unique), arabicName, categoryId, unit, color, thickness, status
glassTypes/{id}                 name, thicknessMm, gasketAllowanceMm
suppliers/{supplierId}          name, phone, whatsappPhones[], address
  prices/{itemId}               price, currency, validFrom   (+ price history subcollection)
  stock/{itemId}                balance, unit, reservedQty
  lots/{lotId}                  itemId, kind('bar'|'roll'|'remnant'), widthCm, lengthCm,
                                 remainingLengthCm, state('full'|'open'|'remnant'|'used'), costBasis
orders/{orderId}
  workshopId, supplierId, status, items[{itemId, name, qty, unit, unitPrice}], notes,
  idempotencyKey, confirmedBy?, confirmedAt?, statusHistory[]
inventoryMovements/{id}         itemId, qty, unit, movementType, orderId, sourceRemnantId?, idempotencyKey
auditLogs/{id}                  actorUid, action, entityType, entityId, before, after, at
```

**Money:** currency, taxes, discounts and quote template are **undecided** (TODO(owner)). Store `price` as a number + `currency` string; do not hardcode a currency or tax logic.

**Order statuses (proposed, needs owner approval):** `draft, sent, confirmed, preparing, completed, cancelled`. Keep the list in one constant/enum so it is easy to change.

---

## 7. Security rules (outline — implement in `firestore.rules`, test in emulator)

- Helper functions: `isSignedIn()`, `role()`, `isActive()` (status == active), `isOwnerOf(workshopId)`, `isSupplier(supplierId)`, `isAdmin()`.
- Owner: read/write only inside `workshops/{ownWorkshopId}/**`; read approved rules, catalog, suppliers' public info and prices.
- Supplier: read/write only `suppliers/{ownSupplierId}/**`; read orders where `supplierId == own`; may update order status only via allowed transitions.
- Admin: read all; write rules, catalog, suppliers, users (role/status changes via functions only).
- **Nobody except Cloud Functions** may write `stock`, `lots`, `inventoryMovements`, custom claims, or set `orders.status` to `confirmed`.
- Reject negative stock and invalid data shapes in rules where feasible.
- Include rules unit tests (`@firebase/rules-unit-testing`) for: cross-workshop read denied, supplier reading another supplier's orders denied, client writing stock denied.

---

## 8. Calculation engine (`packages/maqyas_engine`)

### 8.1 Inputs and variables
Variables available to formulas: `W` (outer width cm), `H` (outer height cm), `N` (quantity of units), plus named intermediate values (e.g. `kaab_len`, `sash_height`, `glass_height`). Options available to conditions: `unitType`, `glazingMode`, `sharhOption`, `sashCount`, `screenCount`, `hasScreen`, `profileSystemId`, etc.

### 8.2 Rule record
```
itemCode, profileSystemId, status, priority, version, effectiveAt,
conditions: [ "unitType == 'window'", "W == 129" ],
quantityFormula: "2 * sashCount",
lengthFormula:   "(W - 2.5) / 2",
dependsOn: []       // item/intermediate codes this formula needs
```

### 8.3 Which rule applies (selection algorithm)
For each needed item of a unit:
1. Keep rules whose `profileSystemId` equals the unit's profile system.
2. Keep `status == approved` and `effectiveAt <= now`; if several versions exist take the latest approved.
3. Keep rules the unit actually needs (mesh rules only if a screen exists; corners/gasket only if selected; roller rules only for the chosen roller type).
4. Keep rules whose **all conditions** evaluate true (unit type, glazing mode, sharh option, width conditions, sash/screen counts).
5. If several remain, highest `priority` wins; an equal-priority tie is a **conflict** → block approval in admin; at runtime report an error for that item.
6. If none remain → result line `status: rule_missing` (UI warning). **Never guess.**
7. Evaluate dependencies in topological order (e.g. mesh horizontal depends on `kaab_len`); detect cycles.
8. Validate: all variables present, length > 0, quantity is an integer ≥ 0. Negative/zero length → error, block save.
9. Store `ruleVersionIds` used on the result so old projects stay reproducible; support "recalculate with latest rules".

Single/double must **swap actual catalog items** (handle, shankal, kaab, glass), not just labels. Window vs facade changes handle faces (1 vs 2) and water plugs (6 vs 12).

### 8.4 Seed rules — default system "2000 بحاجب" (two glass sashes + one screen)

Confirmed (seed as `approved`):

| itemCode | Qty | Length (cm) |
|---|---|---|
| `track` سكة 2000 بحاجب | 2 | `W - 3` |
| `u_profile` يو 2000 | 2 | `H - 3.3` |
| `kaab` كعب 2000 مفرد | 2 per glass sash (4 for 2 sashes) | `(W - 2.5) / 2` (default division) |
| `screen_vertical` درفة منخل عامودي | 2 per screen | `H - 4.1` |
| `screen_horizontal` درفة منخل أفقي | 2 per screen | `kaab_len + 2` |
| glass height | — | `H - 14` |
| glass width per sash | — | `(W - 16.2) / 2` |

Side (جنب) length adjustment for sharh: `none: +5`, `one_side: +2.5`, `two_sides: +0` (added to the **base side length**).

**Seed as `draft` / rule_missing (unconfirmed — do not invent):**
- Handle `مسكة 2000 مفرد` and shankal `شنكل 2000 مفرد`: spec says qty 2 per glass sash, length `sash_height − 5.8`, but the **relation between glass sash height and full window height is unconfirmed**.
- Side `جنب 2000 بحاجب`: **base length unconfirmed**.
- Non-default divisions/clearances (example: width 129 cm) — need approved special rules. Never reuse two-sash formulas for other divisions.
- Double glazing items and air-gap details; doors; other profile systems; brush 900 exact formula; net mesh calculation; gasket-press rules; shekan quantities.

### 8.5 Glass
- Defaults: `glass_height = H - 14`, `glass_width_per_sash = (W - 16.2) / 2`, pane area m² = `width_cm * height_cm / 10000`.
- Types: دبوس شفاف, مشرط أبيض, فيمه أسود, عاكس, شفاف. Thickness: 6, 8, 10 mm.
- Gasket allowance: 6 mm → 2.5 mm per side; 8 mm → 2 mm per side; 10 mm → none (per the registered rule). **How the allowance changes the final pane size is unconfirmed** — keep it as data on `glassTypes`, apply only once the owner confirms.
- Single/double default per workshop, overridable per unit (does not change workshop defaults).

### 8.6 Accessories (fixed quantities from the spec)
- Glass handle (مسكة): 1 per sash; 1 face for window, 2 faces for facade. Screen handle: 2 per screen.
- Shankal plug (طبة شنكل): 4. Water plug (طبة ماء): 6 window / 12 facade.
- Plug for rakilaj handle: 2. Plug for fixed handle: 2.
- Short screws 4mm×1.5cm: 16. Long screws 4mm×3cm: 8.
- Corners: 4 per window when selected. Gasket (جوان): 4 per window when selected. Putty: optional.
- Shekan / screen shekan: exist, **quantity unconfirmed**.
- Screen rollers: choose **exactly one** type: slider ×2, modified 2000 roller ×2, or milled roller ×2.
- Glass rollers: roller 2000 single/double, usually 2 per sash; **count must be even**.

### 8.7 Brush (فراشة) and mesh (شبك)
- Brush 900: for kaab, handle and shankal, inside and outside, from actual lengths (exact formula unconfirmed).
- Brush 450: screen length ×6 and screen width ×4, per screen.
- **Commercial pricing/stock/sale unit for brush and mesh is the ROLL only, not meters.** Internal consumption may be tracked in length/area; open rolls and remnants are tracked.
- Mesh rolls: fiber widths 80, 100, 120, 150, 214, 240 cm × 20 m; aluminum widths 80, 100, 120, 150, 180 cm × 25 m; screen-press gasket rolls 100 m or 135 m depending on type. Brush roll length is defined per item.
- A mesh rectangle can be cut from a roll or a saved remnant **only if `requested_width <= available_width` AND `requested_length <= available_length`** (never by area alone). Store the source, remnant dimensions, state and cost; a remnant can never be consumed twice.
- Open: buy a full roll per partial need, or pool needs to reach an integer roll count? (TODO(owner))

### 8.8 Cut optimization
- Bar length 660 cm; saw kerf 0.5 cm per cut; trim 2 cm per end (4 cm total); minimum useful remnant 50 cm. Usable length per bar = 660 − 4 = 656 cm before kerf.
- Algorithm: group pieces by item + color; solve with first-fit-decreasing (improve later if needed). Output: bars needed, per-bar cut sequence, piece lengths, kerf, trim, waste, remnants (≥ 50 cm kept as remnants).
- **Do not count loss twice.** Cover kerf counting (including the last cut of a bar) with explicit unit tests and confirm with the owner against a physical example.
- Labels: Barcode/QR per piece with project, unit, item, color, length, bar number.

### 8.9 Required test vectors (must pass)

Window `W=120, H=150`, profile 2000 بحاجب, two glass sashes + one screen:

| Check | Expected |
|---|---|
| glass height | 136 |
| glass width per sash | 51.9 |
| track | 117, ×2 |
| u_profile | 146.7, ×2 |
| kaab | 58.75, ×4 |
| screen vertical | 145.9, ×2 |
| screen horizontal | 60.75, ×2 |
| glass pane area | 136 × 51.9 / 10000 = 0.70584 m² |

Behavioral tests: window→facade changes handle faces and water plugs 6→12; single→double swaps items and glass; sharh options change side adjustment (+5/+2.5/0); optimizer respects 660/0.5/4/50; mesh cut rejected when remnant is too narrow or too short even if area suffices; negative cut length blocks save; changing a unit's defaults does not change workshop defaults; results record rule versions.

---

## 9. Admin: rules management

- Screens: profile systems, rules list (filter by profile/item/status), rule editor, "which rule applies?" tester, version history.
- Rule editor: item, qty formula, length formula, conditions, priority, status. Validate syntax, show a live test calculator (enter W, H, options → see result), reject negative results, detect priority conflicts.
- Flow: `draft` → test on a real sample window → `approved`. Never edit an approved rule in place: create a new version; archive the old one.
- Every change writes an `auditLogs` entry (who, when, before, after).
- A formula can only use known variables. A completely new **input** needs an app update.

---

## 10. Catalog, pricing, inventory

- Catalog item: unique code, Arabic name, category (aluminum, accessories, fiber, plastic, tools, glass, …), unit (cm, mm, m, piece, bar, roll), color, thickness, supplier, price, balance, status. Search by code or name.
- Excel import/export with correct Arabic encoding; reject duplicate codes.
- Prices per item and supplier with history.
- Stock: bars, full rolls, open rolls, remnants, reservations, adjustments, consumption; low-stock alerts; **no negative balances**; audit log.

---

## 11. Cart, suppliers, orders

- Cart aggregates materials from saved projects, keeping project/unit references. Edit quantities, add items, per-line note, delete.
- Select supplier, then one of their WhatsApp numbers. Message contains workshop name, phone, location, items, quantities, notes. Use a `wa.me` link (free); no WhatsApp Business API.
- Arabic RTL PDF with logo, prices, terms.
- **Stock is never deducted on cart view, draft save, PDF export or opening WhatsApp.**
- **Order confirmation = Cloud Function `confirmOrder` (callable):**
  1. Authorize caller (who may confirm is **TODO(owner)**; implement as one pluggable check, default: the order's supplier or an admin).
  2. Run **one Firestore transaction**: read order; if already confirmed with same `idempotencyKey` → return existing result (no second deduction); read all stock docs; if any would go negative → abort, change nothing; otherwise deduct, write `inventoryMovements`, set status, append status history.
  3. Write an `auditLogs` entry.
  - Respect Firestore transaction/write limits; split or reject oversized orders explicitly.
- Status changes after confirmation go through functions with a transition table.

---

## 12. Reports and exports

Cut list per unit and per project; purchase list per supplier; quotation PDF (logo, terms, simple drawings); order PDF; barcode/QR labels; Excel for items and prices; roll/remnant/waste reports. Header: workshop name, logo, project, client, date, document number. Tables: items, quantities, lengths, units, prices if available; totals, terms, notes; Arabic RTL; page numbers. Quote template, currency, taxes, discounts: **TODO(owner)**.

---

## 13. UI / UX

- Arabic RTL, mobile-first, minimal horizontal scrolling, clear units (سم / ملم / متر / قطعة / قضيب / لفة).
- Owner flow: `Welcome → Sign Up/Sign In → Email verification → Workshop setup → Dashboard → Projects → New project → New measurement / Quick entry → Unit options → Divisions → Results → Cut optimization → Cart → Supplier selection → Order preview → WhatsApp/PDF → Order tracking`.
- Admin: `Users & permissions → Profile rules → Catalog → Pricing → Inventory & remnants → Suppliers → Orders → Audit logs`.
- Supplier: `Dashboard → Products & prices → Inventory → Incoming orders → Order status`.
- Quick-entry table: name, width, height, quantity, place. After saving a unit, **clear the fields**; never prefill a sample size like 180×90.
- Project review before save: counts of windows/facades, single/double, options that differ from workshop defaults.
- Undo last change; reopen and edit old projects; confirmation dialog before delete (undo when possible).
- Feedback pattern: inline field errors; success/info toasts (SnackBar); blocking dialogs for destructive or stock failures; warning banner for "rule missing"; persistent banner when offline. Keep all Arabic messages in ARB files. Examples: «أدخل عرضاً أكبر من صفر», «الطول الناتج سالب، تحقق من القياسات», «لا توجد قاعدة معتمدة لهذا الصنف», «الرصيد غير كافٍ، لم يتم الخصم», «تم تأكيد هذا الطلب مسبقاً».

---

## 14. Offline behavior

- Enable Firestore persistence. Load rules, catalog and workshop data at login so they are cached.
- Works offline: create projects, enter measurements, run calculations (local engine), view saved projects, build carts and drafts.
- Requires internet: login/registration, `confirmOrder`/stock, receiving new admin rules.
- Default conflict policy is last-write-wins; flag concurrent edits as a future item.

---

## 15. Build phases and Definition of done

**Phase 0 — Setup:** Flutter project, Firebase project (dev + prod), emulators, lint, CI-less local scripts, ARB/RTL scaffold, theme. *DoD:* app runs in Arabic RTL on Android/iOS/Web; emulators start.

**Phase 1 — Auth (email):** registration, email verification, login, reset password, `bootstrapOwner`, role claims, router guards, admin seed script, Security Rules v1 + tests. *DoD:* owner registers, verifies, logs in, lands on the right dashboard; supplier/admin created by script/admin function; cross-role access denied in rules tests.

**Phase 2 — Engine:** `maqyas_engine` with rule selection, evaluator, dependencies, validation, test vectors from 8.9, seed rules. *DoD:* all test vectors pass; missing rules reported, never guessed.

**Phase 3 — Workshop, projects, units:** workshop settings, clients, projects, unit form, quick entry, review summary, results screen with formulas and rule versions, undo, reopen/recalculate. *DoD:* 120×150 example matches expected values in the app.

**Phase 4 — Admin rules:** rule editor, tester, versioning, draft→approved, audit log. *DoD:* adding a rule in admin changes results without an app release; conflicts blocked.

**Phase 5 — Cut optimization + labels + PDF:** optimizer, remnants, Arabic PDFs, barcode/QR labels. *DoD:* respects 660/0.5/4/50; Arabic PDF renders correctly.

**Phase 6 — Catalog, pricing, suppliers, cart, orders:** catalog + Excel import/export, supplier portal, cart, WhatsApp/PDF orders, `confirmOrder` function. *DoD:* preview never changes stock; confirm deducts once; retry doesn't double-deduct; insufficient stock changes nothing.

**Phase 7 — Phone/SMS auth:** link verified phone, phone+password login resolution, password reset by code, provider interface. *DoD:* decided provider integrated; attempts/expiry limits enforced.

**Phase 8 — Later:** push notifications, reports polish, PWA/offline conflict policy, other profile systems, doors, CAD/DXF import.

---

## 16. Acceptance criteria (from the owner)

1. Invalid measurements and negative cut lengths cannot be saved.
2. Results match the numeric examples; the rule version is shown.
3. Unit-level changes don't alter workshop defaults.
4. Single/Double switches the actual profile and glass items.
5. Brush and mesh are priced by roll only; internal consumption may be length/area.
6. A remnant is never consumed twice; width **and** length are checked.
7. No stock deduction on draft/preview/WhatsApp; only on authorized confirmation.
8. Order save + deduction is atomic; resend doesn't duplicate; failure rolls back fully.
9. Arabic import/export has no encoding corruption; all screens and reports are RTL.
10. Saved projects can be reopened, edited and recalculated, showing which rules were used.
11. Undocumented doors or clearances are never treated as complete without approved formulas.

---

## 17. Open decisions (ask the owner; leave as TODO, do not guess)

- Base side-profile length; relation of glass sash height to full window height.
- Non-default clearances and divisions (e.g. 129 cm); other profile systems; door formulas.
- Shekan and screen shekan quantities; brush roll lengths; brush 900 formula; press-gasket rules; double-glazing build and air gap; how gasket allowance changes pane size.
- Who confirms orders and triggers stock deduction; final order statuses.
- Signup fields, admin-approval policy, SMS/WhatsApp provider.
- Technician role; does the customer need an account.
- Currency, taxes, discounts, quote template, how glass/aluminum are priced.
- Roll purchasing: whole roll per partial need vs pooled needs.
- Access sync: whether it is needed at all (default: dropped for MVP).
- Platform priority: mobile vs web first.

Before large implementation steps, produce: user stories, data model, permission matrix, rule list with numeric examples, and test cases — and get them approved. Test with real workshop measurements. Deliver source code, run instructions, tests, sample data, and an Arabic user guide.
