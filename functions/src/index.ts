import * as admin from "firebase-admin";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

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
