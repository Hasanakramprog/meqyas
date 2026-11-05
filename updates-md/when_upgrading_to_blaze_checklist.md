# Checklist: What to Do When Upgrading Firebase (`meqyas-app-2026`) from Spark (Free) to Blaze Plan

**Project ID:** `meqyas-app-2026`  
**Current Plan:** Spark (Free Plan)  
**Target Plan:** Blaze (Pay-as-you-go — still includes the same free tier limits for Auth, Firestore, and Functions up to 2M invocations/month)

---

## 1. How the App Works Right Now on the Spark (Free) Plan ✅

Because you are currently on the **Spark Plan**, we engineered **مقياس (Meqyas)** so that **all features work 100% without Cloud Functions**:
- **Authentication & Registration ([`firebase_auth_repository.dart`](file:///Users/macbook/Desktop/codingrepo/meqyas/lib/features/auth/data/firebase_auth_repository.dart)):** Automatically falls back to writing `workshops/{workshopId}` and `users/{uid}` directly to Firestore when `bootstrapOwner` Cloud Function is not deployed.
- **Security Rules ([`firestore.rules`](file:///Users/macbook/Desktop/codingrepo/meqyas/firestore.rules)):** Automatically falls back to reading `role`, `workshopId`, and `supplierId` from `/users/{uid}` in Firestore when custom JWT token claims are not set by Cloud Functions.
- **100% Apple (iOS) & Android Notifications (Phase 8):**
  - Uses a **Real-Time Firestore $\to$ Native OS Notification Bridge (`flutter_local_notifications`)** that watches `users/{uid}/notifications` and fires native iOS (`UNUserNotificationCenter`) and Android (`maqyas_orders_channel`) system banners + sound whenever the app is open or in the background.

---

## 2. What Upgrading to Blaze Unlocks 🚀

When you upgrade `meqyas-app-2026` to **Blaze**, you unlock:
1. **Cloud Functions ([`functions/src/index.ts`](file:///Users/macbook/Desktop/codingrepo/meqyas/functions/src/index.ts)):**
   - `bootstrapOwner`: Server-side workshop creation & custom JWT claims (`role`, `workshopId`).
   - `adminCreateSupplier` & `adminSetUserStatus`: Admin portal user provisioning & custom claims.
   - `publishCalculationRule`: Server-side transactional rule versioning & audit logging.
   - `onOrderWrittenNotify`: Server-side FCM multicast push notifications when an order is created, quoted, confirmed, or updated.
2. **Terminated-App Push Notifications (FCM + APNs):**
   - Wakes up Android and iPhone devices even when the user has completely swiped/closed the app from memory.
3. **Firebase Cloud Storage:**
   - Storing exported PDFs or supplier attachments in `meqyas-app-2026.firebasestorage.app`.

---

## 3. Step-by-Step Commands to Run After Switching to Blaze

### Step 1: Upgrade in Firebase Console & Set a Budget Alert
1. Open [Firebase Console — `meqyas-app-2026`](https://console.firebase.google.com/project/meqyas-app-2026/overview).
2. Bottom-left corner: Click **Spark → Upgrade** and select **Blaze (Pay as you go)**.
3. Set a billing budget alert (e.g., **\$5 USD/month**) so you get an email if usage ever approaches the free tier ceiling.

---

### Step 2: Build & Deploy Cloud Functions
Run these commands from the root of the project (`/Users/macbook/Desktop/codingrepo/meqyas`):

```bash
# 1. Install and compile TypeScript Cloud Functions
cd functions
npm install
npm run build
cd ..

# 2. Deploy all Cloud Functions to meqyas-app-2026
npx -y firebase-tools@latest deploy --only functions --project meqyas-app-2026
```

---

### Step 3: Enable Cloud Storage (If Needed)
1. In Firebase Console, go to **Build → Storage → Get Started**.
2. Deploy storage rules (if any) or keep default authenticated access.

---

### Step 4: Upload Apple APNs Key for iOS Background/Terminated Push Notifications
To receive remote FCM push notifications on physical iPhones/iPads when the app is completely closed:
1. Go to [Apple Developer Account → Keys](https://developer.apple.com/account/resources/authkeys/list).
2. Create a new Key with **Apple Push Notifications service (APNs)** enabled and download the `.p8` file (note the **Key ID** and your **Apple Team ID**).
3. Open [Firebase Console → Project Settings → Cloud Messaging](https://console.firebase.google.com/project/meqyas-app-2026/settings/cloudmessaging).
4. Under **Apple app configuration (`com.meqyas.meqyas`)**, upload the `.p8` APNs Authentication Key, enter your **Key ID** and **Team ID**, and click **Save**.
5. In Xcode (`open ios/Runner.xcworkspace`), select **Runner → Signing & Capabilities → + Capability** and add **Push Notifications** and **Background Modes** (`Remote notifications`, `Background fetch`).

---

### Step 5: Sync Custom Claims for Existing Seeded Users (Optional)
After deploying Cloud Functions (or after downloading a Service Account key from **Project Settings → Service accounts → Generate new private key** as `service-account.json`):

```bash
# Sets custom JWT claims (role, workshopId, supplierId) on Auth tokens
GOOGLE_APPLICATION_CREDENTIALS="./service-account.json" npx ts-node scripts/seed_phase6.ts
```

---

## 4. Quick Verification After Upgrading to Blaze

```bash
# Check deployed functions list
npx -y firebase-tools@latest functions:list --project meqyas-app-2026

# Tail live Cloud Functions logs
npx -y firebase-tools@latest functions:log --project meqyas-app-2026
```

