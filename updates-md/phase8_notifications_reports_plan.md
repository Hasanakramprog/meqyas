# Phase 8 — 100% Native Apple (iOS/macOS) & Android Notifications + Reports Polish: Implementation Plan

**Spec References:** [`maqyas-agent-spec.md`](file:///Users/macbook/Desktop/codingrepo/meqyas/maqyas-agent-spec.md) §3 (tech stack), §12 (reports and exports), §13 (UI/UX), §15 (Phase 8)  
**Prerequisite:** Phase 6 (§5.4 Project Requirements & §5.5 Supplier Interactive Order Quoting) — Completed ✅  
*(Note: Phase 7 Phone/SMS OTP Auth is intentionally skipped per owner decision.)*

---

## 1. Goals & Scope Overview

1. **100% Native Apple (iOS/macOS) & Android Notification System (3-Layer Architecture):**
   - Instant native OS system tray notifications (banner + sound + vibration + badge) **and** in-app notification center between the **Workshop Owner** and the **Supplier** whenever an order is sent, priced/quoted, approved/confirmed, preparing, completed, or cancelled.
   - **Guaranteed 100% reliability across all environments:**
     - **Layer 1 — Native OS Local Notification Banner (`flutter_local_notifications`):** High-importance Android channel (`maqyas_orders_channel`) + Apple Darwin `UNUserNotificationCenter` presenter so system banners & sounds trigger reliably on both **iOS** and **Android**.
     - **Layer 2 — Real-Time Firestore $\to$ Native OS Notification Bridge:** Watches `users/{uid}/notifications` in real time and triggers a native iOS/Android OS banner via `flutter_local_notifications` whenever a new unread notification arrives—guaranteeing **100% native OS notifications even on iOS Simulators, Android Emulators, and Local Firebase Emulator (`demo-meqyas`)** without requiring paid Apple APNs hardware keys during testing.
     - **Layer 3 — Remote FCM Push + Background Handler (`firebase_messaging` + Cloud Function `onOrderWrittenNotify`):** Registers `@pragma('vm:entry-point')` background handler, syncs FCM + APNs tokens to `users/{uid}.fcmTokens`, and dispatches multicast push notifications with Android `priority: 'high'` and Apple APNs `aps: { alert, sound: 'default', badge: 1, content-available: 1 }` when the app is backgrounded or terminated in production.
2. **Reports & Exports Polish (Spec §12):**
   - **Client Quotation & Project Summary PDF (`عرض سعر للعميل`):** Owner can generate a formal Arabic RTL quotation PDF for their client (listing project windows/doors, dimensions, $\text{m}^2$ area, optional price per $\text{m}^2$ / unit, discount, VAT 15% toggle, and terms) and share it via PDF or WhatsApp.
   - **Workshop Reports & Analytics Hub (`التقارير والإحصائيات`):** A dedicated dashboard view and exportable report summarizing:
     - **Cutting & Waste Efficiency:** Total 660 cm bars consumed, average waste %, and reusable shelf remnants (`قصاصات الرف`).
     - **Supplier Orders & Project Costs:** Total orders by status (`sent`, `quoted`, `confirmed`, `completed`) and approved spend per project and per supplier.
   - **Unified Arabic RTL PDF Header/Footer Standard:** Consistent branding, document numbers, timestamps, signature blocks, and `صفحة X من Y` pagination across all PDFs.

---

## 2. Native Apple (iOS) & Android Platform Configuration

### 2.1 Packages (`pubspec.yaml`)
- `firebase_messaging: ^16.0.0` (matches `firebase_core: ^5.0.0` / `firebase_auth: ^7.0.0` BoM in project)
- `flutter_local_notifications: ^19.0.0`

### 2.2 Android Native Configuration (100% Android 8–15+ Support)
1. **[`android/app/src/main/AndroidManifest.xml`](file:///Users/macbook/Desktop/codingrepo/meqyas/android/app/src/main/AndroidManifest.xml):**
   - Add runtime & system permissions:
     ```xml
     <uses-permission android:name="android.permission.INTERNET"/>
     <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
     <uses-permission android:name="android.permission.VIBRATE"/>
     <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
     ```
   - Add default FCM High-Importance Notification Channel metadata inside `<application>`:
     ```xml
     <meta-data
         android:name="com.google.firebase.messaging.default_notification_channel_id"
         android:value="maqyas_orders_channel" />
     ```
2. **[`android/app/build.gradle.kts`](file:///Users/macbook/Desktop/codingrepo/meqyas/android/app/build.gradle.kts):**
   - Enable `isCoreLibraryDesugaringEnabled = true` in `compileOptions` and add `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` in `dependencies` (required by `flutter_local_notifications` on Android).
3. **Android Notification Channel Registration (`NativeNotificationService`):**
   - Creates `AndroidNotificationChannel('maqyas_orders_channel', 'طلبات التوريد والتسعيرات', description: 'إشعارات فورية لطلبات التوريد وعروض الأسعار وحالة الطلبات', importance: Importance.max, playSound: true, enableVibration: true)`.
   - Requests Android 13+ (API 33+) `requestNotificationsPermission()` automatically upon login.

### 2.3 Apple (iOS & macOS) Native Configuration (100% iOS 14–18+ Support)
1. **[`ios/Runner/Info.plist`](file:///Users/macbook/Desktop/codingrepo/meqyas/ios/Runner/Info.plist):**
   - Enable background remote notifications & background fetch:
     ```xml
     <key>UIBackgroundModes</key>
     <array>
         <string>fetch</string>
         <string>remote-notification</string>
     </array>
     <key>FirebaseAppDelegateProxyEnabled</key>
     <true/>
     ```
2. **[`ios/Runner/AppDelegate.swift`](file:///Users/macbook/Desktop/codingrepo/meqyas/ios/Runner/AppDelegate.swift):**
   - Import `UserNotifications` and assign `UNUserNotificationCenter.current().delegate = self` inside `application(_:didFinishLaunchingWithOptions:)` plus call `application.registerForRemoteNotifications()` so iOS displays notification banners, sounds, and badges even when the app is in the foreground.
3. **Apple Permission & Foreground Presentation (`NativeNotificationService`):**
   - Requests Darwin permissions (`alert: true, badge: true, sound: true`) via both `FirebaseMessaging.instance.requestPermission(...)` and `IOSFlutterLocalNotificationsPlugin.requestPermissions(...)`.
   - Calls `FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true)`.
   - On Apple platforms, safely waits for `getAPNSToken()` before requesting `getToken()` so iOS simulators without APNs keys never throw an unhandled exception.

---

## 3. Architecture & New Modules

```
lib/features/
  ├── notifications/
  │   ├── domain/
  │   │   └── app_notification.dart              # Notification model (id, recipientUid, title, body, type, orderId, projectId, isRead, createdAt)
  │   ├── data/
  │   │   ├── notifications_repository.dart      # Firestore stream + markAsRead / markAllAsRead / createNotification + FCM token sync
  │   │   └── native_notification_service.dart   # iOS + Android local notifications, FCM foreground/background handlers, tap routing, Firestore->OS bridge
  │   └── presentation/
  │       ├── notification_bell_button.dart      # Unread badge counter + real-time listener that triggers OS banner + in-app toast
  │       └── notifications_sheet.dart           # Modal bottom sheet listing notifications with 1-click deep navigation & test notification button
  │
  └── reports/
      ├── domain/
      │   └── workshop_report_summary.dart       # Aggregated metrics (projects, units, m2, bars, waste %, remnants, order totals)
      ├── data/
      │   ├── client_quotation_pdf_generator.dart  # Formal Arabic RTL Client Quotation PDF (with m2/unit pricing, VAT & terms)
      │   └── workshop_report_pdf_generator.dart   # Workshop Production, Waste/Remnants & Orders Summary PDF
      └── presentation/
          ├── client_quotation_dialog.dart       # Interactive dialog on ProjectDetailScreen to configure & export Client Quote PDF
          └── workshop_reports_screen.dart       # Visual analytics cards + 1-click PDF export for Workshop Owner
```

---

## 4. Detailed Feature Specifications

### 4.1 Notification System (`lib/features/notifications/`)

#### A. Data Model (`users/{uid}/notifications/{notificationId}`)
| Field | Type | Description |
|---|---|---|
| `id` | `String` | Document ID |
| `recipientUid` | `String` | Target user UID (Owner or Supplier) |
| `title` | `String` | Short Arabic title (e.g. `وصلت تسعيرة جديدة من المورد`) |
| `body` | `String` | Detailed Arabic summary (e.g. `قامت شركة التوريدات الوطنية بتسعير الطلب PO-2026-YS01 بإجمالي 1,327.50 ريال`) |
| `type` | `String` | `order_sent` \| `order_quoted` \| `order_confirmed` \| `order_status` |
| `orderId` | `String?` | Linked order ID for 1-click deep navigation |
| `projectId` | `String?` | Linked project ID (if applicable) |
| `workshopId` | `String?` | Linked workshop ID |
| `isRead` | `bool` | Unread status (`false` by default) |
| `createdAt` | `Timestamp` | Server timestamp |

#### B. Notification Events Matrix
| Event Trigger | Sender | Recipient | Arabic Notification Title & Body | Click Destination |
|---|---|---|---|---|
| **1. Owner sends in-app order (`status: sent`)** | Owner | Supplier (`users` where `supplierId == order.supplierId`) | **طلب تسعير جديد من ورشة `<workshopName>`**<br>مشروع `<projectName>` — رقم الطلب `<orderNumber>` (`<count>` أصناف) | `/dashboard/supplier/orders/:orderId` |
| **2. Supplier submits quote (`status: quoted`)** | Supplier | Workshop Owner (`workshop.ownerUid`) | **وصلت تسعيرة المورد للطلب `<orderNumber>`**<br>رد `<supplierName>` بتسعير `<avail>/<total>` صنف — الإجمالي: `<totalAmount>` ر.س | `/dashboard/owner/orders/:orderId` |
| **3. Owner approves quote (`status: confirmed`)** | Owner | Supplier | **تم اعتماد التسعيرة وتأكيد الطلب `<orderNumber>`**<br>اعتمدت `<workshopName>` عرض السعر — يرجى البدء بتجهيز الطلب | `/dashboard/supplier/orders/:orderId` |
| **4. Supplier updates status (`preparing` / `completed`)** | Supplier | Workshop Owner | **تحديث حالة الطلب `<orderNumber>`**<br>حالة طلبك لدى `<supplierName>` الآن: `<status.arabicLabel>` | `/dashboard/owner/orders/:orderId` |
| **5. Order Cancelled (`cancelled`)** | Owner or Supplier | Counterparty | **تم إلغاء الطلب `<orderNumber>`**<br>تم إلغاء الطلب المرتبط بمشروع `<projectName>` | Order Detail Screen |

#### C. 3-Layer Delivery Engine (`NativeNotificationService` + `NotificationsRepository` + Cloud Function)
1. **Layer 1: Native OS Banner on Apple (iOS/macOS) & Android (`NativeNotificationService.showOsNotification`):**
   - Uses `FlutterLocalNotificationsPlugin` with `AndroidNotificationDetails('maqyas_orders_channel', ...)` and `DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true)`.
   - Encodes payload `{"orderId": "...", "recipientRole": "owner|supplier"}` so tapping the system notification in the iOS Notification Center or Android Status Bar routes directly to the order detail screen via `GoRouter`.
2. **Layer 2: Real-Time Firestore $\to$ OS Notification Bridge:**
   - Tracks already-seen notification IDs per session and triggers `NativeNotificationService.showOsNotification(...)` + an in-app Arabic banner whenever a newly created unread notification document arrives in `users/{uid}/notifications`.
   - Includes a **"تجربة إشعار النظام (iOS / Android)"** action in the notifications sheet so the Owner or Supplier can test the native Apple/Android system banner with 1 tap at any time.
3. **Layer 3: Cloud Function FCM Multicast (`onOrderWrittenNotify` in [`functions/src/index.ts`](file:///Users/macbook/Desktop/codingrepo/meqyas/functions/src/index.ts)):**
   - Watches `orders/{orderId}`, writes a backup notification document if not already created by the client, and dispatches `admin.messaging().sendEachForMulticast` with:
     - `android: { priority: 'high', notification: { channelId: 'maqyas_orders_channel', sound: 'default' } }`
     - `apns: { headers: { 'apns-priority': '10' }, payload: { aps: { alert: { title, body }, sound: 'default', badge: 1, 'content-available': 1 } } }`

---

### 4.2 Reports & Exports Polish (`lib/features/reports/`) — Spec §12

#### A. Client Quotation PDF (`ClientQuotationPdfGenerator` & `ClientQuotationDialog`)
Accessible from [`ProjectDetailScreen`](file:///Users/macbook/Desktop/codingrepo/meqyas/lib/features/projects/presentation/screens/project_detail_screen.dart) via a new **«عرض سعر للعميل PDF»** button:
- **Interactive Setup Dialog (`ClientQuotationDialog`):**
  - Choose pricing mode:
    1. **سعر المتر المربع ($\text{m}^2$):** Enter price per $\text{m}^2$ (auto-multiplies each unit's area $W \times H \times \text{qty}$).
    2. **سعر مقطوع لكل وحدة:** Enter unit price per window/door line.
    3. **بدون أسعار (كشف مقاسات ومواصفات فنية فقط):** Technical specification sheet for client sign-off.
  - Optional **Discount (`خصم`)** and **VAT 15% toggle (`شامل ضريبة القيمة المضافة 15%`)**.
  - Editable **Terms & Conditions (`الشروط والأحكام ومدة التوريد والتركيب`)** (pre-filled with sensible Arabic workshop defaults).
- **Generated Arabic RTL PDF:**
  - Formal header with Workshop name, phone, location, Quote number (`QT-2026-XXXX`), Date, Client name, phone, and project location.
  - Detailed table of all project units: `#`, `الوحدة /المكان`, `المقاس (عرض × ارتفاع)`, `العدد`, `المساحة م²`, `القطاع والزجاج والمنخل`, `سعر الوحدة`, `الإجمالي`.
  - Summary box: Subtotal, Discount, VAT (if enabled), and Net Total in `SAR`.
  - Signature & Approval blocks (`توقيع واعتماد العميل` / `ختم وتوقيع الورشة`).
  - Actions: **Print / Download PDF** or **Share via WhatsApp to Client (`clientPhone`)**.

#### B. Workshop Reports & Efficiency Screen (`WorkshopReportsScreen`)
Accessible as a 4th workspace tab (**`التقارير والإحصائيات`**) in [`OwnerDashboardScreen`](file:///Users/macbook/Desktop/codingrepo/meqyas/lib/features/dashboard/presentation/owner_dashboard_screen.dart) (and via `/dashboard/owner/reports`):
1. **Production & Cut Optimization Report (تقرير الإنتاج والقص والهدر):**
   - Total Projects & Total Units/Windows measured.
   - Total Glass Area ($\text{m}^2$) across all projects.
   - Total 660 cm Aluminum Bars required vs. Reusable Shelf Remnants (`RemnantsRepository`) available in the workshop.
2. **Supplier Orders & Financial Summary (تقرير أوامر التوريد والمشتريات):**
   - Breakdown of orders by status (`بانتظار التسعير`, `تم التسعير`, `مؤكد ومعتمد`, `مكتمل`).
   - Total approved purchase amount (`SAR`) grouped by **Project** and by **Supplier**.
3. **1-Click Export (`تحميل التقرير الشامل PDF`):**
   - Generates a clean Arabic RTL executive summary PDF of the workshop's projects, remnants inventory, and approved supplier orders.

---

## 5. Security Rules Updates (`firestore.rules` via `firestore-rules-author`)
- Under `match /users/{uid}/notifications/{notificationId}`:
  - Allow `read, update, delete` if `isSignedIn() && (request.auth.uid == uid || isAdmin())`.
  - Allow `create` if `isSignedIn()` with validated schema fields (`recipientUid`, `title`, `body`, `type`, `isRead`).
- Under `match /users/{uid}`:
  - Allow owner of the user document to update their own `fcmTokens` and `lastFcmTokenUpdatedAt` fields.

---

## 6. Step-by-Step Implementation Order

| Step | Task | Files |
|---|---|---|
| **1** | Update `firestore.rules` (via `firestore-rules-author`) for `users/{uid}/notifications/{notifId}` and `fcmTokens` | `firestore.rules` |
| **2** | Add `firebase_messaging` & `flutter_local_notifications` to `pubspec.yaml` and configure Android (`AndroidManifest.xml`, `build.gradle.kts`) & Apple iOS (`Info.plist`, `AppDelegate.swift`) | `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`, `ios/Runner/Info.plist`, `ios/Runner/AppDelegate.swift` |
| **3** | Build `AppNotification`, `NotificationsRepository`, `NativeNotificationService`, and Cloud Function `onOrderWrittenNotify` | `lib/features/notifications/domain/app_notification.dart`, `lib/features/notifications/data/notifications_repository.dart`, `lib/features/notifications/data/native_notification_service.dart`, `functions/src/index.ts` |
| **4** | Wire automatic notification emission into `OrdersRepository` (`createOrder`, `submitSupplierQuote`, `approveOrder`, `updateOrderStatus`) | `lib/features/orders/data/orders_repository.dart` |
| **5** | Add `NotificationBellButton` (with live unread badge + OS notification bridge) and `NotificationsSheet` to `OwnerDashboardScreen`, `SupplierDashboardScreen`, and `SupplierOrdersScreen` | `lib/features/notifications/presentation/...` |
| **6** | Build `ClientQuotationPdfGenerator` & `ClientQuotationDialog` and add **«عرض سعر للعميل PDF»** button to `ProjectDetailScreen` | `lib/features/reports/data/client_quotation_pdf_generator.dart`, `lib/features/reports/presentation/client_quotation_dialog.dart`, `project_detail_screen.dart` |
| **7** | Build `WorkshopReportsScreen` & `WorkshopReportPdfGenerator` and integrate as the **`التقارير والإحصائيات`** tab in `OwnerDashboardScreen` | `lib/features/reports/...`, `owner_dashboard_screen.dart`, `app_router.dart` |
| **8** | Update `scripts/seed_phase6.ts` with sample notifications & verify with unit tests + `flutter analyze` | `scripts/seed_phase6.ts`, `test/features/phase8_notifications_reports_test.dart` |
