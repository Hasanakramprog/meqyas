import * as admin from "firebase-admin";

// Connect to local emulators
process.env.FIREBASE_AUTH_EMULATOR_HOST = "localhost:9099";
process.env.FIRESTORE_EMULATOR_HOST = "localhost:8085";

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: "demo-meqyas",
  });
}

const db = admin.firestore();

async function seedRules() {
  console.log("[Seed Rules] Seeding Profile Systems, Calculation Rules & Optimizer Defaults...");

  const now = admin.firestore.FieldValue.serverTimestamp();
  const batch = db.batch();

  // 1. Profile System: system_2000_beaded
  const systemRef = db.collection("profileSystems").doc("system_2000_beaded");
  batch.set(systemRef, {
    id: "system_2000_beaded",
    nameArabic: "نظام 2000 بحاجب",
    active: true,
    createdAt: now,
    updatedAt: now,
  });

  // 2. Calculation Rules (Approved System 2000 Beaded Rules)
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
      notes: "عووارض منخل أفقية معتمدة على طول الكعب",
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
    const ruleRef = db.collection("calculationRules").doc(r.id);
    batch.set(ruleRef, {
      ...r,
      createdAt: now,
      updatedAt: now,
    });
  }

  // 3. Platform default Cutting Optimizer Config
  const configRef = db.collection("systemConfigs").doc("cuttingOptimizer");
  batch.set(configRef, {
    barLengthCm: 660.0,
    trimLossCm: 4.0,
    kerfPerCutCm: 0.5,
    minRemnantCm: 50.0,
    updatedBy: "system",
    createdAt: now,
    updatedAt: now,
  });

  await batch.commit();
  console.log(`[Seed Rules] Successfully seeded profile system, ${rules.length} rules, and cutting optimizer config!`);
}

seedRules().catch((err) => {
  console.error("[Seed Rules] Error:", err);
  process.exit(1);
});
