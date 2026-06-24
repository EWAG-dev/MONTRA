import { getFirestore } from "./firebase.js";

const CREDITS_COLLECTION = "impactCredits";

// The fixed catalog of causes a client can direct a charitable credit toward.
// The id is the canonical key persisted on the credit; labels/descriptions are
// echoed back for display. Icons/colors are a client concern and live in the app.
export const IMPACT_CAUSES = [
  { id: "youth_sports", label: "Youth Sports", description: "Support programs and opportunities for young athletes to thrive." },
  { id: "fitness_access", label: "Fitness Access", description: "Help provide access to coaching and wellness for those in need." },
  { id: "mental_wellness", label: "Mental Wellness", description: "Support mental health resources, education, and community programs." },
  { id: "community_health", label: "Community Health", description: "Support local organizations working to improve health and quality of life." },
  { id: "survivor_support", label: "Survivor Support", description: "Support organizations helping survivors of domestic violence, abuse, and trauma rebuild their lives." },
];

// How a client can direct a credit. "donate"/"split" require a cause.
const ALLOCATION_TYPES = new Set(["donate", "coaching", "gift", "split"]);

// Default amount unlocked per booked session, in whole dollars.
export const DEFAULT_CREDIT_AMOUNT = Number(process.env.IMPACT_CREDIT_AMOUNT || 10);

// Optional launch baselines so the community totals don't read as $0 on day one.
// Default 0 — real activity is always added on top. The client can set these.
const BASELINE_AMOUNT = Number(process.env.IMPACT_BASELINE_AMOUNT || 0);
const BASELINE_CREDITS = Number(process.env.IMPACT_BASELINE_CREDITS || 0);
const BASELINE_LIVES = Number(process.env.IMPACT_BASELINE_LIVES || 0);

function credits() {
  return getFirestore().collection(CREDITS_COLLECTION);
}

function normalizeString(value) {
  return String(value ?? "").trim();
}

export function getCause(causeId) {
  const id = normalizeString(causeId);
  return IMPACT_CAUSES.find((c) => c.id === id) || null;
}

// Unlocks a credit for a freshly booked session. Idempotent per session so a
// retry on the booking path can't mint duplicate credits.
export async function createImpactCredit({ clientUid, sessionId, amount }) {
  const uid = normalizeString(clientUid);
  if (!uid) throw new Error("clientUid is required");
  const sid = normalizeString(sessionId);

  if (sid) {
    const existing = await credits().where("sessionId", "==", sid).limit(1).get();
    if (!existing.empty) {
      const doc = existing.docs[0];
      return { id: doc.id, ...doc.data() };
    }
  }

  const now = new Date().toISOString();
  const value = Number.isFinite(Number(amount)) && Number(amount) > 0 ? Number(amount) : DEFAULT_CREDIT_AMOUNT;
  const payload = {
    clientUid: uid,
    sessionId: sid,
    amount: value,
    status: "unlocked",
    allocation: null,
    createdAt: now,
    directedAt: null,
  };
  const ref = await credits().add(payload);
  return { id: ref.id, ...payload };
}

export async function listClientCredits(clientUid) {
  const uid = normalizeString(clientUid);
  if (!uid) return [];
  const snap = await credits().where("clientUid", "==", uid).get();
  return snap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
}

export async function getCredit(id) {
  const docId = normalizeString(id);
  if (!docId) return null;
  const doc = await credits().doc(docId).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...doc.data() };
}

// Directs an unlocked credit. Validates the allocation shape; returns the updated
// credit, or null if the credit doesn't exist. Throws on a bad allocation.
export async function directCredit(id, { type, causeId, giftEmail } = {}) {
  const docId = normalizeString(id);
  if (!docId) throw new Error("id is required");

  const allocType = normalizeString(type);
  if (!ALLOCATION_TYPES.has(allocType)) {
    throw new Error("type must be one of donate, coaching, gift, split");
  }

  const allocation = { type: allocType };

  if (allocType === "donate" || allocType === "split") {
    const cause = getCause(causeId);
    if (!cause) throw new Error("A valid causeId is required for this allocation");
    allocation.causeId = cause.id;
    allocation.causeLabel = cause.label;
  }
  if (allocType === "split") {
    allocation.splitCausePct = 50; // half to the cause, half toward the client's coaching
  }
  if (allocType === "gift") {
    const email = normalizeString(giftEmail);
    if (!email) throw new Error("A recipient email is required to gift a credit");
    allocation.giftEmail = email;
  }

  const ref = credits().doc(docId);
  const doc = await ref.get();
  if (!doc.exists) return null;

  const update = { status: "directed", allocation, directedAt: new Date().toISOString() };
  await ref.update(update);
  const updated = await ref.get();
  return { id: updated.id, ...updated.data() };
}

// Aggregate community impact for the "MONTRA Community Impact" panel. Computed
// from real directed credits, plus any configured launch baseline.
export async function getCommunityImpact() {
  const snap = await credits().where("status", "==", "directed").get();
  const directed = snap.docs.map((doc) => doc.data());

  const amountDirected = directed.reduce((sum, c) => sum + (Number(c.amount) || 0), 0);
  const creditsActivated = directed.length;
  const causesUsed = new Set(
    directed
      .map((c) => c.allocation?.causeId)
      .filter(Boolean)
  );

  return {
    amountDirected: amountDirected + BASELINE_AMOUNT,
    creditsActivated: creditsActivated + BASELINE_CREDITS,
    causesSupported: IMPACT_CAUSES.length,
    causesActive: causesUsed.size,
    // One credit, one life touched — a grounded proxy, plus any baseline.
    livesImpacted: creditsActivated + BASELINE_LIVES,
  };
}

// Cleanup helper for the dev endpoint: remove a client's credits.
export async function deleteCreditsForClient(clientUid) {
  const uid = normalizeString(clientUid);
  if (!uid) return;
  const snap = await credits().where("clientUid", "==", uid).get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
}
