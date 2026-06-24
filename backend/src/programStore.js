import { getFirestore } from "./firebase.js";

const PROGRAMS_COLLECTION = "trainerPrograms";
const ASSIGNMENTS_COLLECTION = "clientPrograms";

function programs() {
  return getFirestore().collection(PROGRAMS_COLLECTION);
}

function assignments() {
  return getFirestore().collection(ASSIGNMENTS_COLLECTION);
}

function normalizeString(value) {
  return String(value ?? "").trim();
}

// Coerces freeform client input into a clean workouts array so we never persist
// half-formed objects. Drops blank days and blank exercises.
function normalizeWorkouts(input) {
  if (!Array.isArray(input)) return [];
  return input
    .map((workout) => {
      const day = normalizeString(workout?.day);
      const title = normalizeString(workout?.title);
      const exercises = Array.isArray(workout?.exercises)
        ? workout.exercises
            .map((ex) => ({
              name: normalizeString(ex?.name),
              sets: normalizeString(ex?.sets),
              reps: normalizeString(ex?.reps),
              notes: normalizeString(ex?.notes),
            }))
            .filter((ex) => ex.name)
        : [];
      return { day, title, exercises };
    })
    .filter((workout) => workout.title || workout.day || workout.exercises.length > 0);
}

function normalizeProgramInput(input) {
  const weeksNum = Number(input?.weeks);
  return {
    title: normalizeString(input?.title),
    description: normalizeString(input?.description),
    weeks: Number.isFinite(weeksNum) && weeksNum > 0 ? Math.min(Math.round(weeksNum), 52) : 1,
    workouts: normalizeWorkouts(input?.workouts),
  };
}

export async function createProgram(trainerId, input) {
  const tid = normalizeString(trainerId);
  if (!tid) throw new Error("trainerId is required");

  const fields = normalizeProgramInput(input);
  if (!fields.title) throw new Error("A program title is required");

  const now = new Date().toISOString();
  const payload = { trainerId: tid, ...fields, createdAt: now, updatedAt: now };
  const ref = await programs().add(payload);
  return { id: ref.id, ...payload };
}

export async function listTrainerPrograms(trainerId) {
  const tid = normalizeString(trainerId);
  if (!tid) return [];
  const snap = await programs().where("trainerId", "==", tid).get();
  return snap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)));
}

export async function getProgram(id) {
  const docId = normalizeString(id);
  if (!docId) return null;
  const doc = await programs().doc(docId).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...doc.data() };
}

export async function updateProgram(id, input) {
  const docId = normalizeString(id);
  if (!docId) throw new Error("id is required");
  const ref = programs().doc(docId);
  const doc = await ref.get();
  if (!doc.exists) return null;

  const fields = normalizeProgramInput(input);
  if (!fields.title) throw new Error("A program title is required");

  await ref.update({ ...fields, updatedAt: new Date().toISOString() });
  const updated = await ref.get();
  return { id: updated.id, ...updated.data() };
}

export async function deleteProgram(id) {
  const docId = normalizeString(id);
  if (!docId) throw new Error("id is required");
  const ref = programs().doc(docId);
  const doc = await ref.get();
  if (!doc.exists) return false;
  await ref.delete();
  return true;
}

// Assigns a snapshot of the program to a client. The snapshot means later edits
// to the template don't silently mutate what a client is already following.
export async function assignProgram({ program, trainerName, clientUid, clientName }) {
  const now = new Date().toISOString();
  const payload = {
    programId: program.id,
    trainerId: program.trainerId,
    trainerName: normalizeString(trainerName),
    clientUid: normalizeString(clientUid),
    clientName: normalizeString(clientName),
    title: program.title,
    description: program.description,
    weeks: program.weeks,
    workouts: program.workouts,
    status: "active",
    assignedAt: now,
  };
  const ref = await assignments().add(payload);
  return { id: ref.id, ...payload };
}

export async function listClientPrograms(clientUid) {
  const uid = normalizeString(clientUid);
  if (!uid) return [];
  const snap = await assignments().where("clientUid", "==", uid).get();
  return snap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .sort((a, b) => String(b.assignedAt).localeCompare(String(a.assignedAt)));
}

export async function listProgramAssignments(programId) {
  const pid = normalizeString(programId);
  if (!pid) return [];
  const snap = await assignments().where("programId", "==", pid).get();
  return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

// Cleanup helper for the dev endpoint: remove a trainer's templates and all
// assignments tied to them or to a given client.
export async function deleteProgramsForTrainerOrClient({ trainerId, clientUid }) {
  const db = getFirestore();
  const tid = normalizeString(trainerId);
  const uid = normalizeString(clientUid);

  const tasks = [];
  if (tid) {
    const progSnap = await programs().where("trainerId", "==", tid).get();
    progSnap.docs.forEach((d) => tasks.push(d.ref.delete()));
  }
  const assignSnap = await assignments().get();
  assignSnap.docs
    .filter((d) => {
      const data = d.data();
      return (tid && data.trainerId === tid) || (uid && data.clientUid === uid);
    })
    .forEach((d) => tasks.push(d.ref.delete()));

  await Promise.all(tasks);
}
