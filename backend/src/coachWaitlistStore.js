import { getFirestore } from "./firebase.js";

// Stores email addresses of people waiting for coaches in specific locations.
// When a coach becomes available in a location, we notify all waitlisted emails.
const COLLECTION = "coach_waitlist";

function waitlist() {
  return getFirestore().collection(COLLECTION);
}

function s(v) {
  return String(v ?? "").trim();
}

export async function addToWaitlist(email, location) {
  const emailTrimmed = s(email).toLowerCase();
  const locationTrimmed = s(location);

  if (!emailTrimmed || !emailTrimmed.includes("@")) {
    throw Object.assign(new Error("Valid email address required"), { code: "invalid" });
  }
  if (!locationTrimmed) {
    throw Object.assign(new Error("Location is required"), { code: "invalid" });
  }

  // Create a document with email+location as a composite key to prevent duplicates
  const docId = `${emailTrimmed}:${locationTrimmed}`;
  
  const payload = {
    email: emailTrimmed,
    location: locationTrimmed,
    signedUpAt: new Date().toISOString(),
    notified: false, // Set to true when we send the notification
  };

  await waitlist().doc(docId).set(payload, { merge: true });
  return payload;
}

export async function getWaitlistForLocation(location) {
  const locationTrimmed = s(location);
  if (!locationTrimmed) return [];

  const snapshot = await waitlist()
    .where("location", "==", locationTrimmed)
    .where("notified", "==", false)
    .get();

  return snapshot.docs.map((doc) => doc.data());
}

export async function markNotified(email, location) {
  const emailTrimmed = s(email).toLowerCase();
  const locationTrimmed = s(location);
  const docId = `${emailTrimmed}:${locationTrimmed}`;

  await waitlist().doc(docId).update({ notified: true, notifiedAt: new Date().toISOString() });
}
