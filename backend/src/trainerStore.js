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

function normalizeTrainerPayload(input, existingTrainer = null) {
  const name = normalizeString(input.name || existingTrainer?.name);
  const bio = normalizeString(input.bio || existingTrainer?.bio);
  const certification = normalizeString(input.certification || existingTrainer?.certification);
  const gender = normalizeString(input.gender || existingTrainer?.gender || "Any");
  const accentHex = normalizeString(input.accentHex || existingTrainer?.accentHex || "#FF6820");
  const specialties = normalizeList(input.specialties ?? existingTrainer?.specialties ?? []);
  const locations = normalizeList(input.locations ?? existingTrainer?.locations ?? []);
  const availabilityDays = normalizeList(input.availabilityDays ?? existingTrainer?.availabilityDays ?? []);
  const experienceYears = Number(input.experienceYears ?? existingTrainer?.experienceYears ?? 0);
  const rating = Number(input.rating ?? existingTrainer?.rating ?? 4.9);
  const reviewCount = Number(input.reviewCount ?? existingTrainer?.reviewCount ?? 0);
  const isActive = input.isActive ?? existingTrainer?.isActive ?? true;
  const status = normalizeStatus(input.status || existingTrainer?.status || "pending");
  const email = normalizeString(input.email || existingTrainer?.email);
  const accountUid = normalizeString(input.accountUid || existingTrainer?.accountUid);
  const phone = normalizeString(input.phone || existingTrainer?.phone);

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
    experienceYears: Number.isFinite(experienceYears) ? experienceYears : 0,
    rating: Number.isFinite(rating) ? rating : 4.9,
    reviewCount: Number.isFinite(reviewCount) ? reviewCount : 0,
    isActive: Boolean(isActive),
    status,
    email,
    accountUid,
    phone,
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
    experienceYears: typeof data.experienceYears === "number" ? data.experienceYears : 0,
    rating: typeof data.rating === "number" ? data.rating : 4.9,
    reviewCount: typeof data.reviewCount === "number" ? data.reviewCount : 0,
    isActive: data.isActive !== false,
    status: normalizeStatus(data.status),
    email: data.email || "",
    accountUid: data.accountUid || "",
    phone: data.phone || "",
    createdAt: data.createdAt || null,
    updatedAt: data.updatedAt || null,
  };
}

export function evaluateTrainerApplication(input) {
  const trainer = normalizeTrainerPayload(input, input);
  let score = 0;
  const strengths = [];
  const concerns = [];

  if (trainer.certification) {
    score += 25;
    strengths.push(`Certified: ${trainer.certification}`);
  } else {
    concerns.push("Missing certification");
  }

  if (trainer.specialties.length >= 2) {
    score += 18;
    strengths.push(`${trainer.specialties.length} specialties listed`);
  } else {
    concerns.push("Add at least 2 specialties");
  }

  if (trainer.locations.length >= 1) {
    score += 12;
    strengths.push(`${trainer.locations.length} service location${trainer.locations.length > 1 ? "s" : ""}`);
  } else {
    concerns.push("Add at least 1 service location");
  }

  if (trainer.availabilityDays.length >= 3) {
    score += 10;
    strengths.push("Availability covers 3+ days");
  } else {
    concerns.push("Add more availability days");
  }

  if (trainer.bio.length >= 80) {
    score += 12;
    strengths.push("Detailed bio provided");
  } else {
    concerns.push("Bio should explain training style in more detail");
  }

  if (trainer.experienceYears >= 3) {
    score += 12;
    strengths.push(`${trainer.experienceYears} years experience`);
  } else if (trainer.experienceYears > 0) {
    score += 6;
    strengths.push(`${trainer.experienceYears} years experience`);
  } else {
    concerns.push("Experience years missing");
  }

  if (trainer.email) {
    score += 5;
  } else {
    concerns.push("Email missing");
  }

  if (trainer.phone) {
    score += 3;
  }

  if (trainer.rating >= 4.8 && trainer.reviewCount >= 10) {
    score += 8;
    strengths.push("Strong social proof");
  }

  let recommendation = "hold";
  if (score >= 70) {
    recommendation = "strong_yes";
  } else if (score >= 50) {
    recommendation = "review";
  }

  return {
    score,
    recommendation,
    strengths,
    concerns,
    summary:
      recommendation === "strong_yes"
        ? "Strong trainer applicant with enough signal to approve quickly."
        : recommendation === "review"
          ? "Promising applicant, but a human review should check the missing details."
          : "Not ready for approval yet. The profile needs more proof and coverage.",
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

export async function getTrainer(id) {
  const snapshot = await trainersCollection().doc(id).get();
  return snapshot.exists ? serializeTrainer(snapshot) : null;
}

export async function getTrainerByAccountUid(accountUid) {
  const trainers = await listTrainers({ includeInactive: true });
  return trainers.find((trainer) => trainer.accountUid === accountUid) || null;
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
