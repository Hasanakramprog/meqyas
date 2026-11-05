/**
 * Cloud Firebase Seeder for `meqyas-app-2026`
 * Uses official Firebase Auth REST API & Cloud Firestore REST API so no
 * Service Account private key download is required.
 */

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || "meqyas-app-2026";
const API_KEY =
  process.env.FIREBASE_API_KEY || "AIzaSyD5GNRTUkPniKX3ZAHouItmh9ae4oBFcdE";

const AUTH_BASE = "https://identitytoolkit.googleapis.com/v1";
const FIRESTORE_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

function toFirestoreValue(val) {
  if (val === null || val === undefined) {
    return { nullValue: null };
  }
  if (val instanceof Date) {
    return { timestampValue: val.toISOString() };
  }
  if (typeof val === "boolean") {
    return { booleanValue: val };
  }
  if (typeof val === "number") {
    if (Number.isInteger(val)) {
      return { integerValue: String(val) };
    }
    return { doubleValue: val };
  }
  if (typeof val === "string") {
    return { stringValue: val };
  }
  if (Array.isArray(val)) {
    return {
      arrayValue: {
        values: val.map((item) => toFirestoreValue(item)),
      },
    };
  }
  if (typeof val === "object") {
    const fields = {};
    for (const [k, v] of Object.entries(val)) {
      if (v !== undefined) {
        fields[k] = toFirestoreValue(v);
      }
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(val) };
}

async function ensureAuthAccount({ email, password, displayName }) {
  // Try sign-in first
  let res = await fetch(
    `${AUTH_BASE}/accounts:signInWithPassword?key=${API_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    }
  );
  let data = await res.json();

  if (!res.ok) {
    // Sign up new user
    res = await fetch(`${AUTH_BASE}/accounts:signUp?key=${API_KEY}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    });
    data = await res.json();
    if (!res.ok) {
      throw new Error(
        `Auth failed for ${email}: ${JSON.stringify(data.error || data)}`
      );
    }
  }

  const idToken = data.idToken;
  const uid = data.localId;

  // Update displayName
  await fetch(`${AUTH_BASE}/accounts:update?key=${API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      idToken,
      displayName,
      returnSecureToken: false,
    }),
  });

  return { uid, idToken, email };
}

async function setDoc(docPath, obj, idToken) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v !== undefined) {
      fields[k] = toFirestoreValue(v);
    }
  }
  const url = `${FIRESTORE_BASE}/${docPath}`;
  const res = await fetch(url, {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${idToken}`,
    },
    body: JSON.stringify({ fields }),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Failed writing ${docPath} (${res.status}): ${errText}`);
  }
}

async function seedCloud() {
  console.log(
    `[Cloud Seed] Connecting to real Firebase project: ${PROJECT_ID}...`
  );
  const now = new Date();

  // 1. Ensure 3 Demo Auth Accounts: Admin, Workshop Owner, Supplier
  console.log("[Cloud Seed] Ensuring Auth users (Admin, Owner, Supplier)...");
  const adminUser = await ensureAuthAccount({
    email: "admin@meqyas.com",
    password: "Admin123",
    displayName: "مدير النظام (Admin)",
  });
  const ownerUser = await ensureAuthAccount({
    email: "owner@meqyas.com",
    password: "Owner123",
    displayName: "م. أحمد العتيبي",
  });
  const supplierUser = await ensureAuthAccount({
    email: "supplier@meqyas.com",
    password: "Supplier123",
    displayName: "شركة التوريدات الوطنية للألمنيوم والملحقات",
  });

  const workshopId = "w_al_noor";
  const workshopName = "ورشة النور للألمنيوم والزجاج";
  const supplier1Id = "sup_national_aluminum";
  const supplier1Name = "شركة التوريدات الوطنية للألمنيوم والملحقات";
  const supplier2Id = "sup_gulf_glass";
  const supplier2Name = "مؤسسة الخليج للزجاج والإكسسوارات المعمارية";

  // 2. Write each user's own `users/{uid}` document
  console.log("[Cloud Seed] Seeding users/{uid} documents...");
  await setDoc(
    `users/${adminUser.uid}`,
    {
      uid: adminUser.uid,
      fullName: "مدير النظام (Admin)",
      email: "admin@meqyas.com",
      phone: "+966500000000",
      isEmailVerified: true,
      phoneVerifiedAt: now,
      role: "admin",
      status: "active",
      createdAt: now,
      updatedAt: now,
    },
    adminUser.idToken
  );

  await setDoc(
    `users/${ownerUser.uid}`,
    {
      uid: ownerUser.uid,
      fullName: "م. أحمد العتيبي",
      email: "owner@meqyas.com",
      phone: "966501234567",
      isEmailVerified: true,
      phoneVerifiedAt: now,
      role: "owner",
      status: "active",
      workshopId,
      createdAt: now,
      updatedAt: now,
    },
    ownerUser.idToken
  );

  await setDoc(
    `users/${supplierUser.uid}`,
    {
      uid: supplierUser.uid,
      fullName: supplier1Name,
      email: "supplier@meqyas.com",
      phone: "966500000001",
      isEmailVerified: true,
      phoneVerifiedAt: now,
      role: "supplier",
      status: "active",
      supplierId: supplier1Id,
      createdAt: now,
      updatedAt: now,
    },
    supplierUser.idToken
  );

  // 3. Seed Profile Systems, Calculation Rules & Cutting Optimizer Config (as Admin)
  console.log(
    "[Cloud Seed] Seeding Profile Systems, Calculation Rules & Optimizer Defaults..."
  );
  await setDoc(
    "profileSystems/system_2000_beaded",
    {
      id: "system_2000_beaded",
      nameArabic: "نظام 2000 بحاجب",
      active: true,
      createdAt: now,
      updatedAt: now,
    },
    adminUser.idToken
  );

  const rules = [
    {
      id: "rule_2000_track_v1",
      itemCode: "track",
      ruleKey: "system_2000_beaded:track",
      profileSystemId: "system_2000_beaded",
      status: "approved",
      priority: 10,
      version: 1,
      effectiveAt: new Date(2026, 0, 1),
      conditions: ["unitType == 'window' || unitType == 'facade'"],
      quantityFormula: "2",
      lengthFormula: "W - 3",
      dependsOn: [],
      nameArabic: "سكة 2000 بحاجب",
      outputKind: "profile",
      profileType: "track",
      cutAngleLeft: 90.0,
      cutAngleRight: 90.0,
      notes: "سكة علوية وسفلية لنظام 2000 بحاجب",
      createdBy: "system",
      approvedBy: "system",
      approvedAt: new Date(2026, 0, 1),
    },
    {
      id: "rule_2000_u_profile_v1",
      itemCode: "u_profile",
      ruleKey: "system_2000_beaded:u_profile",
      profileSystemId: "system_2000_beaded",
      status: "approved",
      priority: 10,
      version: 1,
      effectiveAt: new Date(2026, 0, 1),
      conditions: ["unitType == 'window' || unitType == 'facade'"],
      quantityFormula: "2",
      lengthFormula: "H - 3.3",
      dependsOn: [],
      nameArabic: "يو 2000",
      outputKind: "profile",
      profileType: "jamb",
      cutAngleLeft: 90.0,
      cutAngleRight: 90.0,
      notes: "قائم جانبي يو لنظام 2000",
      createdBy: "system",
      approvedBy: "system",
      approvedAt: new Date(2026, 0, 1),
    },
    {
      id: "rule_2000_kaab_v1",
      itemCode: "kaab",
      ruleKey: "system_2000_beaded:kaab",
      profileSystemId: "system_2000_beaded",
      status: "approved",
      priority: 10,
      version: 1,
      effectiveAt: new Date(2026, 0, 1),
      conditions: ["glazingMode == 'single'"],
      quantityFormula: "2 * sashCount",
      lengthFormula: "(W - 2.5) / 2",
      dependsOn: [],
      nameArabic: "كعب 2000 مفرد",
      outputKind: "profile",
      profileType: "sash",
      cutAngleLeft: 45.0,
      cutAngleRight: 45.0,
      notes: "كعب درفة زجاج مفرد 45 درجة",
      createdBy: "system",
      approvedBy: "system",
      approvedAt: new Date(2026, 0, 1),
    },
    {
      id: "rule_2000_screen_vert_v1",
      itemCode: "screen_vertical",
      ruleKey: "system_2000_beaded:screen_vertical",
      profileSystemId: "system_2000_beaded",
      status: "approved",
      priority: 10,
      version: 1,
      effectiveAt: new Date(2026, 0, 1),
      conditions: ["hasScreen == true", "screenCount > 0"],
      quantityFormula: "2 * screenCount",
      lengthFormula: "H - 4.1",
      dependsOn: [],
      nameArabic: "درفة منخل عامودي",
      outputKind: "profile",
      profileType: "screen",
      cutAngleLeft: 45.0,
      cutAngleRight: 45.0,
      notes: "قوائم منخل عامودية",
      createdBy: "system",
      approvedBy: "system",
      approvedAt: new Date(2026, 0, 1),
    },
    {
      id: "rule_2000_screen_horiz_v1",
      itemCode: "screen_horizontal",
      ruleKey: "system_2000_beaded:screen_horizontal",
      profileSystemId: "system_2000_beaded",
      status: "approved",
      priority: 10,
      version: 1,
      effectiveAt: new Date(2026, 0, 1),
      conditions: ["hasScreen == true", "screenCount > 0"],
      quantityFormula: "2 * screenCount",
      lengthFormula: "kaab_len + 2",
      dependsOn: ["kaab_len"],
      nameArabic: "درفة منخل أفقي",
      outputKind: "profile",
      profileType: "screen",
      cutAngleLeft: 45.0,
      cutAngleRight: 45.0,
      notes: "عوارض منخل أفقية معتمدة على طول الكعب",
      createdBy: "system",
      approvedBy: "system",
      approvedAt: new Date(2026, 0, 1),
    },
    {
      id: "rule_2000_glass_height_v1",
      itemCode: "glass_height",
      ruleKey: "system_2000_beaded:glass_height",
      profileSystemId: "system_2000_beaded",
      status: "approved",
      priority: 10,
      version: 1,
      effectiveAt: new Date(2026, 0, 1),
      conditions: [],
      quantityFormula: "sashCount",
      lengthFormula: "H - 14",
      dependsOn: [],
      nameArabic: "ارتفاع الزجاج",
      outputKind: "glass_height",
      profileType: "other",
      cutAngleLeft: 90.0,
      cutAngleRight: 90.0,
      notes: "حساب ارتفاع لوح الزجاج",
      createdBy: "system",
      approvedBy: "system",
      approvedAt: new Date(2026, 0, 1),
    },
    {
      id: "rule_2000_glass_width_v1",
      itemCode: "glass_width",
      ruleKey: "system_2000_beaded:glass_width",
      profileSystemId: "system_2000_beaded",
      status: "approved",
      priority: 10,
      version: 1,
      effectiveAt: new Date(2026, 0, 1),
      conditions: [],
      quantityFormula: "sashCount",
      lengthFormula: "(W - 16.2) / 2",
      dependsOn: [],
      nameArabic: "عرض الزجاج للدرفة",
      outputKind: "glass_width",
      profileType: "other",
      cutAngleLeft: 90.0,
      cutAngleRight: 90.0,
      notes: "حساب عرض لوح الزجاج لكل درفة",
      createdBy: "system",
      approvedBy: "system",
      approvedAt: new Date(2026, 0, 1),
    },
  ];

  for (const r of rules) {
    await setDoc(
      `calculationRules/${r.id}`,
      {
        ...r,
        createdAt: now,
        updatedAt: now,
      },
      adminUser.idToken
    );
  }

  await setDoc(
    "systemConfigs/cuttingOptimizer",
    {
      barLengthCm: 660.0,
      trimLossCm: 4.0,
      kerfPerCutCm: 0.5,
      minRemnantCm: 50.0,
      updatedBy: "system",
      createdAt: now,
      updatedAt: now,
    },
    adminUser.idToken
  );

  // 4. Seed Suppliers Directory (as Admin)
  console.log("[Cloud Seed] Seeding Suppliers Directory...");
  await setDoc(
    `suppliers/${supplier1Id}`,
    {
      id: supplier1Id,
      name: supplier1Name,
      phone: "966500000001",
      whatsappPhones: ["966500000001", "966500000002"],
      address: "المنطقة الصناعية الثانية — الرياض",
      createdAt: now,
      updatedAt: now,
    },
    adminUser.idToken
  );

  await setDoc(
    `suppliers/${supplier2Id}`,
    {
      id: supplier2Id,
      name: supplier2Name,
      phone: "966550000099",
      whatsappPhones: ["966550000099"],
      address: "طريق الخرج — الرياض",
      createdAt: now,
      updatedAt: now,
    },
    adminUser.idToken
  );

  // 5. Seed Workshop, Sample Project, Units & Requirements (as Owner)
  console.log(
    "[Cloud Seed] Seeding Workshop, Project (فيلا الياسمين), Units & Requirements..."
  );
  await setDoc(
    `workshops/${workshopId}`,
    {
      id: workshopId,
      name: workshopName,
      ownerUid: ownerUser.uid,
      location: "الرياض — الصناعية الثانية",
      phone: "0501234567",
      status: "active",
      createdAt: now,
      updatedAt: now,
    },
    ownerUser.idToken
  );

  const projectId = "p_villa_yasmin";
  const projectName = "مشروع فيلا الياسمين";
  await setDoc(
    `workshops/${workshopId}/projects/${projectId}`,
    {
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
    },
    ownerUser.idToken
  );

  await setDoc(
    `workshops/${workshopId}/projects/${projectId}/units/u_win_1`,
    {
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
    },
    ownerUser.idToken
  );

  await setDoc(
    `workshops/${workshopId}/projects/${projectId}/units/u_win_2`,
    {
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
    },
    ownerUser.idToken
  );

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
    await setDoc(
      `workshops/${workshopId}/projects/${projectId}/requirements/${line.id}`,
      {
        ...line,
        createdAt: now,
        updatedAt: now,
      },
      ownerUser.idToken
    );
  }

  // 6. Seed Interactive Supplier Orders (§5.5)
  console.log("[Cloud Seed] Seeding Interactive Supplier Orders...");
  await setDoc(
    "orders/ord_yasmin_sent",
    {
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
          timestamp: now.toISOString(),
        },
      ],
      createdAt: now,
      updatedAt: now,
    },
    adminUser.idToken
  );

  // First create ord_yasmin_quoted in 'sent' status (satisfies orders create rule), then transition to 'quoted'
  await setDoc(
    "orders/ord_yasmin_quoted",
    {
      orderNumber: "PO-2026-YS02",
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
      idempotencyKey: "idem_ord_yasmin_quoted",
      items: [],
      statusHistory: [],
      createdAt: now,
      updatedAt: now,
    },
    ownerUser.idToken
  );

  await setDoc(
    "orders/ord_yasmin_quoted",
    {
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
          actorUid: supplierUser.uid,
          note: "تم تسعير الأصناف المتوفرة وتعديل كمية المسكات إلى 8 حبات",
          timestamp: now.toISOString(),
        },
      ],
      createdAt: now,
      updatedAt: now,
    },
    adminUser.idToken
  );

  // 7. Seed initial notifications for Owner & Supplier
  console.log("[Cloud Seed] Seeding initial notifications...");
  await setDoc(
    `users/${ownerUser.uid}/notifications/notif_quote_ys02`,
    {
      id: "notif_quote_ys02",
      recipientUid: ownerUser.uid,
      title: "وصلت تسعيرة المورد للطلب PO-2026-YS02",
      body: "ردت شركة التوريدات الوطنية للألمنيوم والملحقات بتسعير 3/3 صنف — الإجمالي: 1327.50 ر.س",
      type: "order_quoted",
      orderId: "ord_yasmin_quoted",
      projectId,
      workshopId,
      isRead: false,
      createdAt: now,
    },
    supplierUser.idToken
  );

  await setDoc(
    `users/${supplierUser.uid}/notifications/notif_sent_ys01`,
    {
      id: "notif_sent_ys01",
      recipientUid: supplierUser.uid,
      title: "طلب تسعير جديد من ورشة النور للألمنيوم والزجاج",
      body: "مشروع فيلا الياسمين — رقم الطلب PO-2026-YS01 (3 أصناف)",
      type: "order_sent",
      orderId: "ord_yasmin_sent",
      projectId,
      workshopId,
      isRead: false,
      createdAt: now,
    },
    ownerUser.idToken
  );

  console.log("\n✅ [Cloud Seed] Successfully seeded real Cloud Firebase (`meqyas-app-2026`)!");
  console.log("  • Workshop Owner Login : owner@meqyas.com    / Owner123");
  console.log("  • Supplier Login       : supplier@meqyas.com / Supplier123");
  console.log("  • System Admin Login   : admin@meqyas.com    / Admin123");
}

seedCloud().catch((err) => {
  console.error("[Cloud Seed] Error:", err);
  process.exit(1);
});

