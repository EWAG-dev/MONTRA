import { getFirestore } from "./firebase.js";

const COLLECTION_NAME = "bookedSessions";

function collection() {
  return getFirestore().collection(COLLECTION_NAME);
}

function normalizeString(value) {
  return String(value || "").trim();
}

export async function createBookedSession(input) {
  const trainerId = normalizeString(input.trainerId);
  const clientUid = normalizeString(input.clientUid);
  const startTime = normalizeString(input.startTime);
  const durationMin = Number(input.durationMin) || 60;

  if (!trainerId) {
    throw new Error("trainerId is required");
  }

  if (!clientUid) {
    throw new Error("clientUid is required");
  }

  if (!startTime || Number.isNaN(Date.parse(startTime))) {
    throw new Error("A valid startTime is required");
  }

  const conflict = await collection()
    .where("trainerId", "==", trainerId)
    .where("startTime", "==", startTime)
    .where("status", "==", "scheduled")
    .get();

  if (!conflict.empty) {
    throw new Error("This time slot is already booked");
  }

  const payload = {
    trainerId,
    trainerName: normalizeString(input.trainerName),
    clientUid,
    clientEmail: normalizeString(input.clientEmail),
    clientName: normalizeString(input.clientName),
    startTime,
    durationMin,
    status: "scheduled",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  const ref = await collection().add(payload);
  return {
    id: ref.id,
    ...payload,
  };
}

export async function listClientSessions(clientUid) {
  const snapshot = await collection().where("clientUid", "==", clientUid).get();
  return snapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .sort((left, right) => String(left.startTime).localeCompare(String(right.startTime)));
}

export async function listTrainerSessions(trainerId) {
  const snapshot = await collection().where("trainerId", "==", trainerId).get();
  return snapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .sort((left, right) => String(left.startTime).localeCompare(String(right.startTime)));
}

export async function getBookedSession(id) {
  const docId = normalizeString(id);
  if (!docId) {
    return null;
  }

  const doc = await collection().doc(docId).get();
  if (!doc.exists) {
    return null;
  }

  return {
    id: doc.id,
    ...doc.data(),
  };
}

export async function cancelBookedSession(id) {
  const docId = normalizeString(id);
  if (!docId) {
    throw new Error("id is required");
  }

  const ref = collection().doc(docId);
  const doc = await ref.get();
  if (!doc.exists) {
    return null;
  }

  await ref.update({
    status: "cancelled",
    updatedAt: new Date().toISOString(),
  });

  const updated = await ref.get();
  return {
    id: updated.id,
    ...updated.data(),
  };
}
