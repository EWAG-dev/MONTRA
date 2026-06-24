import { getFirestore } from "./firebase.js";
import { getTrainer, setTrainerRating } from "./trainerStore.js";

const COLLECTION_NAME = "reviews";
const MAX_TEXT_LENGTH = 1000;

function reviews() {
  return getFirestore().collection(COLLECTION_NAME);
}

function normalizeString(value) {
  return String(value ?? "").trim();
}

function normalizeRating(value) {
  const n = Math.round(Number(value));
  if (!Number.isFinite(n) || n < 1 || n > 5) return null;
  return n;
}

function serialize(doc) {
  const data = doc.data();
  return {
    id: doc.id,
    trainerId: data.trainerId,
    sessionId: data.sessionId || null,
    clientUid: data.clientUid,
    clientName: data.clientName || "Verified Client",
    rating: typeof data.rating === "number" ? data.rating : 5,
    text: data.text || "",
    status: data.status || "visible",
    createdAt: data.createdAt || null,
  };
}

export async function getReviewForSession(sessionId) {
  const sid = normalizeString(sessionId);
  if (!sid) return null;
  const snap = await reviews().where("sessionId", "==", sid).limit(1).get();
  return snap.empty ? null : serialize(snap.docs[0]);
}

export async function listTrainerReviews(trainerId, { limit = 50 } = {}) {
  const id = normalizeString(trainerId);
  if (!id) return [];
  const snap = await reviews().where("trainerId", "==", id).get();
  return snap.docs
    .map(serialize)
    .filter((r) => r.status === "visible")
    .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)))
    .slice(0, limit);
}

// Recomputes the trainer's public rating + reviewCount from the actual visible
// reviews, so the number on every surface reflects real, verified feedback
// rather than the seeded default. No-op if the trainer has no reviews yet.
export async function recomputeTrainerRating(trainerId) {
  const id = normalizeString(trainerId);
  if (!id) return;
  const all = await listTrainerReviews(id, { limit: 1000 });
  if (!all.length) return;
  const sum = all.reduce((acc, r) => acc + r.rating, 0);
  const rating = Math.round((sum / all.length) * 10) / 10;
  await setTrainerRating(id, { rating, reviewCount: all.length });
}

/**
 * Creates a review for a completed session. One review per session.
 * Throws Error with a `.code` so the route can map it to a precise status.
 */
export async function createReview({ trainerId, sessionId, clientUid, clientName, rating, text }) {
  const tId = normalizeString(trainerId);
  const sId = normalizeString(sessionId);
  const uid = normalizeString(clientUid);
  const score = normalizeRating(rating);

  if (!tId) throw Object.assign(new Error("trainerId is required"), { code: "invalid" });
  if (!uid) throw Object.assign(new Error("clientUid is required"), { code: "invalid" });
  if (score === null) throw Object.assign(new Error("rating must be a whole number from 1 to 5"), { code: "invalid" });

  const trainer = await getTrainer(tId);
  if (!trainer) throw Object.assign(new Error("Coach not found"), { code: "not_found" });

  if (sId) {
    const existing = await getReviewForSession(sId);
    if (existing) throw Object.assign(new Error("This session has already been reviewed"), { code: "duplicate" });
  }

  const payload = {
    trainerId: tId,
    sessionId: sId || null,
    clientUid: uid,
    clientName: normalizeString(clientName) || "Verified Client",
    rating: score,
    text: normalizeString(text).slice(0, MAX_TEXT_LENGTH),
    status: "visible",
    createdAt: new Date().toISOString(),
  };

  const ref = await reviews().add(payload);
  await recomputeTrainerRating(tId);
  return { id: ref.id, ...payload };
}

export async function deleteReviewsForClient(clientUid) {
  const uid = normalizeString(clientUid);
  if (!uid) return;
  const snap = await reviews().where("clientUid", "==", uid).get();
  const trainerIds = new Set();
  const batch = getFirestore().batch();
  snap.docs.forEach((doc) => {
    trainerIds.add(doc.data().trainerId);
    batch.delete(doc.ref);
  });
  await batch.commit();
  // Re-derive each affected trainer's aggregate after removal.
  await Promise.all([...trainerIds].map((id) => recomputeTrainerRating(id).catch(() => {})));
}
