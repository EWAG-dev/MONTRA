import { getFirestore } from "./firebase.js";

const COLLECTION_NAME = "trainers";

function trainersCollection() {
  return getFirestore().collection(COLLECTION_NAME);
}

function normalizeString(value) {
  return String(value || "").trim();
}

function normalizeList(value) {
  if (Array.isArray(value)) {
    return value.map((item) => normalizeString(item)).filter(Boolean);
  }

  return normalizeString(value)
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function toId(name) {
  return (
    normalizeString(name)
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "_")
      .replace(/^_+|_+$/g, "") || `trainer_${Date.now()}`
  );
}

function deriveInitials(name) {
  return normalizeString(name)
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() || "")
    .join("");
}

function normalizeStatus(value) {
  const normalized = normalizeString(value).toLowerCase();
  return ["pending", "approved", "rejected"].includes(normalized) ? normalized : "pending";
}

// SEO-friendly slug. "Luis Mendonca" + ["Boston, MA"] -> "luis-mendonca-boston".
function slugify(value) {
  return String(value || "")
    .normalize("NFKD")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}
function primaryCity(locations) {
  const loc = (Array.isArray(locations) && locations[0]) || "";
  return String(loc).split(",")[0].trim();
}
export function trainerSlug(name, locations) {
  const base = slugify(name);
  const city = slugify(primaryCity(locations));
  return city ? `${base}-${city}` : base;
}

function normalizeTrainerPayload(input, existingTrainer = null) {
  const name = normalizeString(input.name || existingTrainer?.name);
  const bio = normalizeString(input.bio || existingTrainer?.bio);
  const certification = normalizeString(input.certification || existingTrainer?.certification);
  const gender = normalizeString(input.gender || existingTrainer?.gender || "Any");
  const accentHex = normalizeString(input.accentHex || existingTrainer?.accentHex || "#FF6820");
  const specialties = normalizeList(input.specialties ?? existingTrainer?.specialties ?? []);
  const locations = normalizeList(input.locations ?? existingTrainer?.locations ?? []);
  const availabilityDays = normalizeList(input.availabilityDays ?? existingTrainer?.availabilityDays ?? []);
  const experienceLevels = normalizeList(input.experienceLevels ?? existingTrainer?.experienceLevels ?? []);
  const workingHours = input.workingHours ?? existingTrainer?.workingHours ?? null;
  const photoDataUrl = normalizeString(input.photoDataUrl || existingTrainer?.photoDataUrl);
  const experienceYears = Number(input.experienceYears ?? existingTrainer?.experienceYears ?? 0);
  const rating = Number(input.rating ?? existingTrainer?.rating ?? 4.9);
  const reviewCount = Number(input.reviewCount ?? existingTrainer?.reviewCount ?? 0);
  const isActive = input.isActive ?? existingTrainer?.isActive ?? true;
  const status = normalizeStatus(input.status || existingTrainer?.status || "pending");
  const email = normalizeString(input.email || existingTrainer?.email);
  const accountUid = normalizeString(input.accountUid || existingTrainer?.accountUid);
  const phone = normalizeString(input.phone || existingTrainer?.phone);
  const cprCertification = normalizeString(input.cprCertification ?? existingTrainer?.cprCertification);
  const hasInsurance = Boolean(input.hasInsurance ?? existingTrainer?.hasInsurance ?? false);
  const introVideoUrl = normalizeString(input.introVideoUrl ?? existingTrainer?.introVideoUrl);
  const backgroundCheckConsent = Boolean(input.backgroundCheckConsent ?? existingTrainer?.backgroundCheckConsent ?? false);
  const policyAgreement = Boolean(input.policyAgreement ?? existingTrainer?.policyAgreement ?? false);
  // Real, admin-confirmed vetting outcomes (distinct from the applicant's consent
  // above). Deliberately ignore `input` here so a trainer can't self-claim these
  // via apply/provision — they're only settable through setTrainerVerification
  // (admin-gated). We carry the existing value forward on any other profile edit.
  const idVerified = Boolean(existingTrainer?.idVerified ?? false);
  const backgroundCheckCleared = Boolean(existingTrainer?.backgroundCheckCleared ?? false);
  const montraCertified = Boolean(existingTrainer?.montraCertified ?? false);
  const education = normalizeString(input.education ?? existingTrainer?.education);
  const references = normalizeList(input.references ?? existingTrainer?.references ?? []);

  if (!name) {
    throw new Error("Trainer name is required.");
  }

  if (!bio) {
    throw new Error("Trainer bio is required.");
  }

  if (!certification) {
    throw new Error("Trainer certification is required.");
  }

  return {
    id: normalizeString(input.id || existingTrainer?.id) || toId(name),
    name,
    initials: normalizeString(input.initials || existingTrainer?.initials) || deriveInitials(name),
    certification,
    bio,
    specialties,
    locations,
    gender,
    accentHex,
    availabilityDays,
    experienceLevels,
    workingHours,
    photoDataUrl,
    experienceYears: Number.isFinite(experienceYears) ? experienceYears : 0,
    rating: Number.isFinite(rating) ? rating : 4.9,
    reviewCount: Number.isFinite(reviewCount) ? reviewCount : 0,
    isActive: Boolean(isActive),
    status,
    email,
    accountUid,
    phone,
    cprCertification,
    hasInsurance,
    introVideoUrl,
    backgroundCheckConsent,
    policyAgreement,
    idVerified,
    backgroundCheckCleared,
    montraCertified,
    education,
    references,
  };
}

function serializeTrainer(doc) {
  const data = doc.data();
  return {
    id: doc.id,
    name: data.name || "",
    initials: data.initials || deriveInitials(data.name || ""),
    certification: data.certification || "",
    bio: data.bio || "",
    specialties: Array.isArray(data.specialties) ? data.specialties : [],
    locations: Array.isArray(data.locations) ? data.locations : [],
    gender: data.gender || "Any",
    accentHex: data.accentHex || "#FF6820",
    availabilityDays: Array.isArray(data.availabilityDays) ? data.availabilityDays : [],
    experienceLevels: Array.isArray(data.experienceLevels) ? data.experienceLevels : [],
    workingHours: data.workingHours || null,
    photoDataUrl: data.photoDataUrl || "",
    experienceYears: typeof data.experienceYears === "number" ? data.experienceYears : 0,
    rating: typeof data.rating === "number" ? data.rating : 4.9,
    reviewCount: typeof data.reviewCount === "number" ? data.reviewCount : 0,
    isActive: data.isActive !== false,
    status: normalizeStatus(data.status),
    email: data.email || "",
    accountUid: data.accountUid || "",
    phone: data.phone || "",
    cprCertification: data.cprCertification || "",
    hasInsurance: data.hasInsurance === true,
    introVideoUrl: data.introVideoUrl || "",
    backgroundCheckConsent: data.backgroundCheckConsent === true,
    policyAgreement: data.policyAgreement === true,
    idVerified: data.idVerified === true,
    backgroundCheckCleared: data.backgroundCheckCleared === true,
    montraCertified: data.montraCertified === true,
    education: data.education || "",
    references: Array.isArray(data.references) ? data.references : [],
    orientationCompleted: data.orientationCompleted === true,
    orientationCompletedAt: data.orientationCompletedAt || null,
    agreementSigned: data.agreementSigned === true,
    agreementSignedAt: data.agreementSignedAt || null,
    slug: trainerSlug(data.name, data.locations),
    createdAt: data.createdAt || null,
    updatedAt: data.updatedAt || null,
  };
}

export function evaluateTrainerApplication(input) {
  const trainer = normalizeTrainerPayload(input, input);
  let score = 0;
  const strengths = [];
  const concerns = [];
  const hardFails = []; // automatic disqualifiers per MONTRA Eligibility Policy

  // ── HARD REQUIREMENTS (auto-hold if missing) ────────────────────────────────

  // Fitness certification — required by policy
  const recognizedCerts = ["nasm", "ace", "nsca", "issa", "acsm", "nesta", "afaa", "nafc", "nfpt", "ncsf"];
  if (trainer.certification) {
    const certLower = trainer.certification.toLowerCase();
    const isRecognized = recognizedCerts.some((c) => certLower.includes(c));
    score += isRecognized ? 25 : 15;
    strengths.push(isRecognized ? `Recognized certification: ${trainer.certification}` : `Certification on file: ${trainer.certification}`);
    if (!isRecognized) concerns.push("Certification not from a widely recognized body (NASM, ACE, NSCA, ISSA, ACSM) — admin should verify");
  } else {
    hardFails.push("No fitness certification — required by MONTRA Eligibility Policy before activation");
  }

  // CPR / AED — required by policy
  if (trainer.cprCertification) {
    score += 10;
    strengths.push(`CPR/AED certified: ${trainer.cprCertification}`);
  } else {
    hardFails.push("No CPR/AED certification — required by MONTRA Eligibility Policy");
  }

  // Policy agreement — required before submission
  if (!trainer.policyAgreement) {
    hardFails.push("Trainer has not agreed to the MONTRA Coach Eligibility & Acceptance Policy");
  }

  // Background check consent — required before receiving leads
  if (trainer.backgroundCheckConsent) {
    strengths.push("Background check consent given");
  } else {
    concerns.push("Background check consent not confirmed — required before receiving client leads");
  }

  // ── SCORED PROFILE REQUIREMENTS ─────────────────────────────────────────────

  // Professional liability insurance (10 pts)
  if (trainer.hasInsurance) {
    score += 10;
    strengths.push("Professional liability insurance confirmed");
  } else {
    concerns.push("Professional liability insurance not confirmed — required by MONTRA Eligibility Policy");
  }

  // Coach introduction video (10 pts)
  if (trainer.introVideoUrl) {
    score += 10;
    strengths.push("Coach introduction video provided");
  } else {
    concerns.push("No introduction video — required for full profile activation per MONTRA Eligibility Policy");
  }

  // Profile photo (10 pts)
  if (trainer.photoDataUrl) {
    score += 10;
    strengths.push("Profile photo uploaded");
  } else {
    concerns.push("No profile photo — clients are much less likely to select a trainer without one");
  }

  // Bio quality (up to 15 pts)
  if (trainer.bio.length >= 120) {
    score += 15;
    strengths.push("Detailed, compelling bio");
  } else if (trainer.bio.length >= 60) {
    score += 8;
    concerns.push("Bio is short — aim for 120+ characters describing your style and results");
  } else {
    concerns.push("Bio is missing or too brief — this is what clients read first");
  }

  // Specialties (18 pts)
  if (trainer.specialties.length >= 3) {
    score += 18;
    strengths.push(`${trainer.specialties.length} specialties listed`);
  } else if (trainer.specialties.length >= 2) {
    score += 12;
    strengths.push(`${trainer.specialties.length} specialties listed`);
    concerns.push("Add a 3rd specialty to improve match rate");
  } else if (trainer.specialties.length === 1) {
    score += 5;
    concerns.push("Only 1 specialty — add more to appear in more client matches");
  } else {
    concerns.push("No specialties selected — required for client matching");
  }

  // Service locations (12 pts)
  if (trainer.locations.length >= 2) {
    score += 12;
    strengths.push(`${trainer.locations.length} service locations`);
  } else if (trainer.locations.length === 1) {
    score += 7;
    strengths.push("Service location listed");
    concerns.push("Add a second service location to reach more clients");
  } else {
    concerns.push("No service locations — clients can't match without a location");
  }

  // Availability days (10 pts)
  if (trainer.availabilityDays.length >= 4) {
    score += 10;
    strengths.push(`Available ${trainer.availabilityDays.length} days/week`);
  } else if (trainer.availabilityDays.length >= 2) {
    score += 5;
    strengths.push("Availability days set");
    concerns.push("Trainers with 4+ available days get significantly more matches");
  } else {
    concerns.push("Set your weekly availability so clients know when you're bookable");
  }

  // Working hours (5 pts)
  if (trainer.workingHours?.start && trainer.workingHours?.end) {
    score += 5;
    strengths.push(`Working hours: ${trainer.workingHours.start} – ${trainer.workingHours.end}`);
  } else {
    concerns.push("Set your working hours start and end times");
  }

  // Experience levels (5 pts)
  if (trainer.experienceLevels?.length >= 1) {
    score += 5;
    strengths.push(`Trains ${trainer.experienceLevels.join(", ")} clients`);
  } else {
    concerns.push("Select which experience levels you train (Beginner / Intermediate / Advanced)");
  }

  // Contact info (5 pts)
  if (trainer.email) score += 3;
  else concerns.push("Email missing");
  if (trainer.phone) score += 2;

  // Social proof — only if meaningful (up to 10 pts)
  if (trainer.rating >= 4.8 && trainer.reviewCount >= 10) {
    score += 10;
    strengths.push(`${trainer.rating}★ across ${trainer.reviewCount} reviews`);
  } else if (trainer.rating >= 4.5 && trainer.reviewCount >= 5) {
    score += 5;
    strengths.push(`${trainer.rating}★ across ${trainer.reviewCount} reviews`);
  }

  let recommendation;
  if (hardFails.length > 0) {
    recommendation = "hold";
  } else if (score >= 70) {
    recommendation = "strong_yes";
  } else if (score >= 50) {
    recommendation = "review";
  } else {
    recommendation = "hold";
  }

  const allConcerns = [...hardFails, ...concerns];

  return {
    score,
    recommendation,
    strengths,
    concerns: allConcerns,
    hardFails,
    summary:
      hardFails.length > 0
        ? `Auto-hold: ${hardFails.length} required eligibility item(s) missing. See concerns for details.`
        : recommendation === "strong_yes"
          ? "Strong applicant — meets all key criteria for approval."
          : recommendation === "review"
            ? "Promising applicant. A quick human review of the missing details is recommended."
            : "Profile needs more work before approval. See concerns for guidance.",
  };
}

function scoreTrainerMatch(trainer, filters) {
  let score = 0;
  const reasons = [];

  if (filters.goal && trainer.specialties.includes(filters.goal)) {
    score += 35;
    reasons.push(`Goal match: ${filters.goal}`);
  }

  if (filters.location && trainer.locations.includes(filters.location)) {
    score += 25;
    reasons.push(`Location match: ${filters.location}`);
  }

  if (filters.gender) {
    if (filters.gender === "Male coach" && trainer.gender === "Male") {
      score += 10;
      reasons.push("Matches gender preference");
    } else if (filters.gender === "Female coach" && trainer.gender === "Female") {
      score += 10;
      reasons.push("Matches gender preference");
    } else if (filters.gender === "No preference") {
      score += 4;
    }
  }

  if (Array.isArray(filters.preferredDays) && filters.preferredDays.length > 0) {
    const overlap = filters.preferredDays.filter((day) => trainer.availabilityDays.includes(day));
    if (overlap.length > 0) {
      score += overlap.length * 4;
      reasons.push(`Availability overlap: ${overlap.join(", ")}`);
    }
  }

  score += Math.min(Math.round((trainer.rating || 0) * 2), 10);
  score += Math.min(Math.floor((trainer.reviewCount || 0) / 10), 5);

  return { score, reasons };
}

export async function listTrainers({ includeInactive = false, statuses = [] } = {}) {
  const snapshot = await trainersCollection().get();
  const trainers = snapshot.docs.map(serializeTrainer);
  return trainers
    .filter((trainer) => includeInactive || trainer.isActive)
    .filter((trainer) => statuses.length === 0 || statuses.includes(trainer.status))
    .sort((left, right) => left.name.localeCompare(right.name));
}

// Firestore rejects document IDs that are empty, contain "/", are "." / "..", or
// match the reserved __.*__ pattern — calling .doc(id).get() with one throws. Treat
// any such id (and any transient lookup error) as "not found" so a bad path param
// returns 404 instead of crashing the process via an unhandled rejection.
function isValidDocId(id) {
  const s = String(id ?? "");
  if (!s || s.length > 1500) return false;
  if (s.includes("/") || s === "." || s === "..") return false;
  if (/^__.*__$/.test(s)) return false;
  return true;
}

export async function getTrainer(id) {
  if (!isValidDocId(id)) return null;
  try {
    const snapshot = await trainersCollection().doc(id).get();
    return snapshot.exists ? serializeTrainer(snapshot) : null;
  } catch (err) {
    console.error(`getTrainer(${id}) failed:`, err.message);
    return null;
  }
}

export async function getTrainerByAccountUid(accountUid) {
  const trainers = await listTrainers({ includeInactive: true });
  return trainers.find((trainer) => trainer.accountUid === accountUid) || null;
}

// Resolves a /coaches/<slug> URL to a trainer. First match wins on collisions
// (rare; same name + city). Returns the trainer regardless of status — the public
// profile page is responsible for only rendering approved/active coaches.
export async function getTrainerBySlug(slug) {
  const target = slugify(slug);
  if (!target) return null;
  const trainers = await listTrainers({ includeInactive: true });
  return trainers.find((trainer) => trainer.slug === target) || null;
}

export async function createTrainer(input) {
  const trainer = normalizeTrainerPayload(input);
  const ref = trainersCollection().doc(trainer.id);
  const existing = await ref.get();

  if (existing.exists) {
    throw new Error("A trainer with that id already exists.");
  }

  const timestamp = new Date().toISOString();
  await ref.set({
    ...trainer,
    createdAt: timestamp,
    updatedAt: timestamp,
  });

  return getTrainer(trainer.id);
}

export async function updateTrainer(id, input) {
  const existing = await getTrainer(id);
  if (!existing) {
    return null;
  }

  const trainer = normalizeTrainerPayload({ ...input, id }, existing);
  await trainersCollection().doc(id).set(
    {
      ...trainer,
      createdAt: existing.createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    },
    { merge: true }
  );

  return getTrainer(id);
}

// Writes just the review aggregate fields, bypassing full-profile validation so
// a coach's rating can update even if their profile predates required fields.
export async function setTrainerRating(id, { rating, reviewCount }) {
  const existing = await getTrainer(id);
  if (!existing) return null;
  await trainersCollection().doc(id).set(
    {
      rating: Number.isFinite(Number(rating)) ? Number(rating) : existing.rating,
      reviewCount: Number.isFinite(Number(reviewCount)) ? Number(reviewCount) : existing.reviewCount,
      updatedAt: new Date().toISOString(),
    },
    { merge: true }
  );
  return getTrainer(id);
}

// Sets admin-confirmed vetting flags via a direct merge write (no full-profile
// re-validation). Only the boolean flags passed in are touched.
const VERIFICATION_FIELDS = ["idVerified", "backgroundCheckCleared", "montraCertified"];
export async function setTrainerVerification(id, flags) {
  const existing = await getTrainer(id);
  if (!existing) return null;
  const updates = {};
  for (const key of VERIFICATION_FIELDS) {
    if (typeof flags?.[key] === "boolean") updates[key] = flags[key];
  }
  if (Object.keys(updates).length === 0) return existing;
  updates.updatedAt = new Date().toISOString();
  await trainersCollection().doc(id).set(updates, { merge: true });
  return getTrainer(id);
}

export async function deleteTrainer(id) {
  const existing = await getTrainer(id);
  if (!existing) {
    return false;
  }

  await trainersCollection().doc(id).delete();
  return true;
}

export async function upsertTrainerForAccount(accountUid, input) {
  const existing = await getTrainerByAccountUid(accountUid);

  if (existing) {
    return updateTrainer(existing.id, {
      ...input,
      accountUid,
      email: input.email || existing.email,
      status: existing.status || "pending",
    });
  }

  return createTrainer({
    ...input,
    accountUid,
    status: "pending",
    isActive: true,
  });
}

export async function approveTrainer(id) {
  return updateTrainer(id, { status: "approved", isActive: true });
}

export async function markOrientationCompleted(accountUid) {
  const trainer = await getTrainerByAccountUid(accountUid);
  if (!trainer) {
    return null;
  }

  await trainersCollection().doc(trainer.id).set(
    {
      orientationCompleted: true,
      orientationCompletedAt: new Date().toISOString(),
    },
    { merge: true }
  );

  return getTrainer(trainer.id);
}

export async function markAgreementSigned(accountUid) {
  const trainer = await getTrainerByAccountUid(accountUid);
  if (!trainer) return null;
  await trainersCollection().doc(trainer.id).set(
    { agreementSigned: true, agreementSignedAt: new Date().toISOString() },
    { merge: true }
  );
  return getTrainer(trainer.id);
}

export async function rejectTrainer(id) {
  return updateTrainer(id, { status: "rejected", isActive: false });
}

export async function matchTrainers(filters) {
  const trainers = await listTrainers({ statuses: ["approved"] });
  const preferredDays = normalizeList(filters.preferredDays || []);

  return trainers
    .map((trainer) => {
      const result = scoreTrainerMatch(trainer, {
        goal: normalizeString(filters.goal),
        location: normalizeString(filters.location),
        gender: normalizeString(filters.gender),
        preferredDays,
      });

      return {
        ...trainer,
        matchScore: result.score,
        matchReasons: result.reasons,
      };
    })
    .filter((trainer) => trainer.matchScore > 0)
    .sort((left, right) => right.matchScore - left.matchScore);
}
