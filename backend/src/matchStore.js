import { getFirestore } from "./firebase.js";

const COLLECTION_NAME = "matchRequests";

function collection() {
  return getFirestore().collection(COLLECTION_NAME);
}

function normalizeString(value) {
  return String(value || "").trim();
}

function sanitizeClientProfile(profile = {}) {
  return {
    firstName: normalizeString(profile.firstName),
    goal: normalizeString(profile.goal),
    location: normalizeString(profile.location),
    coachPreference: normalizeString(profile.coachPreference),
    availability: Array.isArray(profile.availability)
      ? profile.availability.map((item) => normalizeString(item)).filter(Boolean)
      : [],
  };
}

export async function createMatchRequest(input) {
  const trainerId = normalizeString(input.trainerId);
  const clientUid = normalizeString(input.clientUid);
  const clientEmail = normalizeString(input.clientEmail);

  if (!trainerId) {
    throw new Error("trainerId is required");
  }

  if (!clientUid) {
    throw new Error("clientUid is required");
  }

  const payload = {
    trainerId,
    trainerName: normalizeString(input.trainerName),
    trainerStatus: normalizeString(input.trainerStatus || "approved"),
    clientUid,
    clientEmail,
    clientProfile: sanitizeClientProfile(input.clientProfile),
    status: "pending",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  const ref = await collection().add(payload);
  return {
    id: ref.id,
    ...payload,
  };
}

export async function listTrainerMatches(trainerId) {
  const snapshot = await collection().where("trainerId", "==", trainerId).get();
  return snapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .sort((left, right) => String(right.createdAt).localeCompare(String(left.createdAt)));
}

export async function listClientRequests(clientUid) {
  const snapshot = await collection().where("clientUid", "==", clientUid).get();
  return snapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .sort((left, right) => String(right.createdAt).localeCompare(String(left.createdAt)));
}
