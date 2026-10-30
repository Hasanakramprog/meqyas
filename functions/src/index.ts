import * as admin from "firebase-admin";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentWritten, onDocumentDeleted } from "firebase-functions/v2/firestore";

admin.initializeApp();
const db = getFirestore();

/**
 * Bootstraps an owner account:
 * 1. Creates `workshops/{workshopId}`
 * 2. Creates `users/{uid}`
 * 3. Sets custom claims `{role: 'owner', workshopId}`
 */
export const bootstrapOwner = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }

  const uid = request.auth.uid;
  const email = request.auth.token.email || "";
  const { fullName, phone, workshopName, workshopLocation } = request.data || {};

  if (!workshopName || !fullName) {
    throw new HttpsError("invalid-argument", "Missing required fields");
  }

  // Create workshop document
  const workshopRef = db.collection("workshops").doc();
  const workshopId = workshopRef.id;

  const now = FieldValue.serverTimestamp();

  const batch = db.batch();

  batch.set(workshopRef, {
    name: workshopName,
    location: workshopLocation || "",
    phone: phone || "",
    ownerUid: uid,
    defaultColor: "white",
    defaultGlazing: "single",
    createdAt: now,
    updatedAt: now,
  });

  // Create or update user doc
  const userRef = db.collection("users").doc(uid);
  batch.set(userRef, {
    fullName,
    email,
    phone: phone || "",
    phoneVerifiedAt: null,
    role: "owner",
    status: "active", // Can be set to 'pending' if requireAdminApproval is enabled
    workshopId,
    createdAt: now,
    updatedAt: now,
  });

  await batch.commit();

  // Set authoritative custom claims
  await admin.auth().setCustomUserClaims(uid, {
    role: "owner",
    workshopId,
    status: "active",
  });

  return { success: true, workshopId };
});

/**
 * Creates an additional workshop for an authenticated owner.
 */
export const createWorkshop = onCall(async (request) => {
  if (!request.auth || request.auth.token.role !== "owner") {
    throw new HttpsError("permission-denied", "Owner privileges required");
  }

  const uid = request.auth.uid;
  const { name, location, phone } = request.data || {};

  if (!name || typeof name !== "string" || !name.trim()) {
    throw new HttpsError("invalid-argument", "Workshop name is required");
  }

  const workshopRef = db.collection("workshops").doc();
  const now = FieldValue.serverTimestamp();

  await workshopRef.set({
    name: name.trim(),
    location: location ? location.trim() : "",
    phone: phone ? phone.trim() : "",
    ownerUid: uid,
    defaultColor: "white",
    defaultGlazing: "single",
    createdAt: now,
    updatedAt: now,
  });

  return { success: true, workshopId: workshopRef.id };
});

/**
 * Creates a supplier user (Admin only)
 */
export const createSupplierUser = onCall(async (request) => {
  if (!request.auth || request.auth.token.role !== "admin") {
    throw new HttpsError("permission-denied", "Admin privileges required");
  }

  const { email, password, name, phone, whatsappPhones, address } = request.data || {};
  if (!email || !password || !name) {
    throw new HttpsError("invalid-argument", "Missing supplier details");
  }

  const userRecord = await admin.auth().createUser({
    email,
    password,
    displayName: name,
    emailVerified: true,
  });

  const supplierRef = db.collection("suppliers").doc();
  const supplierId = supplierRef.id;
  const now = FieldValue.serverTimestamp();

  await supplierRef.set({
    name,
    phone: phone || "",
    whatsappPhones: whatsappPhones || [],
    address: address || "",
    createdAt: now,
    updatedAt: now,
  });

  await db.collection("users").doc(userRecord.uid).set({
    fullName: name,
    email,
    phone: phone || "",
    phoneVerifiedAt: null,
    role: "supplier",
    status: "active",
    supplierId,
    createdAt: now,
    updatedAt: now,
  });

  await admin.auth().setCustomUserClaims(userRecord.uid, {
    role: "supplier",
    supplierId,
    status: "active",
  });

  return { success: true, supplierId, uid: userRecord.uid };
});

/**
 * Approves a draft calculation rule (Admin only).
 * Atomically:
 * 1. Sets draft -> approved
 * 2. Sets previous approved version for same ruleKey -> archived
 * 3. Logs to auditLogs
 */
export const approveRule = onCall(async (request) => {
  if (!request.auth || request.auth.token.role !== "admin") {
    throw new HttpsError("permission-denied", "Admin privileges required");
  }

  const adminUid = request.auth.uid;
  const { ruleId } = request.data || {};
  if (!ruleId || typeof ruleId !== "string") {
    throw new HttpsError("invalid-argument", "Missing or invalid ruleId");
  }

  const ruleRef = db.collection("calculationRules").doc(ruleId);
  const now = FieldValue.serverTimestamp();

  return await db.runTransaction(async (transaction) => {
    const ruleDoc = await transaction.get(ruleRef);
    if (!ruleDoc.exists) {
      throw new HttpsError("not-found", "Rule not found");
    }

    const data = ruleDoc.data()!;
    if (data.status !== "draft") {
      throw new HttpsError("failed-precondition", `Rule is not a draft (current status: ${data.status})`);
    }

    const ruleKey = data.ruleKey || `${data.profileSystemId}:${data.itemCode}`;
    const version = data.version || 1;

    // Find any existing approved rule with same ruleKey
    const prevApprovedQuery = db
      .collection("calculationRules")
      .where("ruleKey", "==", ruleKey)
      .where("status", "==", "approved");
    const prevApprovedSnap = await transaction.get(prevApprovedQuery);

    for (const prevDoc of prevApprovedSnap.docs) {
      if (prevDoc.id !== ruleId) {
        transaction.update(prevDoc.ref, {
          status: "archived",
          updatedAt: now,
        });
      }
    }

    // Approve candidate
    transaction.update(ruleRef, {
      status: "approved",
      approvedBy: adminUid,
      approvedAt: now,
      updatedAt: now,
    });

    // Write audit log
    const auditRef = db.collection("auditLogs").doc();
    transaction.set(auditRef, {
      action: "rule_approved",
      ruleId,
      ruleKey,
      version,
      actorUid: adminUid,
      at: now,
    });

    return { success: true, ruleId, version };
  });
});

/**
 * Archives an approved calculation rule (Admin only).
 */
export const archiveRule = onCall(async (request) => {
  if (!request.auth || request.auth.token.role !== "admin") {
    throw new HttpsError("permission-denied", "Admin privileges required");
  }

  const { ruleId } = request.data || {};
  if (!ruleId || typeof ruleId !== "string") {
    throw new HttpsError("invalid-argument", "Missing or invalid ruleId");
  }

  const ruleRef = db.collection("calculationRules").doc(ruleId);
  const ruleDoc = await ruleRef.get();
  if (!ruleDoc.exists) {
    throw new HttpsError("not-found", "Rule not found");
  }

  const data = ruleDoc.data()!;
  const now = FieldValue.serverTimestamp();

  const batch = db.batch();
  batch.update(ruleRef, {
    status: "archived",
    updatedAt: now,
  });

  const auditRef = db.collection("auditLogs").doc();
  batch.set(auditRef, {
    action: "rule_archived",
    ruleId,
    ruleKey: data.ruleKey || `${data.profileSystemId}:${data.itemCode}`,
    version: data.version || 1,
    actorUid: request.auth.uid,
    at: now,
  });

  await batch.commit();

  return { success: true, ruleId };
});

/**
 * Logs draft changes or rule deletions to auditLogs
 */
export const logRuleDraftChange = onDocumentWritten("calculationRules/{ruleId}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();

  // If deleted or created as draft, or updated draft
  if (!after && before) {
    await db.collection("auditLogs").add({
      action: "rule_deleted",
      ruleId: event.params.ruleId,
      ruleKey: before.ruleKey,
      status: before.status,
      at: FieldValue.serverTimestamp(),
    });
  } else if (after && (!before || before.status === "draft")) {
    if (after.status === "draft") {
      await db.collection("auditLogs").add({
        action: before ? "rule_draft_updated" : "rule_draft_created",
        ruleId: event.params.ruleId,
        ruleKey: after.ruleKey,
        version: after.version,
        createdBy: after.createdBy || null,
        at: FieldValue.serverTimestamp(),
      });
    }
  }
});

/**
 * Triggered whenever a project is deleted (from client or emulator/console).
 * Automatically cleans up units subcollection, cutPlans, and remnants originating from this project,
 * and restores any shelf remnants that were consumed by this project.
 */
export const onProjectDeleted = onDocumentDeleted(
  "workshops/{workshopId}/projects/{projectId}",
  async (event) => {
    const { workshopId, projectId } = event.params;
    const batch = db.batch();

    // 1. Delete units subcollection
    const unitsSnap = await db
      .collection(`workshops/${workshopId}/projects/${projectId}/units`)
      .get();
    unitsSnap.forEach((doc) => batch.delete(doc.ref));

    // 2. Delete cut plans for this project
    const plansSnap = await db
      .collection(`workshops/${workshopId}/cutPlans`)
      .where("projectId", "==", projectId)
      .get();
    const planIds: string[] = [];
    plansSnap.forEach((doc) => {
      planIds.push(doc.id);
      batch.delete(doc.ref);
    });

    // 3. Delete remnants originating from this project
    const remnantsSnap = await db
      .collection(`workshops/${workshopId}/remnants`)
      .where("sourceProjectId", "==", projectId)
      .get();
    remnantsSnap.forEach((doc) => batch.delete(doc.ref));

    // 4. Restore shelf remnants consumed by this project's plans
    if (planIds.length > 0) {
      const consumedSnap = await db
        .collection(`workshops/${workshopId}/remnants`)
        .where("usedInPlanId", "in", planIds.slice(0, 10))
        .get();
      consumedSnap.forEach((doc) => {
        batch.update(doc.ref, {
          state: "available",
          usedAt: FieldValue.delete(),
          usedInPlanId: FieldValue.delete(),
        });
      });
    }

    await batch.commit();
  }
);

/**
 * Confirms an order and atomically deducts stock (Phase 6 Core DoD).
 * - Authorized for the order's assigned supplier or an admin.
 * - Idempotent: calling again with the same idempotencyKey returns success without double-deducting.
 * - Aggregates quantities by itemId so duplicate lines never overwrite each other.
 * - Enforces Firestore transaction limits (max 150 unique items).
 * - All-or-nothing: if any item has insufficient balance, aborts completely and changes nothing.
 */
export const confirmOrder = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }

  const callerUid = request.auth.uid;
  const callerRole = request.auth.token.role;
  const callerSupplierId = request.auth.token.supplierId;

  const { orderId, idempotencyKey } = request.data || {};
  if (!orderId || typeof orderId !== "string" || !idempotencyKey || typeof idempotencyKey !== "string") {
    throw new HttpsError("invalid-argument", "Missing or invalid orderId or idempotencyKey");
  }

  const orderRef = db.collection("orders").doc(orderId);

  return await db.runTransaction(async (transaction) => {
    const orderDoc = await transaction.get(orderRef);
    if (!orderDoc.exists) {
      throw new HttpsError("not-found", "الطلب غير موجود");
    }

    const order = orderDoc.data()!;
    const supplierId = order.supplierId as string;

    // 1. Pluggable authorization check: assigned supplier or admin
    const isAuthorized =
      callerRole === "admin" ||
      (callerRole === "supplier" && callerSupplierId === supplierId);
    if (!isAuthorized) {
      throw new HttpsError(
        "permission-denied",
        "فقط المورد المعني أو الإدارة يمكنهم تأكيد الطلب وخصم المخزون"
      );
    }

    // 2. Idempotency check: already confirmed with the same idempotencyKey?
    if (order.status === "confirmed" && order.idempotencyKey === idempotencyKey) {
      return {
        success: true,
        alreadyConfirmed: true,
        orderId,
      };
    }

    if (order.status === "confirmed") {
      throw new HttpsError("already-exists", "تم تأكيد هذا الطلب مسبقاً");
    }

    if (order.status !== "sent" && order.status !== "draft") {
      throw new HttpsError(
        "failed-precondition",
        `لا يمكن تأكيد الطلب في حالته الحالية (${order.status})`
      );
    }

    const rawItems = (order.items || []) as Array<{
      itemId: string;
      nameArabic?: string;
      name?: string;
      qty: number;
      unit: string;
    }>;

    if (rawItems.length === 0) {
      throw new HttpsError("invalid-argument", "الطلب لا يحتوي على أي أصناف");
    }

    // 3. Aggregate quantities by itemId to prevent duplicate line overwrite bugs
    const aggregatedMap = new Map<
      string,
      { itemId: string; nameArabic: string; qty: number; unit: string }
    >();

    for (const item of rawItems) {
      if (!item.itemId || typeof item.qty !== "number" || item.qty <= 0) {
        throw new HttpsError(
          "invalid-argument",
          `بيانات صنف غير صالحة في الطلب (${item.nameArabic || item.itemId})`
        );
      }
      const existing = aggregatedMap.get(item.itemId);
      if (existing) {
        existing.qty += item.qty;
      } else {
        aggregatedMap.set(item.itemId, {
          itemId: item.itemId,
          nameArabic: item.nameArabic || item.name || item.itemId,
          qty: item.qty,
          unit: item.unit || "piece",
        });
      }
    }

    const aggregatedItems = Array.from(aggregatedMap.values());

    // Respect Firestore 500-operation transaction limit (1 read + 2 writes per item + 2 order/audit ops)
    if (aggregatedItems.length > 150) {
      throw new HttpsError(
        "invalid-argument",
        "الطلب يتجاوز الحد الأقصى للأصناف في العملية الواحدة (150 صنفاً). يرجى تجزئة الطلب."
      );
    }

    // 4. Pre-read all stock documents inside transaction
    const stockRefs = aggregatedItems.map((item) =>
      db.doc(`suppliers/${supplierId}/stock/${item.itemId}`)
    );
    const stockDocs = await Promise.all(
      stockRefs.map((ref) => transaction.get(ref))
    );

    // 5. All-or-nothing atomic verification: abort if any item would go negative
    for (let i = 0; i < aggregatedItems.length; i++) {
      const item = aggregatedItems[i];
      const stockDoc = stockDocs[i];
      const currentBalance = stockDoc.exists
        ? Number(stockDoc.data()?.balance ?? 0)
        : 0;

      if (currentBalance < item.qty) {
        throw new HttpsError(
          "failed-precondition",
          `الرصيد غير كافٍ للصنف «${item.nameArabic}». المتوفر: ${currentBalance}، المطلوب: ${item.qty} — لم يتم الخصم`
        );
      }
    }

    // 6. Deduct stock & create inventoryMovements records
    const now = FieldValue.serverTimestamp();
    const nowIso = new Date().toISOString();

    for (let i = 0; i < aggregatedItems.length; i++) {
      const item = aggregatedItems[i];
      const stockRef = stockRefs[i];
      const currentBalance = Number(stockDocs[i].data()?.balance ?? 0);
      const newBalance = currentBalance - item.qty;

      transaction.set(
        stockRef,
        {
          itemId: item.itemId,
          supplierId,
          balance: newBalance,
          unit: item.unit,
          updatedAt: now,
        },
        { merge: true }
      );

      const movementRef = db.collection("inventoryMovements").doc();
      transaction.set(movementRef, {
        movementId: movementRef.id,
        itemId: item.itemId,
        nameArabic: item.nameArabic,
        supplierId,
        qty: item.qty,
        balanceBefore: currentBalance,
        balanceAfter: newBalance,
        unit: item.unit,
        movementType: "deduction",
        orderId,
        idempotencyKey,
        actorUid: callerUid,
        createdAt: now,
      });
    }

    // 7. Update order status and append statusHistory
    const statusHistory = Array.isArray(order.statusHistory)
      ? [...order.statusHistory]
      : [];
    statusHistory.push({
      status: "confirmed",
      changedBy: callerUid,
      changedAt: nowIso,
      note: "تم تأكيد الطلب وخصم الكميات من المخزون بنجاح",
    });

    transaction.update(orderRef, {
      status: "confirmed",
      confirmedBy: callerUid,
      confirmedAt: now,
      idempotencyKey,
      statusHistory,
      updatedAt: now,
    });

    // 8. Write audit log
    const auditRef = db.collection("auditLogs").doc();
    transaction.set(auditRef, {
      action: "order_confirmed",
      entityType: "order",
      entityId: orderId,
      orderId,
      supplierId,
      workshopId: order.workshopId || "",
      actorUid: callerUid,
      idempotencyKey,
      itemsCount: aggregatedItems.length,
      at: now,
    });

    return {
      success: true,
      alreadyConfirmed: false,
      orderId,
    };
  });
});

/**
 * Restocks or adjusts a supplier's inventory balance server-side.
 * Rejects any adjustment that would result in a negative balance.
 */
export const adjustStock = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }

  const callerUid = request.auth.uid;
  const callerRole = request.auth.token.role;
  const callerSupplierId = request.auth.token.supplierId;

  const { supplierId, itemId, nameArabic, qty, unit, movementType, reason } =
    request.data || {};

  if (!supplierId || !itemId || typeof qty !== "number" || qty === 0) {
    throw new HttpsError(
      "invalid-argument",
      "بيانات تعديل المخزون غير مكتملة أو الكمية تساوي صفراً"
    );
  }

  const isAuthorized =
    callerRole === "admin" ||
    (callerRole === "supplier" && callerSupplierId === supplierId);
  if (!isAuthorized) {
    throw new HttpsError(
      "permission-denied",
      "غير مصرح لك بتعديل مخزون هذا المورد"
    );
  }

  const stockRef = db.doc(`suppliers/${supplierId}/stock/${itemId}`);
  const now = FieldValue.serverTimestamp();

  return await db.runTransaction(async (transaction) => {
    const stockDoc = await transaction.get(stockRef);
    const currentBalance = stockDoc.exists
      ? Number(stockDoc.data()?.balance ?? 0)
      : 0;
    const effectiveType =
      movementType === "adjustment" ? "adjustment" : "restock";
    const delta = effectiveType === "restock" ? Math.abs(qty) : qty;
    const newBalance = currentBalance + delta;

    if (newBalance < 0) {
      throw new HttpsError(
        "failed-precondition",
        `لا يمكن أن يصبح رصيد المخزون سالباً (الرصيد الحالي: ${currentBalance})`
      );
    }

    transaction.set(
      stockRef,
      {
        itemId,
        nameArabic: nameArabic || stockDoc.data()?.nameArabic || itemId,
        supplierId,
        balance: newBalance,
        unit: unit || stockDoc.data()?.unit || "piece",
        reservedQty: stockDoc.exists
          ? Number(stockDoc.data()?.reservedQty ?? 0)
          : 0,
        updatedAt: now,
      },
      { merge: true }
    );

    const movementRef = db.collection("inventoryMovements").doc();
    transaction.set(movementRef, {
      movementId: movementRef.id,
      itemId,
      nameArabic: nameArabic || itemId,
      supplierId,
      qty: delta,
      balanceBefore: currentBalance,
      balanceAfter: newBalance,
      unit: unit || "piece",
      movementType: effectiveType,
      reason: reason || "",
      actorUid: callerUid,
      createdAt: now,
    });

    const auditRef = db.collection("auditLogs").doc();
    transaction.set(auditRef, {
      action: `stock_${effectiveType}`,
      entityType: "stock",
      entityId: `${supplierId}:${itemId}`,
      supplierId,
      itemId,
      before: { balance: currentBalance },
      after: { balance: newBalance },
      actorUid: callerUid,
      at: now,
    });

    return {
      success: true,
      itemId,
      balanceBefore: currentBalance,
      balanceAfter: newBalance,
    };
  });
});

/**
 * Transitions order status after confirmation using a strict transition table (Spec §11).
 */
export const updateOrderStatus = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }

  const callerUid = request.auth.uid;
  const callerRole = request.auth.token.role;
  const callerSupplierId = request.auth.token.supplierId;
  const callerWorkshopId = request.auth.token.workshopId;

  const { orderId, newStatus, note } = request.data || {};
  if (!orderId || !newStatus) {
    throw new HttpsError("invalid-argument", "Missing orderId or newStatus");
  }

  if (newStatus === "confirmed") {
    throw new HttpsError(
      "invalid-argument",
      "يجب استخدام دالة confirmOrder لتأكيد الطلب وخصم المخزون"
    );
  }

  const allowedTransitions: Record<string, string[]> = {
    draft: ["sent", "cancelled"],
    sent: ["cancelled"],
    confirmed: ["preparing", "completed", "cancelled"],
    preparing: ["completed", "cancelled"],
    completed: [],
    cancelled: [],
  };

  const orderRef = db.collection("orders").doc(orderId);
  const now = FieldValue.serverTimestamp();
  const nowIso = new Date().toISOString();

  return await db.runTransaction(async (transaction) => {
    const orderDoc = await transaction.get(orderRef);
    if (!orderDoc.exists) {
      throw new HttpsError("not-found", "الطلب غير موجود");
    }

    const order = orderDoc.data()!;
    const currentStatus = order.status as string;

    const isSupplierOrAdmin =
      callerRole === "admin" ||
      (callerRole === "supplier" && callerSupplierId === order.supplierId);
    const isOwner =
      callerRole === "owner" && callerWorkshopId === order.workshopId;

    if (!isSupplierOrAdmin && !isOwner) {
      throw new HttpsError("permission-denied", "غير مصرح لك بتحديث هذا الطلب");
    }

    // Owner can only transition draft -> sent or draft/sent -> cancelled
    if (isOwner && !isSupplierOrAdmin) {
      if (
        !(
          (currentStatus === "draft" &&
            (newStatus === "sent" || newStatus === "cancelled")) ||
          (currentStatus === "sent" && newStatus === "cancelled")
        )
      ) {
        throw new HttpsError(
          "permission-denied",
          "صاحب الورشة يمكنه فقط إرسال المسودة أو إلغاء الطلب قبل التأكيد"
        );
      }
    }

    const validNext = allowedTransitions[currentStatus] || [];
    if (!validNext.includes(newStatus)) {
      throw new HttpsError(
        "failed-precondition",
        `انتقال حالة غير مسموح به من (${currentStatus}) إلى (${newStatus})`
      );
    }

    const statusHistory = Array.isArray(order.statusHistory)
      ? [...order.statusHistory]
      : [];
    statusHistory.push({
      status: newStatus,
      changedBy: callerUid,
      changedAt: nowIso,
      note: note || `تحديث الحالة إلى ${newStatus}`,
    });

    transaction.update(orderRef, {
      status: newStatus,
      statusHistory,
      updatedAt: now,
    });

    const auditRef = db.collection("auditLogs").doc();
    transaction.set(auditRef, {
      action: "order_status_updated",
      entityType: "order",
      entityId: orderId,
      orderId,
      before: { status: currentStatus },
      after: { status: newStatus },
      actorUid: callerUid,
      at: now,
    });

    return { success: true, orderId, status: newStatus };
  });
});


