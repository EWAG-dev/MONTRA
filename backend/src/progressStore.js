import { getFirestore } from "./firebase.js";

const COLLECTION_NAME = "clientProgress";

function collection() {
  return getFirestore().collection(COLLECTION_NAME);
}

function normalizeString(value) {
  return String(value ?? "").trim();
}

const DEFAULTS = {
  currentWeight: "",
  startWeight: "",
  weightLossGoal: "",
  selectedGoals: [],
  strengthWeeklyTarget: "5",
  enduranceMinutesTarget: "180",
  mobilitySessionsTarget: "3",
  performanceMonthlyTarget: "12",
  consistencyPercentTarget: "90",
};

export async function getClientProgress(clientUid) {
  const doc = await collection().doc(clientUid).get();
  if (!doc.exists) {
    return { clientUid, ...DEFAULTS, weightLog: [] };
  }
  const data = doc.data();
  return { clientUid, ...DEFAULTS, weightLog: [], ...data };
}

function sortWeightLog(log) {
  return [...log].sort((a, b) => String(a.date).localeCompare(String(b.date)));
}

export async function getWeightHistory(clientUid) {
  const doc = await collection().doc(clientUid).get();
  const log = doc.exists && Array.isArray(doc.data().weightLog) ? doc.data().weightLog : [];
  return sortWeightLog(log);
}

// Appends a weight measurement, keeps the log sorted by date, and syncs the
// derived currentWeight (latest) / startWeight (first) used by Body Stats.
export async function addWeightEntry(clientUid, { weight, date }) {
  const weightNum = Number(weight);
  if (!Number.isFinite(weightNum) || weightNum <= 0) {
    throw new Error("A valid positive weight is required");
  }

  const when = normalizeString(date) || new Date().toISOString();
  if (Number.isNaN(Date.parse(when))) {
    throw new Error("A valid date is required");
  }

  const ref = collection().doc(clientUid);
  const doc = await ref.get();
  const existing = doc.exists && Array.isArray(doc.data().weightLog) ? doc.data().weightLog : [];

  const entry = { date: when, weight: weightNum };
  const log = sortWeightLog([...existing, entry]);

  // Once a client is logging measurements, the log is authoritative for the
  // Body Stats summary: startWeight = earliest entry, currentWeight = latest.
  const payload = {
    weightLog: log,
    currentWeight: String(log[log.length - 1].weight),
    startWeight: String(log[0].weight),
    updatedAt: new Date().toISOString(),
  };

  await ref.set(payload, { merge: true });
  return { clientUid, ...payload };
}

export async function saveClientProgress(clientUid, input) {
  const payload = {
    currentWeight: normalizeString(input.currentWeight),
    startWeight: normalizeString(input.startWeight),
    weightLossGoal: normalizeString(input.weightLossGoal),
    selectedGoals: Array.isArray(input.selectedGoals)
      ? input.selectedGoals.map(normalizeString).filter(Boolean)
      : [],
    strengthWeeklyTarget: normalizeString(input.strengthWeeklyTarget) || DEFAULTS.strengthWeeklyTarget,
    enduranceMinutesTarget: normalizeString(input.enduranceMinutesTarget) || DEFAULTS.enduranceMinutesTarget,
    mobilitySessionsTarget: normalizeString(input.mobilitySessionsTarget) || DEFAULTS.mobilitySessionsTarget,
    performanceMonthlyTarget: normalizeString(input.performanceMonthlyTarget) || DEFAULTS.performanceMonthlyTarget,
    consistencyPercentTarget: normalizeString(input.consistencyPercentTarget) || DEFAULTS.consistencyPercentTarget,
    updatedAt: new Date().toISOString(),
  };

  await collection().doc(clientUid).set(payload, { merge: true });
  return { clientUid, ...payload };
}
