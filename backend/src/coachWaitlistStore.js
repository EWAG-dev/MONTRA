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

function normalizeLocationToken(value) {
  return s(value).toLowerCase().replace(/[^a-z0-9]/g, "");
}

export async function addToWaitlist(email, location) {
  const emailTrimmed = s(email).toLowerCase();
  const locationTrimmed = s(location);
  const normalizedLocation = normalizeLocationToken(locationTrimmed);

  if (!emailTrimmed || !emailTrimmed.includes("@")) {
    throw Object.assign(new Error("Valid email address required"), { code: "invalid" });
  }
  if (!locationTrimmed) {
    throw Object.assign(new Error("Location is required"), { code: "invalid" });
  }

  // Composite key on normalized location dedupes variants like "Boston, MA" vs "boston ma".
  const docId = `${emailTrimmed}:${normalizedLocation}`;
  
  const payload = {
    email: emailTrimmed,
    location: locationTrimmed,
    normalizedLocation,
    signedUpAt: new Date().toISOString(),
    notified: false, // Set to true when we send the notification
  };

  await waitlist().doc(docId).set(payload, { merge: true });
  return payload;
}

export async function getWaitlistForLocation(location) {
  const locationTrimmed = s(location);
  const normalizedLocation = normalizeLocationToken(locationTrimmed);
  if (!locationTrimmed) return [];

  const [normalizedSnapshot, legacySnapshot] = await Promise.all([
    waitlist()
      .where("normalizedLocation", "==", normalizedLocation)
      .where("notified", "==", false)
      .get(),
    // Backward compatibility for records written before normalizedLocation existed.
    waitlist()
      .where("location", "==", locationTrimmed)
      .where("notified", "==", false)
      .get(),
  ]);

  const unique = new Map();
  for (const doc of [...normalizedSnapshot.docs, ...legacySnapshot.docs]) {
    const data = doc.data();
    const key = `${s(data.email).toLowerCase()}:${normalizeLocationToken(data.location)}`;
    if (!unique.has(key)) unique.set(key, data);
  }

  return [...unique.values()];
}

export async function markNotified(email, location) {
  const emailTrimmed = s(email).toLowerCase();
  const locationTrimmed = s(location);
  const normalizedLocation = normalizeLocationToken(locationTrimmed);
  const normalizedDocId = `${emailTrimmed}:${normalizedLocation}`;
  const legacyDocId = `${emailTrimmed}:${locationTrimmed}`;

  try {
    await waitlist().doc(normalizedDocId).update({ notified: true, notifiedAt: new Date().toISOString() });
    return;
  } catch (error) {
    // Firestore NOT_FOUND code
    if (error?.code !== 5) {
      throw error;
    }
  }

  await waitlist().doc(legacyDocId).update({ notified: true, notifiedAt: new Date().toISOString() });
}
