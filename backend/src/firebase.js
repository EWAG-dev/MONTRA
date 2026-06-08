import admin from "firebase-admin";

let initialized = false;

function parseServiceAccount() {
  const rawJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!rawJson) {
    return null;
  }

  try {
    return JSON.parse(rawJson);
  } catch {
    return null;
  }
}

export function initFirebaseAdmin() {
  if (initialized) {
    return;
  }

  const serviceAccount = parseServiceAccount();
  const projectId = process.env.FIREBASE_PROJECT_ID;

  if (serviceAccount) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: projectId || serviceAccount.project_id,
    });
    initialized = true;
    return;
  }

  if (projectId) {
    admin.initializeApp({
      projectId,
    });
    initialized = true;
    return;
  }

  throw new Error("Firebase Admin config missing. Set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_PROJECT_ID.");
}

export function getAuth() {
  if (!initialized) {
    initFirebaseAdmin();
  }
  return admin.auth();
}

export function getFirestore() {
  if (!initialized) {
    initFirebaseAdmin();
  }
  return admin.firestore();
}
