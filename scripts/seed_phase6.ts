import * as admin from "firebase-admin";

const useEmulator = process.env.USE_FIREBASE_EMULATOR === "true";
if (useEmulator) {
  process.env.FIREBASE_AUTH_EMULATOR_HOST = "localhost:9099";
  process.env.FIRESTORE_EMULATOR_HOST = "localhost:8085";
} else {
  delete process.env.FIREBASE_AUTH_EMULATOR_HOST;
  delete process.env.FIRESTORE_EMULATOR_HOST;
}

const projectId = process.env.FIREBASE_PROJECT_ID || "meqyas-app-2026";

if (!admin.apps.length) {
  admin.initializeApp({
    projectId,
  });
}

const auth = admin.auth();
const db = admin.firestore();

async function ensureAuthUser(params: {
  email: string;
  password: string;
  displayName: string;
  claims: Record<string, any>;
}) {
  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(params.email);
    await auth.updateUser(userRecord.uid, {
      password: params.password,
      displayName: params.displayName,
      emailVerified: true,
    });
  } catch (err: any) {
    if (err.code === "auth/user-not-found") {
      userRecord = await auth.createUser({
        email: params.email,
        password: params.password,
        displayName: params.displayName,
        emailVerified: true,
      });
    } else {
      throw err;
    }
  }
  await auth.setCustomUserClaims(userRecord.uid, params.claims);
  return userRecord;
}

async function seedPhase6() {
  console.log(
    "[Seed Phase 6] Seeding Owner & Workshop, Suppliers Directory, Project Requirements (§5.4), and Interactive Supplier Orders (§5.5)..."
  );
  const now = admin.firestore.FieldValue.serverTimestamp();
  const batch = db.batch();

  // =========================================================================
  // 1. Seed Workshop Owner & Active Workshop (Capabilities: Projects, Units,
  //    Cut Plan, Project Requirements, 3 Post-Requirements Options, Order Tracking)
  // =========================================================================
  const workshopId = "w_al_noor";
  const workshopName = "ورشة النور للألمنيوم والزجاج";
  const ownerEmail = "owner@meqyas.com";
  const ownerPassword = "Owner123";
  const ownerName = "م. أحمد العتيبي";

  const ownerUser = await ensureAuthUser({
    email: ownerEmail,
    password: ownerPassword,
    displayName: ownerName,
    claims: {
      role: "owner",
      workshopId,
      status: "active",
    },
  });

  batch.set(
    db.collection("users").doc(ownerUser.uid),
    {
      fullName: ownerName,
      email: ownerEmail,
      phone: "966501234567",
      phoneVerifiedAt: now,
      role: "owner",
      status: "active",
      workshopId,
      createdAt: now,
      updatedAt: now,
    },
    { merge: true }
  );

  const workshopRef = db.collection("workshops").doc(workshopId);
  batch.set(
    workshopRef,
    {
      id: workshopId,
      name: workshopName,
      ownerUid: ownerUser.uid,
      location: "الرياض — الصناعية الثانية",
      phone: "0501234567",
      createdAt: now,
      updatedAt: now,
    },
    { merge: true }
  );

  // =========================================================================
  // 2. Seed Suppliers (Directory & Interactive Order Review Only —
  //    NO Catalog, NO Pre-set Price Lists, NO Stock Management)
  // =========================================================================
  const supplier1Id = "sup_national_aluminum";
  const supplier1Email = "supplier@meqyas.com";
  const supplier1Password = "Supplier123";
  const supplier1Name = "شركة التوريدات الوطنية للألمنيوم والملحقات";

  const supplier1User = await ensureAuthUser({
    email: supplier1Email,
    password: supplier1Password,
    displayName: supplier1Name,
    claims: {
      role: "supplier",
      supplierId: supplier1Id,
      status: "active",
    },
  });

  batch.set(
    db.collection("users").doc(supplier1User.uid),
    {
      fullName: supplier1Name,
      email: supplier1Email,
      phone: "966500000001",
      phoneVerifiedAt: now,
      role: "supplier",
      status: "active",
      supplierId: supplier1Id,
      createdAt: now,
      updatedAt: now,
    },
    { merge: true }
  );

  batch.set(db.collection("suppliers").doc(supplier1Id), {
    id: supplier1Id,
    name: supplier1Name,
    phone: "966500000001",
    whatsappPhones: ["966500000001", "966500000002"],
    address: "المنطقة الصناعية الثانية — الرياض",
    createdAt: now,
    updatedAt: now,
  });

  const supplier2Id = "sup_gulf_glass";
  const supplier2Name = "مؤسسة الخليج للزجاج والإكسسوارات المعمارية";
  batch.set(db.collection("suppliers").doc(supplier2Id), {
    id: supplier2Id,
    name: supplier2Name,
    phone: "966550000099",
    whatsappPhones: ["966550000099"],
    address: "طريق الخرج — الرياض",
    createdAt: now,
    updatedAt: now,
  });

  // =========================================================================
  // 3. Seed Sample Project, Units & Project Requirements Table (§5.4)
  // =========================================================================
  const projectId = "p_villa_yasmin";
  const projectName = "مشروع فيلا الياسمين";
  const projectRef = workshopRef.collection("projects").doc(projectId);

  batch.set(projectRef, {
    id: projectId,
    workshopId,
    name: projectName,
    clientName: "خالد السالم",
    clientPhone: "0551234567",
    location: "الرياض — حي الياسمين",
    unitCount: 2,
    defaultAluminumColor: "أبيض",
    defaultAluminumThickness: "1.3 مم",
    requirementsGeneratedAt: now,
    createdAt: now,
    updatedAt: now,
  });

  // Sample Units inside the project
  batch.set(projectRef.collection("units").doc("u_win_1"), {
    id: "u_win_1",
    projectId,
    name: "شباك صالة 200×150",
    location: "الدور الأرضي — الصالة",
    widthCm: 200,
    heightCm: 150,
    quantity: 3,
    unitType: "window",
    profileSystemId: "system_2000_beaded",
    glazingMode: "single",
    sharhOption: "none",
    sashCount: 2,
    screenCount: 1,
    hasScreen: true,
    rollerType: "slider",
    glassType: "clear",
    glassThicknessMm: 6.0,
    hasCorners: true,
    hasGasket: true,
    createdAt: now,
    updatedAt: now,
  });

  batch.set(projectRef.collection("units").doc("u_win_2"), {
    id: "u_win_2",
    projectId,
    name: "شباك غرفة نوم 120×140",
    location: "الدور الأول — الغرفة الرئيسية",
    widthCm: 120,
    heightCm: 140,
    quantity: 4,
    unitType: "window",
    profileSystemId: "system_2000_beaded",
    glazingMode: "single",
    sharhOption: "none",
    sashCount: 2,
    screenCount: 1,
    hasScreen: true,
    rollerType: "slider",
    glassType: "clear",
    glassThicknessMm: 6.0,
    hasCorners: true,
    hasGasket: true,
    createdAt: now,
    updatedAt: now,
  });

  // Sample Project Materials Requirements (§5.4)
  const requirementLines = [
    {
      id: "req_track",
      engineItemCode: "track",
      nameArabic: "سكة 2000 بحاجب (قضيب 6.6م)",
      category: "aluminum",
      requiredQty: 8,
      inStockQty: 2,
      toBuyQty: 6,
      isToBuyOverridden: false,
      needsReviewAfterRegen: false,
      unit: "bar",
      note: "لون أبيض 1.3 مم",
      source: "auto",
      dismissed: false,
    },
    {
      id: "req_u_profile",
      engineItemCode: "u_profile",
      nameArabic: "يو 2000 جانبي (قضيب 6.6م)",
      category: "aluminum",
      requiredQty: 7,
      inStockQty: 0,
      toBuyQty: 7,
      isToBuyOverridden: false,
      needsReviewAfterRegen: false,
      unit: "bar",
      note: "لون أبيض 1.2 مم",
      source: "auto",
      dismissed: false,
    },
    {
      id: "req_kaab",
      engineItemCode: "kaab",
      nameArabic: "كعب 2000 مفرد (قضيب 6.6م)",
      category: "aluminum",
      requiredQty: 9,
      inStockQty: 1,
      toBuyQty: 8,
      isToBuyOverridden: false,
      needsReviewAfterRegen: false,
      unit: "bar",
      note: "",
      source: "auto",
      dismissed: false,
    },
    {
      id: "req_glass",
      engineItemCode: "glass_pane",
      nameArabic: "زجاج شفاف 6 ملم",
      category: "glass",
      requiredQty: 14.5,
      inStockQty: 0,
      toBuyQty: 14.5,
      isToBuyOverridden: false,
      needsReviewAfterRegen: false,
      unit: "m2",
      note: "شامل تقصيب الحواف",
      source: "auto",
      dismissed: false,
    },
    {
      id: "req_handle",
      engineItemCode: "glass_handle",
      nameArabic: "مسكة درفة زجاج 2000",
      category: "accessories",
      requiredQty: 14,
      inStockQty: 4,
      toBuyQty: 10,
      isToBuyOverridden: false,
      needsReviewAfterRegen: false,
      unit: "piece",
      note: "لون أبيض",
      source: "auto",
      dismissed: false,
    },
    {
      id: "req_mesh_roll",
      engineItemCode: "fiber_mesh_roll",
      nameArabic: "لفة شبك منخل فيبر عرض 120 سم",
      category: "fiber",
      requiredQty: 2,
      inStockQty: 0,
      toBuyQty: 2,
      isToBuyOverridden: false,
      needsReviewAfterRegen: false,
      unit: "roll",
      note: "",
      source: "auto",
      dismissed: false,
    },
  ];

  for (const line of requirementLines) {
    batch.set(projectRef.collection("requirements").doc(line.id), {
      ...line,
      createdAt: now,
      updatedAt: now,
    });
  }

  // =========================================================================
  // 4. Seed Sample Orders (§5.5 Flow: Sent Request & Supplier Priced Quote)
  // =========================================================================

  // Order 1: Sent by Workshop Owner from Project Requirements -> Waiting for Supplier response
  const orderSentId = "ord_yasmin_sent";
  batch.set(db.collection("orders").doc(orderSentId), {
    orderNumber: "PO-2026-YS01",
    projectId,
    projectName,
    workshopId,
    workshopName,
    workshopPhone: "0501234567",
    workshopLocation: "الرياض — الصناعية الثانية",
    supplierId: supplier1Id,
    supplierName: supplier1Name,
    status: "sent",
    currency: "SAR",
    totalAmount: 0,
    supplierResponseNote: "",
    idempotencyKey: "idem_ord_yasmin_sent",
    items: [
      {
        itemId: "req_track",
        nameArabic: "سكة 2000 بحاجب (قضيب 6.6م)",
        category: "aluminum",
        requestedQty: 6,
        qty: 6,
        unit: "bar",
        isAvailable: true,
        unitPrice: 0,
        lineTotal: 0,
        note: "لون أبيض 1.3 مم",
        supplierNote: "",
      },
      {
        itemId: "req_u_profile",
        nameArabic: "يو 2000 جانبي (قضيب 6.6م)",
        category: "aluminum",
        requestedQty: 7,
        qty: 7,
        unit: "bar",
        isAvailable: true,
        unitPrice: 0,
        lineTotal: 0,
        note: "لون أبيض 1.2 مم",
        supplierNote: "",
      },
      {
        itemId: "req_kaab",
        nameArabic: "كعب 2000 مفرد (قضيب 6.6م)",
        category: "aluminum",
        requestedQty: 8,
        qty: 8,
        unit: "bar",
        isAvailable: true,
        unitPrice: 0,
        lineTotal: 0,
        note: "",
        supplierNote: "",
      },
    ],
    statusHistory: [
      {
        status: "sent",
        actorUid: ownerUser.uid,
        note: "طلب تسعير وتوريد مواد مشروع فيلا الياسمين",
        timestamp: new Date().toISOString(),
      },
    ],
    createdAt: now,
    updatedAt: now,
  });

  // Order 2: Reviewed & Priced manually by Supplier (`status: "quoted"`) -> Ready for Owner Approval
  const orderQuotedId = "ord_yasmin_quoted";
  batch.set(db.collection("orders").doc(orderQuotedId), {
    orderNumber: "PO-2026-YS02",
    projectId,
    projectName,
    workshopId,
    workshopName,
    workshopPhone: "0501234567",
    workshopLocation: "الرياض — الصناعية الثانية",
    supplierId: supplier1Id,
    supplierName: supplier1Name,
    status: "quoted",
    currency: "SAR",
    totalAmount: 1327.5,
    supplierResponseNote:
      "تم تسعير الأصناف المتوفرة — التوصيل للورشة خلال 24 ساعة بعد الاعتماد",
    idempotencyKey: "idem_ord_yasmin_quoted",
    items: [
      {
        itemId: "req_glass",
        nameArabic: "زجاج شفاف 6 ملم",
        category: "glass",
        requestedQty: 14.5,
        qty: 14.5,
        unit: "m2",
        isAvailable: true,
        unitPrice: 65,
        lineTotal: 942.5,
        note: "شامل تقصيب الحواف",
        supplierNote: "متوفر بالكامل جاهز للقص",
      },
      {
        itemId: "req_handle",
        nameArabic: "مسكة درفة زجاج 2000",
        category: "accessories",
        requestedQty: 10,
        qty: 8,
        unit: "piece",
        isAvailable: true,
        unitPrice: 25,
        lineTotal: 200,
        note: "لون أبيض",
        supplierNote: "متوفر 8 حبات حالياً في المستودع",
      },
      {
        itemId: "req_mesh_roll",
        nameArabic: "لفة شبك منخل فيبر عرض 120 سم",
        category: "fiber",
        requestedQty: 2,
        qty: 2,
        unit: "roll",
        isAvailable: true,
        unitPrice: 92.5,
        lineTotal: 185,
        note: "",
        supplierNote: "نوع أمريكي ممتاز",
      },
    ],
    statusHistory: [
      {
        status: "sent",
        actorUid: ownerUser.uid,
        note: "إرسال طلب تسعير للزجاج والإكسسوارات",
        timestamp: new Date(Date.now() - 3600 * 1000).toISOString(),
      },
      {
        status: "quoted",
        actorUid: supplier1User.uid,
        note: "تم تسعير الأصناف المتوفرة وتعديل كمية المسكات إلى 8 حبات",
        timestamp: new Date().toISOString(),
      },
    ],
    createdAt: now,
    updatedAt: now,
  });

  await batch.commit();
  console.log("[Seed Phase 6] Done!");
  console.log("  • Workshop Owner Login : owner@meqyas.com / Owner123");
  console.log("  • Supplier Login       : supplier@meqyas.com / Supplier123");
}

seedPhase6().catch((err) => {
  console.error("[Seed Phase 6] Error:", err);
  process.exit(1);
});
