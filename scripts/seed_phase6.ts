import * as admin from "firebase-admin";

process.env.FIREBASE_AUTH_EMULATOR_HOST = "localhost:9099";
process.env.FIRESTORE_EMULATOR_HOST = "localhost:8085";

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: "demo-meqyas",
  });
}

const auth = admin.auth();
const db = admin.firestore();

async function seedPhase6() {
  console.log("[Seed Phase 6] Seeding Supplier Auth User, Catalog Items, Suppliers, Prices & Initial Stock...");
  const now = admin.firestore.FieldValue.serverTimestamp();
  const batch = db.batch();

  // 1. Seed Suppliers & Default Supplier Auth User
  const supplierId = "sup_national_aluminum";
  const supplierEmail = "supplier@meqyas.com";
  const supplierPassword = "Supplier123";
  const supplierName = "شركة التوريدات الوطنية للألمنيوم والملحقات";

  let supplierUser;
  try {
    supplierUser = await auth.getUserByEmail(supplierEmail);
  } catch (err: any) {
    if (err.code === "auth/user-not-found") {
      supplierUser = await auth.createUser({
        email: supplierEmail,
        password: supplierPassword,
        displayName: supplierName,
        emailVerified: true,
      });
    } else {
      throw err;
    }
  }

  await auth.setCustomUserClaims(supplierUser.uid, {
    role: "supplier",
    supplierId,
    status: "active",
  });

  const userRef = db.collection("users").doc(supplierUser.uid);
  batch.set(
    userRef,
    {
      fullName: supplierName,
      email: supplierEmail,
      phone: "966500000001",
      phoneVerifiedAt: now,
      role: "supplier",
      status: "active",
      supplierId,
      createdAt: now,
      updatedAt: now,
    },
    { merge: true }
  );

  const supplierRef = db.collection("suppliers").doc(supplierId);
  batch.set(supplierRef, {
    id: supplierId,
    name: supplierName,
    phone: "966500000001",
    whatsappPhones: ["966500000001", "966500000002"],
    address: "المنطقة الصناعية — الرياض",
    createdAt: now,
    updatedAt: now,
  });

  // 2. Seed Catalog Items, Supplier Prices, and Stock
  const items = [
    {
      id: "cat_al_track_2000",
      code: "AL-TRK-2000",
      engineItemCode: "track",
      arabicName: "سكة 2000 بحاجب (قضيب 6.6م)",
      categoryId: "aluminum",
      unit: "bar",
      color: "أبيض",
      thickness: "1.3 مم",
      status: "active",
      price: 145.0,
      stock: 100,
    },
    {
      id: "cat_al_u_2000",
      code: "AL-UPR-2000",
      engineItemCode: "u_profile",
      arabicName: "يو 2000 جانبي (قضيب 6.6م)",
      categoryId: "aluminum",
      unit: "bar",
      color: "أبيض",
      thickness: "1.2 مم",
      status: "active",
      price: 95.0,
      stock: 120,
    },
    {
      id: "cat_al_kaab_2000",
      code: "AL-KAB-2000",
      engineItemCode: "kaab",
      arabicName: "كعب 2000 مفرد (قضيب 6.6م)",
      categoryId: "aluminum",
      unit: "bar",
      color: "أبيض",
      thickness: "1.3 مم",
      status: "active",
      price: 115.0,
      stock: 100,
    },
    {
      id: "cat_al_scr_vert_2000",
      code: "AL-SCV-2000",
      engineItemCode: "screen_vertical",
      arabicName: "درفة منخل عامودي 2000 (قضيب 6.6م)",
      categoryId: "aluminum",
      unit: "bar",
      color: "أبيض",
      thickness: "1.1 مم",
      status: "active",
      price: 75.0,
      stock: 80,
    },
    {
      id: "cat_al_scr_horiz_2000",
      code: "AL-SCH-2000",
      engineItemCode: "screen_horizontal",
      arabicName: "درفة منخل أفقي 2000 (قضيب 6.6م)",
      categoryId: "aluminum",
      unit: "bar",
      color: "أبيض",
      thickness: "1.1 مم",
      status: "active",
      price: 75.0,
      stock: 80,
    },
    {
      id: "cat_gl_clear_6mm",
      code: "GL-CLR-06",
      engineItemCode: "glass_pane",
      arabicName: "زجاج شفاف 6 ملم",
      categoryId: "glass",
      unit: "m2",
      color: "شفاف",
      thickness: "6 مم",
      status: "active",
      price: 65.0,
      stock: 500,
    },
    {
      id: "cat_acc_glass_handle",
      code: "AC-HND-GLS",
      engineItemCode: "glass_handle",
      arabicName: "مسكة درفة زجاج 2000",
      categoryId: "accessories",
      unit: "piece",
      color: "أبيض",
      thickness: "",
      status: "active",
      price: 18.0,
      stock: 300,
    },
    {
      id: "cat_fb_mesh_120",
      code: "FB-MSH-120",
      engineItemCode: "fiber_mesh_roll",
      arabicName: "لفة شبك منخل فيبر عرض 120 سم × 20 م",
      categoryId: "fiber",
      unit: "roll",
      color: "رمادي",
      thickness: "",
      status: "active",
      price: 90.0,
      stock: 40,
    },
  ];

  for (const item of items) {
    const catRef = db.collection("catalogItems").doc(item.id);
    batch.set(catRef, {
      id: item.id,
      code: item.code,
      engineItemCode: item.engineItemCode,
      arabicName: item.arabicName,
      categoryId: item.categoryId,
      unit: item.unit,
      color: item.color,
      thickness: item.thickness,
      status: item.status,
      createdAt: now,
      updatedAt: now,
    });

    const priceRef = supplierRef.collection("prices").doc(item.id);
    batch.set(priceRef, {
      itemId: item.id,
      supplierId,
      price: item.price,
      currency: "SAR",
      validFrom: now,
      updatedAt: now,
    });

    const stockRef = supplierRef.collection("stock").doc(item.id);
    batch.set(stockRef, {
      itemId: item.id,
      nameArabic: item.arabicName,
      supplierId,
      balance: item.stock,
      unit: item.unit,
      reservedQty: 0,
      lowStockThreshold: 10,
      updatedAt: now,
    });
  }

  await batch.commit();
  console.log("[Seed Phase 6] Done!");
}

seedPhase6().catch((err) => {
  console.error("[Seed Phase 6] Error:", err);
  process.exit(1);
});

