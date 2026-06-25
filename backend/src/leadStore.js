import { getFirestore } from "./firebase.js";

// "Talk to a Human" callback requests captured by the MONTRA Team chat widget.
// This is the lightweight CRM until a real one is wired in (see HUMAN_TASKS).
const COLLECTION = "leads";

function leads() {
  return getFirestore().collection(COLLECTION);
}
function s(v) {
  return String(v ?? "").trim();
}

// Priority routing: which internal team owns a callback, based on the page the
// visitor was on when they asked for a call.
const TEAM_BY_SOURCE = {
  coach_profile: "sales",
  pricing: "sales",
  homepage: "sales",
  consultation: "sales",
  get_matched: "sales",
  how_it_works: "sales",
  services: "sales",
  existing_client: "support",
  coach_application: "recruiting",
  for_trainers: "recruiting",
};

export function routeTeam(source) {
  return TEAM_BY_SOURCE[s(source).toLowerCase()] || "sales";
}

export async function createLead(input) {
  const firstName = s(input.firstName);
  const phone = s(input.phone);
  if (!firstName) throw Object.assign(new Error("First name is required"), { code: "invalid" });
  if (!phone || phone.replace(/\D/g, "").length < 7) {
    throw Object.assign(new Error("A valid phone number is required"), { code: "invalid" });
  }

  const context = input.context && typeof input.context === "object" ? input.context : null;
  const payload = {
    firstName,
    phone,
    email: s(input.email),
    message: s(input.message).slice(0, 1000),
    source: s(input.source) || "unknown",
    sourcePath: s(input.sourcePath).slice(0, 300),
    context, // collected goal / trainingLocation / city / startTiming, when available
    team: routeTeam(input.source),
    status: "new",
    createdAt: new Date().toISOString(),
  };
  const ref = await leads().add(payload);
  return { id: ref.id, ...payload };
}

export async function listLeads({ limit = 200 } = {}) {
  const snap = await leads().get();
  return snap.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)))
    .slice(0, limit);
}

// Dev cleanup so E2E callback leads don't pollute the real list.
export async function deleteLeadsForPhone(phone) {
  const p = s(phone);
  if (!p) return;
  const snap = await leads().where("phone", "==", p).get();
  const batch = getFirestore().batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}
