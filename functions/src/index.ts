import * as admin from "firebase-admin";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

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
