import { getFirestore } from "./firebase.js";
import { ensureConversationThread, conversationIdFor } from "./chatStore.js";

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
  const clientName = normalizeString(input.clientName || input.clientProfile?.firstName);

  if (!trainerId) {
    throw new Error("trainerId is required");
  }

  if (!clientUid) {
    throw new Error("clientUid is required");
  }

  // Idempotency: return the existing request if one already exists for this
  // client→trainer pair with a non-declined status, rather than creating a
  // duplicate. Allow a new request if the previous one was declined (client
  // may want to re-apply after updating their profile).
  const existing = await collection()
    .where("trainerId", "==", trainerId)
    .where("clientUid", "==", clientUid)
    .get();

  const active = existing.docs.find((doc) => doc.data().status !== "declined");
  if (active) {
    return { id: active.id, ...active.data() };
  }

  const payload = {
    conversationId: conversationIdFor({ trainerId, clientUid }),
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

  await ensureConversationThread({
    trainerId,
    clientUid,
    trainerName: payload.trainerName,
    clientEmail,
    clientName,
  });

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

export async function getMatchRequest(requestId) {
  const id = normalizeString(requestId);
  if (!id) {
    return null;
  }

  const doc = await collection().doc(id).get();
  if (!doc.exists) {
    return null;
  }

  return {
    id: doc.id,
    ...doc.data(),
  };
}

export async function updateMatchRequestStatus(requestId, status) {
  const id = normalizeString(requestId);
  const normalizedStatus = normalizeString(status).toLowerCase();
  if (!id) {
    throw new Error("requestId is required");
  }

  if (!["pending", "accepted", "declined"].includes(normalizedStatus)) {
    throw new Error("Invalid match request status");
  }

  const ref = collection().doc(id);
  const doc = await ref.get();
  if (!doc.exists) {
    return null;
  }

  await ref.update({
    status: normalizedStatus,
    updatedAt: new Date().toISOString(),
  });

  const updated = await ref.get();
  return {
    id: updated.id,
    ...updated.data(),
  };
}
