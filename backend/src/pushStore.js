import { getFirestore, getMessaging } from "./firebase.js";

// Device tokens keyed by uid — one token per uid (last-registered wins).
// Collection: "deviceTokens" / doc id = uid / fields: { token, updatedAt }

function collection() {
  return getFirestore().collection("deviceTokens");
}

export async function saveDeviceToken(uid, token) {
  if (!uid || !token) return;
  await collection().doc(uid).set(
    { token: String(token).trim(), updatedAt: new Date().toISOString() },
    { merge: true }
  );
}

export async function getDeviceToken(uid) {
  if (!uid) return null;
  const doc = await collection().doc(uid).get();
  return doc.exists ? (doc.data().token || null) : null;
}

export async function deleteDeviceToken(uid) {
  if (!uid) return;
  await collection().doc(uid).delete().catch(() => {});
}

// Sends a push notification to a single uid. Silently no-ops if they have
// no token or if the Messaging API isn't available (e.g. missing config).
export async function sendPushToUid(uid, { title, body, data = {} }) {
  if (!uid) return;
  const token = await getDeviceToken(uid);
  if (!token) return;

  try {
    const messaging = getMessaging();
    await messaging.send({
      token,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
      apns: {
        payload: {
          aps: { sound: "default", badge: 1 },
        },
      },
    });
  } catch (err) {
    // Token may be stale (device re-installed, etc.) — delete it so we don't
    // keep trying and log unnecessary errors.
    if (
      err.code === "messaging/registration-token-not-registered" ||
      err.code === "messaging/invalid-registration-token"
    ) {
      await deleteDeviceToken(uid);
    } else {
      console.error(`[Push] Failed to notify uid ${uid}:`, err.message);
    }
  }
}
