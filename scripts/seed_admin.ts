import * as admin from "firebase-admin";

// Connect to local emulators
process.env.FIREBASE_AUTH_EMULATOR_HOST = "localhost:9099";
process.env.FIRESTORE_EMULATOR_HOST = "localhost:8085";

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: "demo-meqyas",
  });
}

const auth = admin.auth();
const db = admin.firestore();

async function seedAdmin() {
  const adminEmail = process.argv[2] || "admin@meqyas.com";
  const adminPassword = process.argv[3] || "Admin123";
  const adminName = "مدير النظام (Admin)";

  console.log(`[Seed Admin] Ensuring admin user: ${adminEmail}...`);

  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(adminEmail);
    console.log(`[Seed Admin] User exists with UID: ${userRecord.uid}`);
  } catch (error: any) {
    if (error.code === "auth/user-not-found") {
      userRecord = await auth.createUser({
        email: adminEmail,
        password: adminPassword,
        displayName: adminName,
        emailVerified: true,
      });
      console.log(`[Seed Admin] Created user with UID: ${userRecord.uid}`);
    } else {
      throw error;
    }
  }

  // Set custom claims: role=admin, status=active
  await auth.setCustomUserClaims(userRecord.uid, {
    role: "admin",
    status: "active",
  });
  console.log(`[Seed Admin] Custom claims set: { role: 'admin', status: 'active' }`);

  // Write users/{uid} document in Firestore
  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.collection("users").doc(userRecord.uid).set(
    {
      fullName: adminName,
      email: adminEmail,
      phone: "+966500000000",
      phoneVerifiedAt: now,
      role: "admin",
      status: "active",
      createdAt: now,
      updatedAt: now,
    },
    { merge: true }
  );

  console.log(`[Seed Admin] Successfully seeded admin user in Firestore!`);
  console.log(`-----------------------------------------------`);
  console.log(`Login credentials:`);
  console.log(`Email:    ${adminEmail}`);
  console.log(`Password: ${adminPassword}`);
  console.log(`-----------------------------------------------`);
}

seedAdmin()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(`[Seed Admin Error]:`, err);
    process.exit(1);
  });
