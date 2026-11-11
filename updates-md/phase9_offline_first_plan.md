# Phase 9: 100% Offline-First Architecture, Single-Device Lock & Auto-Sync Plan

## 1. Goal & Philosophy
Make **Meqyas (`مِقْيَاس`)** work **100% offline** in workshops and job sites with zero or weak internet connectivity:
1. **Zero infinite loading spinners** when saving projects, windows/doors, cut plans, remnants, or material requirements offline.
2. **Instant app startup (`< 100ms`)** in Airplane Mode for already signed-in users.
3. **Zero sync conflicts** by enforcing **Single Active Device per Account** (`activeSessionId`) + deterministic Firestore document IDs.
4. **Graceful Outbox / Queuing** for features that communicate with another person (Supplier Orders, WhatsApp PDF sharing) and clear Arabic guidance for Auth actions that strictly require a server.

---

## 2. How We Handle Features That Genuinely Require Internet When Offline

Even when a feature talks to another person or Google's Auth server, the app must **never crash, hang, or lose the user's work**. Here is how each one is handled in Offline Mode:

### A. Authentication (`signIn`, `signUp`, `resetPassword`, `signOut`)
| Sub-Action | Offline Behavior & Solution |
| :--- | :--- |
| **1. App Startup / Already Logged-In User** | **Works 100% Offline.** Firebase Auth caches the JWT token locally in iOS Keychain / Android Keystore. We read `users/{uid}` from `Source.cache` first so the user enters their dashboard immediately without network. |
| **2. First-Time Login (`signIn`) / New Registration (`signUp`) / Password Reset** | **Requires Auth Server.** Before calling Firebase Auth (or upon catching `network-request-failed`), check connectivity and immediately show a clear Arabic banner/snackbar: *"لا يوجد اتصال بالإنترنت حالياً. تسجيل الدخول لأول مرة أو إنشاء حساب جديد يتطلب اتصالاً بالإنترنت."* (No infinite spinner). |
| **3. Logging Out (`signOut`) While Offline** | **Warning Guard Before Logout!** If the user tries to log out while offline (or while `hasPendingWrites == true`), warn them: *"أنت غير متصل بالإنترنت حالياً (أو توجد تعديلات قيد المزامنة). إذا قمت بتسجيل الخروج الآن لن تتمكن من الدخول مرة أخرى حتى يتوفر الإنترنت. هل تريد المتابعة؟"* |

---

### B. Sending Orders & Quotes Between Workshop Owner & Supplier (`OrdersRepository`)
Because an Order (`orders/{orderId}`) is a **turn-by-turn state machine** between two people (`sent` -> `quoted` -> `confirmed` -> `preparing` -> `completed`), we handle it with **Firestore Offline Outbox Queuing**:

1. **Workshop Owner Creates & Sends an Order Offline (`createOrder`):**
   - **Works 100% Offline (Queued in Outbox)!**
   - The Workshop Owner selects a supplier (from cached `suppliersListProvider`), writes their notes, and taps **"إرسال الطلب للمورد"**.
   - Firestore saves the new `orders/{orderId}` document to the local SQLite cache immediately and queues the write.
   - The order appears immediately in the Owner's **"طلباتي"** list with a badge: **`⏳ بانتظار الاتصال للإرسال تلقائياً`** (`metadata.hasPendingWrites == true`).
   - The moment the phone reconnects to Wi-Fi/4G, Firestore automatically transmits the order to the Supplier and the badge turns to **`✅ تم الإرسال للمورد`**.

2. **Supplier Submits a Price Quote Offline (`submitSupplierQuote`) / Owner Approves Quote Offline (`approveOrder`):**
   - **Works Offline Using Cached Document Snapshot!**
   - Currently, `submitSupplierQuote()`, `approveOrder()`, and `updateOrderStatus()` call `await docRef.get()` (which fails or stalls offline).
   - **Fix:** Read `docRef.get()` with **`getOfflineSafe()`** (falls back to `Source.cache` if offline), append the new entry to `statusHistory`, and call `updateOfflineSafe()`.
   - Because Owner and Supplier take strict turns (`sent` is only edited by Supplier; `quoted` is only approved by Owner), queuing the transition offline is safe and auto-syncs when online.

---

### C. Exporting & Sharing PDFs via WhatsApp / Printing (`CutPlanScreen` & `ProjectRequirementsScreen`)
| Sub-Action | Offline Behavior & Solution |
| :--- | :--- |
| **1. Generating Cut Plan PDF, QR Labels PDF, or Requirements PDF** | **Works 100% Offline.** Uses bundled `assets/fonts/Cairo-Regular.ttf` and `Cairo-Bold.ttf`. |
| **2. Saving / AirDropping / Printing PDF (`Printing.layoutPdf` / `Printing.sharePdf`)** | **Works 100% Offline.** Uses native iOS/Android OS share sheet (save to Files, AirDrop to another iPhone/Mac, or print via local Wi-Fi printer). |
| **3. Sending to Supplier via WhatsApp (`_showSendWhatsAppWithPdfDialog`)** | **Works Offline up to WhatsApp Hand-off.** 1) Generates and shares the PDF locally first. 2) Opens the WhatsApp chat with the pre-filled Arabic message (`wa.me/...`). Even if the phone is offline, WhatsApp lets the user paste/queue the message inside the chat so WhatsApp sends it automatically when internet returns. |

---

## 3. Single-Device Session Lock (Zero Conflict Guarantee)

To guarantee that the same Workshop Owner or Supplier account is never edited simultaneously on two phones (e.g., Phone A offline + Phone B online):

1. **On Sign-In / Sign-Up (`FirebaseAuthRepository`):**
   - Generate a unique `sessionId` (e.g. `${DateTime.now().millisecondsSinceEpoch}_${uid.substring(0, 6)}`).
   - Save `sessionId` locally on the device and write `'activeSessionId': sessionId` to `users/{uid}` in Firestore.
2. **Real-Time Session Listener (`_userDocSubscription` in `FirebaseAuthRepository`):**
   - Listen to `users/{uid}.snapshots(includeMetadataChanges: true)`.
   - **When Offline (`doc.metadata.isFromCache == true`):** Keep the user logged in and working without interruption.
   - **When Online (`doc.metadata.isFromCache == false`):** If `doc.data()?['activeSessionId']` is non-empty and does **not** match the device's local `sessionId`, sign out immediately and display:
     > 🔒 **"تم تسجيل الدخول إلى حسابك من جهاز آخر. يُسمح بجهاز نشط واحد فقط لمنع تضارب البيانات."**

---

## 4. Technical Implementation Phases

### Phase 9.1: Firestore Unlimited Persistence & Local Font Bundling
- **File:** `lib/core/firebase/firebase_config.dart`
  - Configure `FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);`
- **Files:** `pubspec.yaml` & `lib/app/theme/app_typography.dart`
  - Register `assets/fonts/Cairo-Regular.ttf` and `assets/fonts/Cairo-Bold.ttf` under `flutter -> fonts:` in `pubspec.yaml`.
  - Set `GoogleFonts.config.allowRuntimeFetching = false;` so UI typography never attempts HTTP font downloads when offline.

### Phase 9.2: Create `OfflineFirestoreHelper` (`lib/core/firebase/offline_firestore_helper.dart`)
- **`getDocOfflineSafe(DocumentReference ref)` & `getQueryOfflineSafe(Query query)`:**
  - Attempts server fetch with a short `1500ms` timeout; on timeout or `FirebaseException(code: 'unavailable')`, immediately falls back to `GetOptions(source: Source.cache)`.
- **`commitBatchOfflineSafe(WriteBatch batch)` & `writeOfflineSafe(Future<void> writeFuture)`:**
  - Because Firestore writes to local SQLite cache synchronously upon calling `.set()` / `.update()` / `.delete()` / `batch.commit()`, waiting forever for the server ACK causes UI spinners to freeze when offline.
  - Races the server ACK against a `1200ms` timer: if the device is offline, it resolves cleanly after `1200ms` while Firestore continues syncing the queued write in the background when internet returns.

### Phase 9.3: Deterministic Document IDs & Repository Upgrades
- **`CutPlanRepository` (`lib/features/cut_optimization/data/cut_plan_repository.dart`):**
  - Use deterministic ID `plan_$projectId` for `workshops/{workshopId}/cutPlans/plan_$projectId` so offline re-saves always overwrite the same plan document.
  - Replace raw `.get()` and `await batch.commit()` with `getQueryOfflineSafe()` and `commitBatchOfflineSafe()`.
- **`FirestoreProjectsRepository` (`lib/features/projects/data/projects_repository.dart`):**
  - Use `writeOfflineSafe()` and `commitBatchOfflineSafe()` in `createProject`, `updateProject`, `deleteProject`, `saveUnit`, and `deleteUnit`.
- **`RequirementsRepository` (`lib/features/requirements/data/requirements_repository.dart`):**
  - Use deterministic IDs for auto-generated requirement lines (`auto_${category.name}_${itemCode}`) and `commitBatchOfflineSafe()`.
- **`OrdersRepository` (`lib/features/orders/data/orders_repository.dart`):**
  - Use `getDocOfflineSafe()` and `writeOfflineSafe()` in `createOrder`, `sendDraftOrder`, `submitSupplierQuote`, `approveOrder`, and `updateOrderStatus`.
- **`RulesRepository` (`lib/features/rules/data/rules_repository.dart`):**
  - Use `getDocOfflineSafe()` and `commitBatchOfflineSafe()` for workshop rule overrides and cutting settings.

### Phase 9.4: Instant Offline Auth Restore + Single-Device Lock + Logout Warning
- **File:** `lib/features/auth/data/firebase_auth_repository.dart`
  - Read `users/{uid}` from `Source.cache` first on startup so the app opens in `< 100ms` even in Airplane Mode.
  - Enforce `activeSessionId` single-device lock when online snapshots arrive.
  - Add offline logout warning guard.

### Phase 9.5: Cache Warm-Up, Offline UI Banner & Background Auto-Sync Worker
- **New File:** `lib/core/widgets/offline_sync_banner.dart`
  - Shows a compact status bar when offline (**`🟠 وضع عدم الاتصال — يتم الحفظ محلياً في الجهاز`**) or when local changes are waiting to sync (**`🔵 بانتظار الاتصال لمزامنة التعديلات...`**), and hides automatically when synced.
  - Pre-subscribes to `calculationRules`, `suppliers`, `remnants`, and `projects` upon login so cache is always warm before going to a job site.
- **Background Sync Without Opening the App (`BGAppRefreshTask` / Network Constraint Task):**
  - Whenever an offline write is queued (`hasPendingWrites == true`), register an OS background task with `NetworkType.connected` constraint.
  - When the phone reconnects to Wi-Fi/4G while in the user's pocket (minimized/locked), the OS wakes the app in the background, runs `await FirebaseFirestore.instance.waitForPendingWrites()`, flushes all queued projects/cut plans/orders to Cloud Firebase, and shows a local notification:
    > ✅ **«مِقْيَاس: تمت مزامنة التعديلات وإرسال الطلبات المعلقة بنجاح»**

---

## 5. Verification Checklist
1. `flutter analyze` passes with `0` issues.
2. Turn on **Airplane Mode** on `sam’s iPhone`:
   - Cold-launch the app -> opens directly into Owner Dashboard in `< 1 second`.
   - Create a new Project -> saves immediately without spinner hanging.
   - Add 2 Windows -> calculates pieces & saves immediately.
   - Open Cut Plan -> optimizes with cached remnants & saves immediately.
   - Add a manual remnant -> appears immediately.
   - Create an Order for a Supplier -> queues immediately with `بانتظار الاتصال` status.
3. Turn **Airplane Mode OFF** -> all queued documents sync to Cloud Firestore (`meqyas-app-2026`) automatically.

