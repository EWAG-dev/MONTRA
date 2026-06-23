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
    return { clientUid, ...DEFAULTS };
  }
  return { clientUid, ...DEFAULTS, ...doc.data() };
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
