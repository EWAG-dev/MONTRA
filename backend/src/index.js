import "dotenv/config";
import { randomBytes } from "crypto";
import cors from "cors";
import express from "express";
import { getAuth, getFirestore, initFirebaseAdmin } from "./firebase.js";
import {
  approveTrainer,
  createTrainer,
  deleteTrainer,
  evaluateTrainerApplication,
  getTrainerByAccountUid,
  getTrainer,
  getTrainerBySlug,
  listTrainers,
  markOrientationCompleted,
  matchTrainers,
  rejectTrainer,
  upsertTrainerForAccount,
  updateTrainer,
  setTrainerVerification,
} from "./trainerStore.js";
import {
  createMatchRequest,
  getMatchRequest,
  listClientRequests,
  listTrainerMatches,
  updateMatchRequestStatus,
} from "./matchStore.js";
import {
  ensureConversationThread,
  getConversation,
  listConversationMessages,
  listConversationsForClient,
  listConversationsForTrainer,
  sendConversationMessage,
} from "./chatStore.js";
import {
  cancelBookedSession,
  completeBookedSession,
  createBookedSession,
  getBookedSession,
  listClientSessions,
  listTrainerSessions,
} from "./sessionStore.js";
import { getClientProgress, saveClientProgress, addWeightEntry, getWeightHistory } from "./progressStore.js";
import {
  createProgram,
  listTrainerPrograms,
  getProgram,
  updateProgram,
  deleteProgram,
  assignProgram,
  listClientPrograms,
  deleteProgramsForTrainerOrClient,
} from "./programStore.js";
import { saveDeviceToken, deleteDeviceToken, sendPushToUid } from "./pushStore.js";
import {
  createImpactCredit,
  listClientCredits,
  getCredit,
  directCredit,
  getCommunityImpact,
  deleteCreditsForClient,
} from "./impactStore.js";
import {
  createReview,
  listTrainerReviews,
  deleteReviewsForClient,
} from "./reviewStore.js";
import { getTrainerInsights } from "./insightStore.js";
import { getTrainerPackages } from "./packageStore.js";
import { computeMatch, normalizePrefs } from "./matchScore.js";
import { createLead, listLeads, updateLeadStatus, deleteLeadsForPhone } from "./leadStore.js";
import { createIntroSessionIntent, createProgramSubscription, cancelSubscription, constructWebhookEvent, getPublishableKey } from "./stripeStore.js";

// Safety net: Express 4 doesn't forward errors from async route handlers, so a
// single rejecting request would otherwise become an unhandled rejection and crash
// the whole process (Node's default). Log and keep serving instead of taking the
// entire API down over one bad request.
process.on("unhandledRejection", (reason) => {
  console.error("Unhandled promise rejection (kept alive):", reason);
});

const app = express();
const port = Number(process.env.PORT || 8080);
const autoApproveTrainers = String(process.env.AUTO_APPROVE_TRAINERS || "true").toLowerCase() === "true";
const approveThreshold = Number(process.env.HIRING_SCORE_APPROVE_THRESHOLD || 70);
const adminEmails = (process.env.ADMIN_EMAILS || "")
  .split(",")
  .map((value) => value.trim().toLowerCase())
  .filter(Boolean);

const allowedOrigins = (process.env.ALLOWED_ORIGINS || "")
  .split(",")
  .map((v) => v.trim())
  .filter(Boolean);
const defaultOrigins = [
  "https://montra-27532.web.app",
  "https://montra-production.up.railway.app",
  "http://localhost:3000",
  "http://localhost:5173",
  "http://127.0.0.1:5173",
];
const corsOrigins = [...new Set([...defaultOrigins, ...allowedOrigins])];

app.use(express.json({ limit: "5mb" }));
app.use(
  cors({
    origin: corsOrigins.length ? corsOrigins : true,
  })
);

initFirebaseAdmin();

// ── Email helpers ─────────────────────────────────────────────────────────────

async function sendEmail(to, subject, html) {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    console.warn(`[Email skipped — RESEND_API_KEY not set] To: ${to} | Subject: ${subject}`);
    return;
  }
  const from = process.env.FROM_EMAIL || "MONTRA <noreply@montra.com>";
  console.log(`[Email] Sending to: ${to} | From: ${from} | Subject: ${subject}`);
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from, to: [to], subject, html }),
  });
  const body = await res.text();
  if (!res.ok) {
    console.error(`[Email] Resend API error ${res.status}: ${body}`);
    throw new Error(`Resend error ${res.status}: ${body}`);
  }
  console.log(`[Email] Sent successfully. Resend response: ${body}`);
}

// Sends a transactional SMS via Twilio's REST API (no SDK needed). No-ops if Twilio
// isn't configured, mirroring sendEmail, so missing creds never break a request.
async function sendSMS(to, body) {
  const sid = process.env.TWILIO_ACCOUNT_SID;
  const token = process.env.TWILIO_AUTH_TOKEN;
  const from = process.env.TWILIO_FROM; // a Twilio number (+1...) or Messaging Service SID (MG...)
  if (!sid || !token || !from || !to) {
    console.warn(`[SMS skipped — Twilio not configured] To: ${to || "(none)"}`);
    return;
  }
  const params = new URLSearchParams();
  params.set("To", to);
  if (from.startsWith("MG")) params.set("MessagingServiceSid", from);
  else params.set("From", from);
  params.set("Body", body);
  const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
    method: "POST",
    headers: {
      Authorization: "Basic " + Buffer.from(`${sid}:${token}`).toString("base64"),
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params.toString(),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Twilio error ${res.status}: ${text}`);
  }
}

// SMS recipients for a routed team: prefer a team-specific number, fall back to the
// shared LEAD_SMS_TO list. Returns an array of E.164 numbers.
function smsRecipientsForTeam(team) {
  const perTeam = {
    sales: process.env.LEAD_SMS_SALES,
    support: process.env.LEAD_SMS_SUPPORT,
    recruiting: process.env.LEAD_SMS_RECRUITING,
  }[team];
  const raw = perTeam || process.env.LEAD_SMS_TO || "";
  return raw.split(",").map((n) => n.trim()).filter(Boolean);
}

function escapeHtml(value) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function approvalEmailHtml(name, resetLink) {
  return `<!DOCTYPE html><html><body style="margin:0;padding:0;background:#0a0a0a;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
<div style="max-width:560px;margin:0 auto;padding:48px 24px">
  <p style="color:#FF6820;font-size:11px;font-weight:700;letter-spacing:2px;margin:0 0 32px">MONTRA</p>
  <h1 style="color:#fff;font-size:28px;font-weight:900;margin:0 0 12px">You're approved.</h1>
  <p style="color:#999;font-size:15px;margin:0 0 32px">Welcome to the Elite Home Fitness trainer network.</p>
  <p style="font-size:15px;line-height:1.7;color:#ccc">Hi ${name},<br><br>
  Congratulations — your application has been approved and you are now part of the MONTRA trainer network.<br><br>
  Click below to set your password and complete your trainer profile. Once your profile is live you will start receiving client match requests in the MONTRA app.</p>
  <a href="${resetLink}" style="display:inline-block;background:#FF6820;color:#000;font-size:15px;font-weight:700;padding:16px 32px;border-radius:12px;text-decoration:none;margin:32px 0">Set Password &amp; Complete Profile &rarr;</a>
  <p style="color:#666;font-size:13px;line-height:1.6">After setting your password you will be taken to your trainer profile page. Then download the MONTRA app and sign in with your email and new password.</p>
  <hr style="border:none;border-top:1px solid #222;margin:40px 0">
  <p style="color:#555;font-size:11px">MONTRA &middot; Powered by Elite Home Fitness</p>
</div></body></html>`;
}

function rejectionEmailHtml(name, concerns = []) {
  const concernsBlock = concerns.length
    ? `<div style="background:#151515;border-radius:10px;padding:20px;margin:24px 0;border:1px solid #222">
         <p style="color:#999;font-size:12px;font-weight:600;letter-spacing:1px;margin:0 0 12px">AREAS TO STRENGTHEN</p>
         <ul style="margin:0;padding-left:18px;color:#bbb;font-size:14px;line-height:1.8">${concerns.map(c => `<li>${c}</li>`).join("")}</ul>
       </div>`
    : "";
  return `<!DOCTYPE html><html><body style="margin:0;padding:0;background:#0a0a0a;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
<div style="max-width:560px;margin:0 auto;padding:48px 24px">
  <p style="color:#FF6820;font-size:11px;font-weight:700;letter-spacing:2px;margin:0 0 32px">MONTRA</p>
  <h1 style="color:#fff;font-size:24px;font-weight:900;margin:0 0 24px">Thank you for applying</h1>
  <p style="font-size:15px;line-height:1.7;color:#ccc">Hi ${name},<br><br>
  Thank you for your interest in joining MONTRA. After carefully reviewing your application, we are unable to move forward at this time.<br><br>
  We genuinely appreciate the effort you put in, and we encourage you to strengthen your profile and reapply in the future.</p>
  ${concernsBlock}
  <p style="color:#777;font-size:14px;line-height:1.6">We wish you the very best and hope to work with you down the road.</p>
  <hr style="border:none;border-top:1px solid #222;margin:40px 0">
  <p style="color:#555;font-size:11px">MONTRA &middot; Powered by Elite Home Fitness</p>
</div></body></html>`;
}

function applicationReceivedEmailHtml(name) {
  return `<!DOCTYPE html><html><body style="margin:0;padding:0;background:#0a0a0a;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
<div style="max-width:560px;margin:0 auto;padding:48px 24px">
  <p style="color:#FF6820;font-size:11px;font-weight:700;letter-spacing:2px;margin:0 0 32px">MONTRA</p>
  <h1 style="color:#fff;font-size:24px;font-weight:900;margin:0 0 16px">Application Received</h1>
  <p style="font-size:15px;line-height:1.7;color:#ccc">Hi ${name},<br><br>
  We received your MONTRA coach application and our team will review it within 48 hours.<br><br>
  If approved, you will receive a second email with a secure link to set your password and complete your trainer onboarding.</p>
  <div style="background:#151515;border-radius:10px;padding:18px;margin:24px 0;border:1px solid #222;color:#bbb;font-size:14px;line-height:1.7">
    <strong style="color:#fff">What happens next:</strong><br>
    1) Application review<br>
    2) Eligibility checks<br>
    3) Approval email with setup link
  </div>
  <p style="color:#777;font-size:14px;line-height:1.6">Thank you for applying to MONTRA.</p>
  <hr style="border:none;border-top:1px solid #222;margin:40px 0">
  <p style="color:#555;font-size:11px">MONTRA &middot; Powered by Elite Home Fitness</p>
</div></body></html>`;
}

function chatMessageEmailHtml(senderName, messageText) {
  return `<!DOCTYPE html><html><body style="margin:0;padding:0;background:#0a0a0a;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
<div style="max-width:560px;margin:0 auto;padding:48px 24px">
  <p style="color:#FF6820;font-size:11px;font-weight:700;letter-spacing:2px;margin:0 0 32px">MONTRA</p>
  <h1 style="color:#fff;font-size:24px;font-weight:900;margin:0 0 16px">New message</h1>
  <p style="font-size:15px;line-height:1.7;color:#ccc">You have a new message from ${escapeHtml(senderName || "your MONTRA match") }.</p>
  <div style="background:#151515;border-radius:10px;padding:18px;margin:24px 0;border:1px solid #222;color:#fff;font-size:14px;line-height:1.7">
    ${escapeHtml(messageText)}
  </div>
  <p style="color:#777;font-size:14px;line-height:1.6">Open the MONTRA app to reply and schedule your next session.</p>
  <hr style="border:none;border-top:1px solid #222;margin:40px 0">
  <p style="color:#555;font-size:11px">MONTRA &middot; Powered by Elite Home Fitness</p>
</div></body></html>`;
}

function trainerClientRequestEmailHtml(trainerName, clientName) {
  return `<!DOCTYPE html><html><body style="margin:0;padding:0;background:#0a0a0a;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
<div style="max-width:560px;margin:0 auto;padding:48px 24px">
  <p style="color:#FF6820;font-size:11px;font-weight:700;letter-spacing:2px;margin:0 0 32px">MONTRA</p>
  <h1 style="color:#fff;font-size:24px;font-weight:900;margin:0 0 16px">New client request</h1>
  <p style="font-size:15px;line-height:1.7;color:#ccc">Hi ${escapeHtml(trainerName || "Coach")},<br><br>
  ${escapeHtml(clientName || "A new client")} selected you as their coach in MONTRA.</p>
  <div style="background:#151515;border-radius:10px;padding:18px;margin:24px 0;border:1px solid #222;color:#bbb;font-size:14px;line-height:1.7">
    Please log in to the MONTRA app to:<br>
    1) Open chat with this client<br>
    2) Coordinate schedule options<br>
    3) Lock in their first session
  </div>
  <p style="color:#777;font-size:14px;line-height:1.6">Thanks for coaching with MONTRA.</p>
  <hr style="border:none;border-top:1px solid #222;margin:40px 0">
  <p style="color:#555;font-size:11px">MONTRA &middot; Powered by Elite Home Fitness</p>
</div></body></html>`;
}

function clientRequestAcceptedEmailHtml(clientName, trainerName) {
  return `<!DOCTYPE html><html><body style="margin:0;padding:0;background:#0a0a0a;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
<div style="max-width:560px;margin:0 auto;padding:48px 24px">
  <p style="color:#FF6820;font-size:11px;font-weight:700;letter-spacing:2px;margin:0 0 32px">MONTRA</p>
  <h1 style="color:#fff;font-size:24px;font-weight:900;margin:0 0 16px">Your coach accepted</h1>
  <p style="font-size:15px;line-height:1.7;color:#ccc">Hi ${escapeHtml(clientName || "there")},<br><br>
  ${escapeHtml(trainerName || "Your coach")} accepted your request in MONTRA.</p>
  <div style="background:#151515;border-radius:10px;padding:18px;margin:24px 0;border:1px solid #222;color:#bbb;font-size:14px;line-height:1.7">
    Open the app to:
    <br>1) Chat with your coach
    <br>2) Confirm your preferred times
    <br>3) Book your first session
  </div>
  <p style="color:#777;font-size:14px;line-height:1.6">Your training journey is officially underway.</p>
  <hr style="border:none;border-top:1px solid #222;margin:40px 0">
  <p style="color:#555;font-size:11px">MONTRA &middot; Powered by Elite Home Fitness</p>
</div></body></html>`;
}

function sessionBookedEmailHtml(trainerName, clientName, startTimeDisplay) {
  return `<!DOCTYPE html><html><body style="margin:0;padding:0;background:#0a0a0a;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
<div style="max-width:560px;margin:0 auto;padding:48px 24px">
  <p style="color:#FF6820;font-size:11px;font-weight:700;letter-spacing:2px;margin:0 0 32px">MONTRA</p>
  <h1 style="color:#fff;font-size:24px;font-weight:900;margin:0 0 16px">New session booked</h1>
  <p style="font-size:15px;line-height:1.7;color:#ccc">Hi ${escapeHtml(trainerName || "there")},<br><br>
  ${escapeHtml(clientName || "A client")} booked a session with you for <strong>${escapeHtml(startTimeDisplay || "")}</strong>.</p>
  <p style="color:#777;font-size:14px;line-height:1.6">Open the app to see it on your schedule.</p>
  <hr style="border:none;border-top:1px solid #222;margin:40px 0">
  <p style="color:#555;font-size:11px">MONTRA &middot; Powered by Elite Home Fitness</p>
</div></body></html>`;
}

async function finalizeTrainerApproval(trainer, context = "approval") {
  if (!trainer) {
    return null;
  }

  if (!trainer.accountUid && trainer.email) {
    try {
      const tempPassword = randomBytes(16).toString("base64url");
      const authUser = await getAuth().createUser({
        email: trainer.email,
        password: tempPassword,
        displayName: trainer.name,
      });
      await updateTrainer(trainer.id, { accountUid: authUser.uid });
      trainer.accountUid = authUser.uid;
    } catch (authError) {
      if (authError.code === "auth/email-already-exists") {
        try {
          const existing = await getAuth().getUserByEmail(trainer.email);
          if (trainer.name && existing.displayName !== trainer.name) {
            await getAuth().updateUser(existing.uid, { displayName: trainer.name });
          }
          await updateTrainer(trainer.id, { accountUid: existing.uid });
          trainer.accountUid = existing.uid;
        } catch (e) {
          console.error(`[${context}] Failed to resolve existing auth user:`, e.message);
        }
      } else {
        console.error(`[${context}] Failed to provision trainer auth account:`, authError.message);
      }
    }
  }

  if (trainer.accountUid) {
    try {
      await getAuth().setCustomUserClaims(trainer.accountUid, { role: "trainer" });
    } catch (claimError) {
      console.error(`[${context}] Failed to set trainer custom claim:`, claimError.message);
    }
  }

  if (trainer.email) {
    try {
      const onboardingUrl = `${process.env.WEBSITE_URL || "https://montra-27532.web.app"}/trainer-onboarding.html`;
      const resetLink = await getAuth().generatePasswordResetLink(trainer.email, { url: onboardingUrl });
      await sendEmail(trainer.email, "You're approved — welcome to MONTRA!", approvalEmailHtml(trainer.name, resetLink));
    } catch (emailError) {
      console.error(`[${context}] Failed to send approval email:`, emailError.message);
      const webApiKey = process.env.FIREBASE_WEB_API_KEY;
      if (webApiKey) {
        await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${webApiKey}`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ requestType: "PASSWORD_RESET", email: trainer.email }),
        }).catch(() => {});
      }
    }
  }

  return trainer;
}

app.get("/", (_req, res) => {
  res.status(200).json({ ok: true, service: "montra-backend" });
});

app.get("/health", (_req, res) => {
  res.status(200).json({ ok: true, service: "montra-backend" });
});

app.get("/api/firebase/client-config", (_req, res) => {
  const projectId = String(process.env.FIREBASE_PROJECT_ID || "").trim();
  const rawAuthDomain = String(process.env.FIREBASE_AUTH_DOMAIN || "").trim();
  const rawAppId = String(process.env.FIREBASE_APP_ID || "").trim();
  const warnings = [];

  let authDomain = rawAuthDomain;
  if (authDomain.endsWith(".firebaseapp.co")) {
    authDomain = authDomain.replace(/\.firebaseapp\.co$/i, ".firebaseapp.com");
    warnings.push("FIREBASE_AUTH_DOMAIN had .firebaseapp.co and was auto-corrected to .firebaseapp.com");
  }
  if (!authDomain && projectId) {
    authDomain = `${projectId}.firebaseapp.com`;
    warnings.push("FIREBASE_AUTH_DOMAIN missing; using default <project>.firebaseapp.com");
  }

  let appId = rawAppId;
  if (appId && !/^1:\d+:(web|ios|android):/i.test(appId)) {
    warnings.push("FIREBASE_APP_ID does not look valid; omitting appId from client config");
    appId = "";
  }

  res.status(200).json({
    apiKey: process.env.FIREBASE_WEB_API_KEY || "",
    authDomain,
    appId,
    projectId,
    warnings,
  });
});

async function requireFirebaseAuth(req, res, next) {
  const authHeader = req.headers.authorization || "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";

  if (!token) {
    res.status(401).json({ error: "Missing bearer token" });
    return;
  }

  try {
    const decoded = await getAuth().verifyIdToken(token);
    req.user = decoded;
    next();
  } catch {
    res.status(401).json({ error: "Invalid Firebase token" });
  }
}

function hasAdminAccess(user) {
  const email = String(user.email || "").toLowerCase();
  const role = String(user.role || user.adminRole || "").toLowerCase();
  const claims = user || {};

  return (
    adminEmails.includes(email) ||
    role === "admin" ||
    role === "trainer_admin" ||
    claims.admin === true
  );
}

function requireAdmin(req, res, next) {
  if (!hasAdminAccess(req.user)) {
    res.status(403).json({ error: "Admin access required" });
    return;
  }

  next();
}

app.get("/api/me", requireFirebaseAuth, (req, res) => {
  res.status(200).json({
    uid: req.user.uid,
    email: req.user.email || null,
    role: req.user.role || "client",
    isAdmin: hasAdminAccess(req.user),
  });
});

// Register or refresh the FCM device token for the authenticated user.
// Called by the iOS app whenever FirebaseMessaging delivers a new token.
app.post("/api/me/device-token", requireFirebaseAuth, async (req, res) => {
  const token = String(req.body?.token || "").trim();
  if (!token) {
    return res.status(400).json({ error: "token is required" });
  }
  await saveDeviceToken(req.user.uid, token);
  res.status(200).json({ ok: true });
});

// Remove the device token on sign-out so the user stops receiving pushes.
app.delete("/api/me/device-token", requireFirebaseAuth, async (req, res) => {
  await deleteDeviceToken(req.user.uid);
  res.status(200).json({ ok: true });
});

app.post("/api/trainers/apply", requireFirebaseAuth, async (req, res) => {
  try {
    const application = {
      ...req.body,
      email: req.user.email || req.body.email,
      accountUid: req.user.uid,
      status: "pending",
    };

    let trainer = await upsertTrainerForAccount(req.user.uid, application);
    const evaluation = evaluateTrainerApplication(trainer);

    if (autoApproveTrainers && evaluation.score >= approveThreshold) {
      trainer = await approveTrainer(trainer.id);
    }

    const status = trainer?.status || "pending";

    res.status(200).json({
      trainer,
      hiringEvaluation: evaluation,
      message:
        status === "approved"
          ? "Application approved. You can now view client matches in the app."
          : "Application received. Add stronger profile details to improve your approval score.",
      autoApproveEnabled: autoApproveTrainers,
      requiredScoreForAutoApproval: approveThreshold,
    });
  } catch (error) {
    res.status(400).json({ error: error.message || "Unable to submit trainer application" });
  }
});

// DEV ONLY — one-shot email patch; remove after use
app.post("/api/dev/patch-trainer-email", async (req, res) => {
  if (!process.env.ALLOW_DEV_ENDPOINTS) return res.status(404).json({ error: "Not found" });
  const { trainerId, email } = req.body;
  if (!trainerId || !email) return res.status(400).json({ error: "trainerId + email required" });
  const trainer = await updateTrainer(trainerId, { email });
  if (!trainer) return res.status(404).json({ error: "Trainer not found" });
  res.json({ ok: true, trainerId, email: trainer.email });
});

// DEV ONLY — remove after testing
app.post("/api/dev/create-test-trainer", async (req, res) => {
  if (!process.env.ALLOW_DEV_ENDPOINTS) {
    return res.status(404).json({ error: "Not found" });
  }
  try {
    const { email, password, name } = req.body;
    const auth = getAuth();
    const db = getFirestore();
    // Get or create auth user
    let user;
    try {
      user = await auth.createUser({ email, password, displayName: name });
    } catch (e) {
      if (e.code === "auth/email-already-exists") {
        user = await auth.getUserByEmail(email);
        // Update password in case it changed
        await auth.updateUser(user.uid, { password });
      } else throw e;
    }
    // Find existing trainer doc by email and update accountUid, or create new
    const snap = await db.collection("trainers").where("email", "==", email).limit(1).get();
    if (!snap.empty) {
      await snap.docs[0].ref.update({ accountUid: user.uid, status: "approved" });
    } else {
      await db.collection("trainers").add({ email, name, status: "approved", accountUid: user.uid });
    }
    await auth.setCustomUserClaims(user.uid, { role: "trainer" });
    res.json({ ok: true, uid: user.uid });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// DEV — set trainer role claim for an existing uid
app.post("/api/dev/set-trainer-claim", async (req, res) => {
  if (!process.env.ALLOW_DEV_ENDPOINTS) {
    return res.status(404).json({ error: "Not found" });
  }
  try {
    const { uid } = req.body;
    if (!uid) return res.status(400).json({ error: "uid required" });
    await getAuth().setCustomUserClaims(uid, { role: "trainer" });
    res.json({ ok: true, uid });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// DEV ONLY — remove after testing. Creates an email-verified client account
// (no role claim) for end-to-end booking-flow testing.
app.post("/api/dev/create-test-client", requireFirebaseAuth, requireAdmin, async (req, res) => {
  if (!process.env.ALLOW_DEV_ENDPOINTS) {
    return res.status(404).json({ error: "Not found" });
  }
  try {
    const { email, password, name } = req.body;
    const auth = getAuth();
    let user;
    try {
      user = await auth.createUser({ email, password, displayName: name, emailVerified: true });
    } catch (e) {
      if (e.code === "auth/email-already-exists") {
        user = await auth.getUserByEmail(email);
        await auth.updateUser(user.uid, { password, emailVerified: true });
      } else throw e;
    }
    res.json({ ok: true, uid: user.uid });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// DEV ONLY — remove after testing. Deletes test trainer/client accounts and
// any trainer/match/session/conversation docs referencing them.
app.post("/api/dev/cleanup-test-data", requireFirebaseAuth, requireAdmin, async (req, res) => {
  if (!process.env.ALLOW_DEV_ENDPOINTS) {
    return res.status(404).json({ error: "Not found" });
  }
  try {
    const { trainerUid, clientUid, trainerId } = req.body;
    const db = getFirestore();
    const auth = getAuth();

    let trainerDocId = null;
    if (trainerUid) {
      const snap = await db.collection("trainers").where("accountUid", "==", trainerUid).limit(1).get();
      if (!snap.empty) {
        trainerDocId = snap.docs[0].id;
        await snap.docs[0].ref.delete();
      }
    }
    // Application-only trainer docs (e.g. from /api/trainers/provision) have no accountUid,
    // so they can only be targeted by their Firestore doc id directly.
    if (trainerId && !trainerDocId) {
      const ref = db.collection("trainers").doc(trainerId);
      const doc = await ref.get();
      if (doc.exists) {
        trainerDocId = doc.id;
        await ref.delete();
      }
    }

    const matchesDeletion = (async () => {
      const snap = await db.collection("matchRequests").get();
      await Promise.all(
        snap.docs
          .filter((d) => {
            const data = d.data();
            return (trainerDocId && data.trainerId === trainerDocId) || (clientUid && data.clientUid === clientUid);
          })
          .map((d) => d.ref.delete())
      );
    })();

    const sessionsDeletion = (async () => {
      const snap = await db.collection("bookedSessions").get();
      await Promise.all(
        snap.docs
          .filter((d) => {
            const data = d.data();
            return (trainerDocId && data.trainerId === trainerDocId) || (clientUid && data.clientUid === clientUid);
          })
          .map((d) => d.ref.delete())
      );
    })();

    const conversationsDeletion = (async () => {
      const snap = await db.collection("conversations").get();
      await Promise.all(
        snap.docs
          .filter((d) => {
            const data = d.data();
            return (trainerDocId && data.trainerId === trainerDocId) || (clientUid && data.clientUid === clientUid);
          })
          .map((d) => d.ref.delete())
      );
    })();

    const programsDeletion = deleteProgramsForTrainerOrClient({
      trainerId: trainerDocId,
      clientUid,
    });

    const creditsDeletion = clientUid ? deleteCreditsForClient(clientUid) : Promise.resolve();
    const reviewsDeletion = clientUid ? deleteReviewsForClient(clientUid) : Promise.resolve();
    const leadsDeletion = req.body?.leadPhone ? deleteLeadsForPhone(req.body.leadPhone) : Promise.resolve();

    await Promise.all([matchesDeletion, sessionsDeletion, conversationsDeletion, programsDeletion, creditsDeletion, reviewsDeletion, leadsDeletion]);

    if (trainerUid) {
      try { await auth.deleteUser(trainerUid); } catch (e) { /* already gone */ }
    }
    if (clientUid) {
      try { await auth.deleteUser(clientUid); } catch (e) { /* already gone */ }
      await db.collection("clientProgress").doc(clientUid).delete().catch(() => {});
    }

    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// Dev-only: run full approval flow for a trainer doc without requiring admin auth
app.post("/api/dev/approve-trainer", async (req, res) => {
  if (!process.env.ALLOW_DEV_ENDPOINTS) {
    return res.status(404).json({ error: "Not found" });
  }
  const { trainerId } = req.body;
  if (!trainerId) return res.status(400).json({ error: "trainerId required" });

  const trainer = await approveTrainer(trainerId);
  if (!trainer) return res.status(404).json({ error: "Trainer not found" });

  await finalizeTrainerApproval(trainer, "dev-approve-trainer");

  res.json({ ok: true, trainerId, email: trainer.email });
});

app.post("/api/trainers/provision", async (req, res) => {
  try {
    const {
      firstName,
      lastName,
      email,
      phone,
      specialties,
      certifications,
      coachingStyle,
      experienceYears,
      education,
      references,
      backgroundCheckConsent,
      policyAgreement,
    } = req.body || {};

    if (!firstName || !lastName || !email) {
      res.status(400).json({ error: "firstName, lastName, and email are required" });
      return;
    }

    const name = `${String(firstName).trim()} ${String(lastName).trim()}`;
    const normalizedEmail = String(email).trim().toLowerCase();

    let trainer = await createTrainer({
      name,
      email: normalizedEmail,
      phone: String(phone || "").trim(),
      specialties: Array.isArray(specialties) ? specialties : [],
      certification: String(certifications || "").trim(),
      bio: String(coachingStyle || "").trim(),
      status: "pending",
      experienceYears: Number.isFinite(Number(experienceYears)) ? Number(experienceYears) : 0,
      education: String(education || "").trim(),
      references: Array.isArray(references) ? references : [],
      backgroundCheckConsent: Boolean(backgroundCheckConsent),
      policyAgreement: Boolean(policyAgreement),
    });

    // Best-effort confirmation so applicants know submission succeeded.
    try {
      await sendEmail(
        normalizedEmail,
        "Application received — MONTRA Coach Application",
        applicationReceivedEmailHtml(name)
      );
    } catch (emailError) {
      console.error("Failed to send application confirmation email:", emailError.message);
    }

    if (autoApproveTrainers) {
      trainer = await approveTrainer(trainer.id);
      await finalizeTrainerApproval(trainer, "public-provision-auto-approve");
    }

    res.status(201).json({
      ok: true,
      applicationId: trainer.id,
      status: trainer.status,
      autoApproved: autoApproveTrainers,
    });
  } catch (error) {
    res.status(500).json({ error: error.message || "Failed to submit application" });
  }
});

app.get("/api/trainers/my-profile", requireFirebaseAuth, async (req, res) => {
  const trainer = await getTrainerByAccountUid(req.user.uid);
  if (!trainer) {
    res.status(404).json({ error: "Trainer profile not found" });
    return;
  }

  res.status(200).json({ trainer });
});

app.post("/api/trainers/my-profile/orientation-complete", requireFirebaseAuth, async (req, res) => {
  const trainer = await markOrientationCompleted(req.user.uid);
  if (!trainer) {
    res.status(404).json({ error: "Trainer profile not found" });
    return;
  }

  res.status(200).json({ trainer });
});

app.get("/api/trainers/my-status", requireFirebaseAuth, async (req, res) => {
  const trainer = await getTrainerByAccountUid(req.user.uid);
  if (!trainer) {
    res.status(200).json({
      hasApplication: false,
      status: "not_submitted",
    });
    return;
  }

  const hiringEvaluation = evaluateTrainerApplication(trainer);
  res.status(200).json({
    hasApplication: true,
    status: trainer.status,
    trainer,
    hiringEvaluation,
    autoApproveEnabled: autoApproveTrainers,
    requiredScoreForAutoApproval: approveThreshold,
  });
});

app.get("/api/trainers/my-matches", requireFirebaseAuth, async (req, res) => {
  const trainer = await getTrainerByAccountUid(req.user.uid);
  if (!trainer) {
    res.status(404).json({ error: "Trainer profile not found" });
    return;
  }

  if (trainer.status !== "approved") {
    res.status(403).json({
      error: "Trainer account is not approved yet",
      status: trainer.status,
    });
    return;
  }

  const matches = await listTrainerMatches(trainer.id);
  res.status(200).json({ trainer, matches });
});

// MARK: Trainer programs (templates) + assignment

app.get("/api/trainers/programs", requireFirebaseAuth, async (req, res) => {
  const trainer = await getTrainerByAccountUid(req.user.uid);
  if (!trainer) {
    res.status(404).json({ error: "Trainer profile not found" });
    return;
  }
  const programs = await listTrainerPrograms(trainer.id);
  res.status(200).json({ programs });
});

app.post("/api/trainers/programs", requireFirebaseAuth, async (req, res) => {
  const trainer = await getTrainerByAccountUid(req.user.uid);
  if (!trainer) {
    res.status(404).json({ error: "Trainer profile not found" });
    return;
  }
  try {
    const program = await createProgram(trainer.id, req.body || {});
    res.status(201).json({ program });
  } catch (error) {
    res.status(400).json({ error: error.message || "Unable to create program" });
  }
});

app.put("/api/trainers/programs/:id", requireFirebaseAuth, async (req, res) => {
  const trainer = await getTrainerByAccountUid(req.user.uid);
  const existing = await getProgram(req.params.id);
  if (!existing) {
    res.status(404).json({ error: "Program not found" });
    return;
  }
  if (!trainer || existing.trainerId !== trainer.id) {
    res.status(403).json({ error: "Not your program" });
    return;
  }
  try {
    const program = await updateProgram(req.params.id, req.body || {});
    res.status(200).json({ program });
  } catch (error) {
    res.status(400).json({ error: error.message || "Unable to update program" });
  }
});

app.delete("/api/trainers/programs/:id", requireFirebaseAuth, async (req, res) => {
  const trainer = await getTrainerByAccountUid(req.user.uid);
  const existing = await getProgram(req.params.id);
  if (!existing) {
    res.status(404).json({ error: "Program not found" });
    return;
  }
  if (!trainer || existing.trainerId !== trainer.id) {
    res.status(403).json({ error: "Not your program" });
    return;
  }
  await deleteProgram(req.params.id);
  res.status(200).json({ ok: true });
});

app.post("/api/trainers/programs/:id/assign", requireFirebaseAuth, async (req, res) => {
  const trainer = await getTrainerByAccountUid(req.user.uid);
  const program = await getProgram(req.params.id);
  if (!program) {
    res.status(404).json({ error: "Program not found" });
    return;
  }
  if (!trainer || program.trainerId !== trainer.id) {
    res.status(403).json({ error: "Not your program" });
    return;
  }

  const clientUid = String(req.body?.clientUid || "").trim();
  if (!clientUid) {
    res.status(400).json({ error: "clientUid is required" });
    return;
  }

  // Trainer may only assign to a client they have an accepted match with.
  const matches = await listTrainerMatches(trainer.id);
  const match = matches.find((m) => m.clientUid === clientUid && m.status === "accepted");
  if (!match) {
    res.status(403).json({ error: "No accepted match with this client" });
    return;
  }

  const assignment = await assignProgram({
    program,
    trainerName: trainer.name,
    clientUid,
    clientName: match.clientProfile?.firstName || match.clientName || "",
  });

  // Notify the client their coach assigned a program.
  sendPushToUid(clientUid, {
    title: "New Program Assigned",
    body: `${trainer.name} assigned you a new program: ${program.title}.`,
    data: { category: "program", programId: assignment.id },
  }).catch(() => {});

  res.status(201).json({ assignment });
});

app.get("/api/client/programs", requireFirebaseAuth, async (req, res) => {
  const programs = await listClientPrograms(req.user.uid);
  res.status(200).json({ programs });
});

app.get("/api/trainers/my-sessions", requireFirebaseAuth, async (req, res) => {
  const trainer = await getTrainerByAccountUid(req.user.uid);
  if (!trainer) {
    res.status(404).json({ error: "Trainer profile not found" });
    return;
  }

  if (trainer.status !== "approved") {
    res.status(403).json({
      error: "Trainer account is not approved yet",
      status: trainer.status,
    });
    return;
  }

  const sessions = await listTrainerSessions(trainer.id);
  res.status(200).json({ trainer, sessions });
});

app.post("/api/trainers/sessions/:id/cancel", requireFirebaseAuth, async (req, res) => {
  const trainer = await getTrainerByAccountUid(req.user.uid);
  const existing = await getBookedSession(req.params.id);
  if (!existing) {
    res.status(404).json({ error: "Session not found" });
    return;
  }

  if (!trainer || existing.trainerId !== trainer.id) {
    res.status(403).json({ error: "Not your session" });
    return;
  }

  const session = await cancelBookedSession(req.params.id);

  // Push to the client
  sendPushToUid(session.clientUid, {
    title: "Session Cancelled",
    body: `${trainer.name} cancelled your upcoming session.`,
    data: { category: "session", sessionId: session.id },
  }).catch(() => {});

  res.status(200).json({ session });
});

app.post("/api/trainers/sessions/:id/complete", requireFirebaseAuth, async (req, res) => {
  const trainer = await getTrainerByAccountUid(req.user.uid);
  const existing = await getBookedSession(req.params.id);
  if (!existing) {
    res.status(404).json({ error: "Session not found" });
    return;
  }

  if (!trainer || existing.trainerId !== trainer.id) {
    res.status(403).json({ error: "Not your session" });
    return;
  }

  if (existing.status === "cancelled") {
    res.status(409).json({ error: "Cannot complete a cancelled session" });
    return;
  }

  if (Date.parse(existing.startTime) > Date.now()) {
    res.status(409).json({ error: "Cannot complete a session that hasn't started yet" });
    return;
  }

  const session = await completeBookedSession(req.params.id, { notes: req.body?.notes });

  // Push to the client
  sendPushToUid(session.clientUid, {
    title: "Session Completed",
    body: `${trainer.name} marked your session as complete. Nice work!`,
    data: { category: "session", sessionId: session.id },
  }).catch(() => {});

  res.status(200).json({ session });
});

// Trainer pushes a session preview to the client before the session
app.post("/api/trainers/sessions/:id/preview", requireFirebaseAuth, async (req, res) => {
  const trainer = await getTrainerByAccountUid(req.user.uid);
  const existing = await getBookedSession(req.params.id);
  if (!existing) { res.status(404).json({ error: "Session not found" }); return; }
  if (!trainer || existing.trainerId !== trainer.id) { res.status(403).json({ error: "Not your session" }); return; }

  const { title, durationMin, equipment, focusAreas, notes } = req.body;
  if (!title) { res.status(400).json({ error: "title is required" }); return; }

  const preview = {
    title,
    durationMin: Number(durationMin) || 60,
    equipment: Array.isArray(equipment) ? equipment : [],
    focusAreas: Array.isArray(focusAreas) ? focusAreas : [],
    notes: notes || null,
    trainerName: trainer.name,
    trainerId: trainer.id,
    preparedAt: new Date().toISOString(),
    clientResponse: null,
  };

  const db = getFirestore();
  await db.collection("bookedSessions").doc(req.params.id).update({ preview });

  sendPushToUid(existing.clientUid, {
    title: "Your coach prepared your session 🏋️",
    body: `${trainer.name} has your ${title} session ready. Tap to review.`,
    data: { category: "session_preview", sessionId: req.params.id },
  }).catch(() => {});

  res.status(200).json({ preview });
});

// Client acknowledges or requests changes to a session preview
app.post("/api/client/sessions/:id/preview/respond", requireFirebaseAuth, async (req, res) => {
  const { response } = req.body; // "approved" | "customize"
  if (!["approved", "customize"].includes(response)) { res.status(400).json({ error: "response must be approved or customize" }); return; }
  const existing = await getBookedSession(req.params.id);
  if (!existing) { res.status(404).json({ error: "Session not found" }); return; }
  if (existing.clientUid !== req.user.uid) { res.status(403).json({ error: "Not your session" }); return; }
  if (!existing.preview) { res.status(409).json({ error: "No preview to respond to" }); return; }

  const db = getFirestore();
  await db.collection("bookedSessions").doc(req.params.id).update({ "preview.clientResponse": response });
  res.status(200).json({ ok: true });
});

// Client fetches their latest upcoming session that has a coach-prepared preview
app.get("/api/client/session-preview", requireFirebaseAuth, async (req, res) => {
  const db = getFirestore();
  const now = new Date().toISOString();
  // Single-field filter only — sort in JS to avoid needing a composite index
  const snap = await db.collection("bookedSessions")
    .where("clientUid", "==", req.user.uid)
    .get();

  const withPreview = snap.docs
    .map(d => ({ id: d.id, ...d.data() }))
    .filter(s => s.status === "confirmed" && s.startTime > now && s.preview)
    .sort((a, b) => a.startTime.localeCompare(b.startTime));

  if (!withPreview.length) { res.status(200).json({ preview: null }); return; }
  const session = withPreview[0];
  res.status(200).json({ preview: { ...session.preview, sessionId: session.id, startTime: session.startTime } });
});

app.post("/api/trainers/matches/:requestId/accept", requireFirebaseAuth, async (req, res) => {
  const trainer = await getTrainerByAccountUid(req.user.uid);
  if (!trainer) {
    res.status(404).json({ error: "Trainer profile not found" });
    return;
  }

  const existing = await getMatchRequest(req.params.requestId);
  if (!existing) {
    res.status(404).json({ error: "Match request not found" });
    return;
  }

  if (existing.trainerId !== trainer.id) {
    res.status(403).json({ error: "Not allowed to update this request" });
    return;
  }

  if (existing.status === "accepted") {
    res.status(200).json({ request: existing, alreadyAccepted: true });
    return;
  }

  const request = await updateMatchRequestStatus(existing.id, "accepted");

  if (request?.clientEmail) {
    const clientName = request?.clientProfile?.firstName || "";
    sendEmail(
      request.clientEmail,
      "Your MONTRA coach accepted your request",
      clientRequestAcceptedEmailHtml(clientName, trainer.name)
    ).catch((error) => console.error("Failed to send client acceptance email:", error.message));
  }

  // Push to client
  sendPushToUid(request.clientUid, {
    title: "Coach Accepted Your Request",
    body: `${trainer.name} accepted your request. Open the app to start chatting.`,
    data: { category: "request", requestId: request.id },
  }).catch(() => {});

  res.status(200).json({ request });
});

app.post("/api/trainers/matches/:requestId/decline", requireFirebaseAuth, async (req, res) => {
  const trainer = await getTrainerByAccountUid(req.user.uid);
  if (!trainer) {
    res.status(404).json({ error: "Trainer profile not found" });
    return;
  }

  const existing = await getMatchRequest(req.params.requestId);
  if (!existing) {
    res.status(404).json({ error: "Match request not found" });
    return;
  }

  if (existing.trainerId !== trainer.id) {
    res.status(403).json({ error: "Not allowed to update this request" });
    return;
  }

  if (existing.status === "declined") {
    res.status(200).json({ request: existing, alreadyDeclined: true });
    return;
  }

  const request = await updateMatchRequestStatus(existing.id, "declined");
  res.status(200).json({ request });
});

app.post("/api/trainers/matches/:requestId/open-chat", requireFirebaseAuth, async (req, res) => {
  const trainer = await getTrainerByAccountUid(req.user.uid);
  if (!trainer) {
    res.status(404).json({ error: "Trainer profile not found" });
    return;
  }

  const existing = await getMatchRequest(req.params.requestId);
  if (!existing) {
    res.status(404).json({ error: "Match request not found" });
    return;
  }

  if (existing.trainerId !== trainer.id) {
    res.status(403).json({ error: "Not allowed to open chat for this request" });
    return;
  }

  const requestConversationId = String(existing.conversationId || "").trim();
  const fallbackConversationId = `trainer_${String(existing.trainerId || "").trim()}__client_${String(existing.clientUid || "").trim()}`;
  const conversationId = requestConversationId || fallbackConversationId;

  let conversation = await getConversation(conversationId);
  if (!conversation) {
    conversation = await ensureConversationThread({
      trainerId: trainer.id,
      trainerName: existing.trainerName || trainer.name,
      clientUid: String(existing.clientUid || "").trim(),
      clientEmail: String(existing.clientEmail || "").trim(),
      clientName: String(existing?.clientProfile?.firstName || "").trim() || "Client",
    });
  }

  res.status(200).json({ conversation });
});

app.get("/api/trainers", async (req, res) => {
  const includeInactive = req.query.includeInactive === "true";
  const trainers = await listTrainers({ includeInactive });
  res.status(200).json({ trainers });
});

// Must be registered before /api/trainers/:id — otherwise Express matches "match" as an :id
// value and this route is unreachable (always falls through to "Trainer not found").
app.get("/api/trainers/match", async (req, res) => {
  const filters = {
    goal: String(req.query.goal || "").trim(),
    location: String(req.query.location || "").trim(),
    gender: String(req.query.gender || "").trim(),
    preferredDays: String(req.query.preferredDays || "")
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
  };
  const trainers = await matchTrainers(filters);
  res.status(200).json({ trainers, filters });
});

// Resolve an SEO coach URL (/coaches/<slug>) to a trainer. Registered before the
// generic :id route; "by-slug" is a literal first segment so there's no overlap.
app.get("/api/trainers/by-slug/:slug", async (req, res) => {
  const trainer = await getTrainerBySlug(req.params.slug);
  if (!trainer) {
    res.status(404).json({ error: "Trainer not found" });
    return;
  }
  res.status(200).json({ trainer });
});

app.get("/api/trainers/:id", async (req, res) => {
  const trainer = await getTrainer(req.params.id);
  if (!trainer) {
    res.status(404).json({ error: "Trainer not found" });
    return;
  }
  res.status(200).json({ trainer });
});

// MONTRA Match score + factor breakdown for a coach, personalized from the client's
// quiz prefs (same algorithm as the website, scored against the full trainer record).
app.post("/api/trainers/:id/match", async (req, res) => {
  try {
    const trainer = await getTrainer(req.params.id);
    if (!trainer) {
      res.status(404).json({ error: "Trainer not found" });
      return;
    }
    res.status(200).json(computeMatch(trainer, normalizePrefs(req.body?.prefs)));
  } catch (err) {
    console.error("match route failed:", err.message);
    res.status(500).json({ error: "Could not compute match" });
  }
});

// Batch MONTRA Match scores for many coaches at once (the Find-a-Coach + Get Matched
// card badges) — one call instead of N. Returns id -> { overall, quality }.
app.post("/api/match/batch", async (req, res) => {
  try {
    const ids = Array.isArray(req.body?.ids) ? req.body.ids.filter((x) => typeof x === "string").slice(0, 60) : [];
    if (!ids.length) {
      res.status(200).json({ results: [] });
      return;
    }
    const prefs = normalizePrefs(req.body?.prefs);
    const all = await listTrainers({ includeInactive: true });
    const byId = new Map(all.map((t) => [t.id, t]));
    const results = ids
      .map((id) => {
        const trainer = byId.get(id);
        if (!trainer) return null;
        const m = computeMatch(trainer, prefs);
        return { id, overall: m.overall, quality: m.quality };
      })
      .filter(Boolean);
    res.status(200).json({ results });
  } catch (err) {
    console.error("match batch route failed:", err.message);
    res.status(500).json({ error: "Could not compute matches" });
  }
});

// Public: real client reviews for a coach, newest first. Powers the
// "What Clients Say" block on coach-profile.html.
app.get("/api/trainers/:id/reviews", async (req, res) => {
  const trainer = await getTrainer(req.params.id);
  if (!trainer) {
    res.status(404).json({ error: "Trainer not found" });
    return;
  }
  const reviews = await listTrainerReviews(req.params.id, { limit: 50 });
  res.status(200).json({
    reviews,
    summary: {
      rating: trainer.rating ?? null,
      reviewCount: trainer.reviewCount ?? reviews.length,
    },
  });
});

// Public: derived "MONTRA Insights" + client-proof signals for a coach. Real where
// the data model supports it (demand, background-verified, featured review), with
// deterministic, swap-for-real placeholders elsewhere (see insightStore.js).
app.get("/api/trainers/:id/insights", async (req, res) => {
  try {
    const insights = await getTrainerInsights(req.params.id);
    if (!insights) {
      res.status(404).json({ error: "Trainer not found" });
      return;
    }
    res.status(200).json(insights);
  } catch (err) {
    console.error("insights route failed:", err.message);
    res.status(500).json({ error: "Could not load insights" });
  }
});

// Public: a coach's session packages (5/10/20/40), frequency options, and à-la-carte
// add-ons with derived pricing. Powers the interactive "Choose Your Session Package"
// builder on the coach profile. See packageStore.js.
app.get("/api/trainers/:id/packages", async (req, res) => {
  try {
    const packages = await getTrainerPackages(req.params.id);
    if (!packages) {
      res.status(404).json({ error: "Trainer not found" });
      return;
    }
    res.status(200).json(packages);
  } catch (err) {
    console.error("packages route failed:", err.message);
    res.status(500).json({ error: "Could not load packages" });
  }
});

// Notifies the routed internal team about a new callback request. Email is real
// (Resend); SMS-to-rep is a documented follow-up (no SMS provider wired yet).
async function notifyLeadTeam(lead) {
  if (!adminEmails.length) return;
  const ctx = lead.context || {};
  const ctxRows = Object.entries(ctx)
    .filter(([, v]) => v)
    .map(([k, v]) => `<tr><td style="padding:2px 10px 2px 0;color:#888">${escapeHtml(k)}</td><td><b>${escapeHtml(String(v))}</b></td></tr>`)
    .join("");
  const html = `
    <h2>New callback request — route to <span style="color:#E85D04">${escapeHtml(lead.team)}</span></h2>
    <table style="font-size:14px">
      <tr><td style="padding:2px 10px 2px 0;color:#888">Name</td><td><b>${escapeHtml(lead.firstName)}</b></td></tr>
      <tr><td style="padding:2px 10px 2px 0;color:#888">Phone</td><td><b>${escapeHtml(lead.phone)}</b></td></tr>
      ${lead.email ? `<tr><td style="padding:2px 10px 2px 0;color:#888">Email</td><td>${escapeHtml(lead.email)}</td></tr>` : ""}
      ${lead.message ? `<tr><td style="padding:2px 10px 2px 0;color:#888">Message</td><td>${escapeHtml(lead.message)}</td></tr>` : ""}
      <tr><td style="padding:2px 10px 2px 0;color:#888">From page</td><td>${escapeHtml(lead.source)} (${escapeHtml(lead.sourcePath || "—")})</td></tr>
      ${ctxRows}
    </table>
    <p style="color:#888;font-size:12px">Call back within 10–15 minutes during business hours.</p>`;
  const emailJobs = adminEmails.map((to) =>
    sendEmail(to, `📞 New callback request — ${lead.firstName} (${lead.team})`, html).catch((e) =>
      console.error("lead email failed:", e.message)
    )
  );

  // SMS the assigned rep(s) so they can call back within the 10–15 min window.
  const city = lead.context?.city ? ` · ${lead.context.city}` : "";
  const smsBody = `MONTRA ${lead.team} callback: ${lead.firstName} ${lead.phone}${city}. From ${lead.source}. Call back within 10–15 min.`;
  const smsJobs = smsRecipientsForTeam(lead.team).map((to) =>
    sendSMS(to, smsBody).catch((e) => console.error("lead SMS failed:", e.message))
  );

  await Promise.all([...emailJobs, ...smsJobs]);
}

// Public: "Talk to a Human" callback request from the MONTRA Team chat widget.
// Creates a lead, routes it to the right team, and notifies the team.
app.post("/api/leads/callback", async (req, res) => {
  try {
    const lead = await createLead({
      firstName: req.body?.firstName,
      phone: req.body?.phone,
      email: req.body?.email,
      message: req.body?.message,
      source: req.body?.source,
      sourcePath: req.body?.sourcePath,
      context: req.body?.context,
    });
    notifyLeadTeam(lead).catch((e) => console.error("notifyLeadTeam failed:", e.message));
    res.status(201).json({ ok: true, ticketId: lead.id, team: lead.team, etaMinutes: 15 });
  } catch (err) {
    const status = err.code === "invalid" ? 400 : 500;
    res.status(status).json({ error: err.message || "Could not submit your request" });
  }
});

app.get("/api/admin/leads", requireFirebaseAuth, requireAdmin, async (_req, res) => {
  const allLeads = await listLeads({ limit: 200 });
  res.status(200).json({ leads: allLeads });
});

app.post("/api/admin/leads/:id/status", requireFirebaseAuth, requireAdmin, async (req, res) => {
  try {
    const lead = await updateLeadStatus(req.params.id, req.body?.status);
    if (!lead) {
      res.status(404).json({ error: "Lead not found" });
      return;
    }
    res.status(200).json({ lead });
  } catch (err) {
    res.status(err.code === "invalid" ? 400 : 500).json({ error: err.message || "Could not update lead" });
  }
});

app.post("/api/client/match", requireFirebaseAuth, async (req, res) => {
  const filters = {
    goal: String(req.body.goal || "").trim(),
    location: String(req.body.location || "").trim(),
    gender: String(req.body.gender || "").trim(),
    preferredDays: Array.isArray(req.body.preferredDays) ? req.body.preferredDays : [],
  };

  const trainers = await matchTrainers(filters);
  res.status(200).json({ trainers, filters });
});

app.post("/api/client/requests", requireFirebaseAuth, async (req, res) => {
  try {
    if (req.user.email_verified !== true) {
      res.status(403).json({ error: "Email verification required before selecting a coach" });
      return;
    }

    const trainer = await getTrainer(String(req.body.trainerId || "").trim());
    if (!trainer || trainer.status !== "approved") {
      res.status(400).json({ error: "Selected trainer is unavailable" });
      return;
    }

    const request = await createMatchRequest({
      trainerId: trainer.id,
      trainerName: trainer.name,
      trainerStatus: trainer.status,
      clientUid: req.user.uid,
      clientEmail: req.user.email || "",
      clientProfile: req.body.clientProfile || {},
    });

    const clientFirstName = String(req.body?.clientProfile?.firstName || "").trim();

    if (trainer.email) {
      sendEmail(
        trainer.email,
        "New client request on MONTRA",
        trainerClientRequestEmailHtml(trainer.name, clientFirstName)
      ).catch((e) => console.error("Failed to send trainer client-request email:", e.message));
    }

    // Push to trainer if they have a device registered
    if (trainer.accountUid) {
      sendPushToUid(trainer.accountUid, {
        title: "New Client Request",
        body: `${clientFirstName || "A new client"} wants you as their coach.`,
        data: { category: "request", requestId: request.id },
      }).catch(() => {});
    }

    res.status(201).json({ request });
  } catch (error) {
    res.status(400).json({ error: error.message || "Unable to create request" });
  }
});

app.get("/api/client/requests", requireFirebaseAuth, async (req, res) => {
  const requests = await listClientRequests(req.user.uid);
  res.status(200).json({ requests });
});

app.post("/api/client/sessions", requireFirebaseAuth, async (req, res) => {
  try {
    const trainerId = String(req.body.trainerId || "").trim();
    const startTime = String(req.body.startTime || "").trim();
    const durationMin = Number(req.body.durationMin) || 60;

    const trainer = await getTrainer(trainerId);
    if (!trainer || trainer.status !== "approved") {
      res.status(400).json({ error: "Selected trainer is unavailable" });
      return;
    }

    const clientRequests = await listClientRequests(req.user.uid);
    const hasAcceptedMatch = clientRequests.some(
      (request) => request.trainerId === trainer.id && request.status === "accepted"
    );
    if (!hasAcceptedMatch) {
      res.status(403).json({ error: "You need an accepted match with this trainer before booking a session" });
      return;
    }

    const session = await createBookedSession({
      trainerId: trainer.id,
      trainerName: trainer.name,
      clientUid: req.user.uid,
      clientEmail: req.user.email || "",
      clientName: String(req.body.clientName || "").trim(),
      startTime,
      durationMin,
    });

    if (trainer.email) {
      sendEmail(
        trainer.email,
        "New session booked on MONTRA",
        sessionBookedEmailHtml(trainer.name, session.clientName, startTime)
      ).catch((e) => console.error("Failed to send session-booked email:", e.message));
    }

    // Push to trainer
    if (trainer.accountUid) {
      const dateLabel = new Date(startTime).toLocaleString("en-US", {
        weekday: "short", month: "short", day: "numeric", hour: "numeric", minute: "2-digit",
      });
      sendPushToUid(trainer.accountUid, {
        title: "New Session Booked",
        body: `${session.clientName || "A client"} booked a session for ${dateLabel}.`,
        data: { category: "session", sessionId: session.id },
      }).catch(() => {});
    }

    // Booking unlocks an Impact Credit the client can later direct to a cause.
    // Best-effort: never let credit creation block a successful booking.
    let impactCredit = null;
    try {
      impactCredit = await createImpactCredit({ clientUid: req.user.uid, sessionId: session.id });
    } catch (e) {
      console.error("Failed to unlock impact credit:", e.message);
    }

    res.status(201).json({ session, impactCredit });
  } catch (error) {
    res.status(400).json({ error: error.message || "Unable to book session" });
  }
});

app.get("/api/client/sessions", requireFirebaseAuth, async (req, res) => {
  const sessions = await listClientSessions(req.user.uid);
  res.status(200).json({ sessions });
});

// MARK: Impact Credits — unlocked at booking, directed to a cause by the client.

app.get("/api/client/impact-credits", requireFirebaseAuth, async (req, res) => {
  const impactCredits = await listClientCredits(req.user.uid);
  res.status(200).json({ impactCredits });
});

app.post("/api/client/impact-credits/:id/direct", requireFirebaseAuth, async (req, res) => {
  try {
    const credit = await getCredit(req.params.id);
    if (!credit) {
      res.status(404).json({ error: "Impact credit not found" });
      return;
    }
    if (credit.clientUid !== req.user.uid) {
      res.status(403).json({ error: "Not your impact credit" });
      return;
    }
    if (credit.status === "directed") {
      res.status(409).json({ error: "This impact credit has already been directed" });
      return;
    }

    const updated = await directCredit(req.params.id, {
      type: req.body.type,
      causeId: req.body.causeId,
      giftEmail: req.body.giftEmail,
    });
    res.status(200).json({ impactCredit: updated });
  } catch (error) {
    res.status(400).json({ error: error.message || "Unable to direct impact credit" });
  }
});

// Public aggregate for the community-impact panel (usable by app + website).
app.get("/api/impact/community", async (_req, res) => {
  try {
    const community = await getCommunityImpact();
    res.status(200).json({ community });
  } catch (error) {
    res.status(500).json({ error: "Unable to load community impact" });
  }
});

app.post("/api/client/sessions/:id/cancel", requireFirebaseAuth, async (req, res) => {
  const existing = await getBookedSession(req.params.id);
  if (!existing) {
    res.status(404).json({ error: "Session not found" });
    return;
  }

  if (existing.clientUid !== req.user.uid) {
    res.status(403).json({ error: "Not your session" });
    return;
  }

  const session = await cancelBookedSession(req.params.id);

  // Push to the trainer. session.trainerId is the trainer *profile* doc id,
  // so resolve via getTrainer (not getTrainerByAccountUid, which expects a uid).
  const cancelledTrainer = await getTrainer(session.trainerId);
  if (cancelledTrainer?.accountUid) {
    sendPushToUid(cancelledTrainer.accountUid, {
      title: "Session Cancelled",
      body: `${session.clientName || "Your client"} cancelled their session.`,
      data: { category: "session", sessionId: session.id },
    }).catch(() => {});
  }

  res.status(200).json({ session });
});

app.post("/api/client/sessions/:id/complete", requireFirebaseAuth, async (req, res) => {
  const existing = await getBookedSession(req.params.id);
  if (!existing) {
    res.status(404).json({ error: "Session not found" });
    return;
  }

  if (existing.clientUid !== req.user.uid) {
    res.status(403).json({ error: "Not your session" });
    return;
  }

  if (existing.status === "cancelled") {
    res.status(409).json({ error: "Cannot complete a cancelled session" });
    return;
  }

  if (Date.parse(existing.startTime) > Date.now()) {
    res.status(409).json({ error: "Cannot complete a session that hasn't started yet" });
    return;
  }

  const session = await completeBookedSession(req.params.id, { notes: req.body?.notes });

  // Push to the trainer. session.trainerId is the trainer profile doc id.
  const completedTrainer = await getTrainer(session.trainerId);
  if (completedTrainer?.accountUid) {
    sendPushToUid(completedTrainer.accountUid, {
      title: "Session Completed",
      body: `${session.clientName || "Your client"} marked their session as complete.`,
      data: { category: "session", sessionId: session.id },
    }).catch(() => {});
  }

  res.status(200).json({ session });
});

// A client leaves a verified review for a coach they trained with. The review
// is anchored to a completed session, so every review on the platform is real.
app.post("/api/client/reviews", requireFirebaseAuth, async (req, res) => {
  const sessionId = String(req.body?.sessionId || "").trim();
  const session = await getBookedSession(sessionId);
  if (!session) {
    res.status(404).json({ error: "Session not found" });
    return;
  }

  if (session.clientUid !== req.user.uid) {
    res.status(403).json({ error: "Not your session" });
    return;
  }

  if (session.status !== "completed") {
    res.status(409).json({ error: "You can review a coach after the session is completed" });
    return;
  }

  try {
    const review = await createReview({
      trainerId: session.trainerId,
      sessionId: session.id,
      clientUid: req.user.uid,
      clientName: session.clientName,
      rating: req.body?.rating,
      text: req.body?.text,
    });

    const reviewedTrainer = await getTrainer(session.trainerId);
    if (reviewedTrainer?.accountUid) {
      sendPushToUid(reviewedTrainer.accountUid, {
        title: "New Review",
        body: `${session.clientName || "A client"} left you a ${review.rating}★ review.`,
        data: { category: "review", trainerId: session.trainerId },
      }).catch(() => {});
    }

    res.status(201).json({ review });
  } catch (err) {
    const status = err.code === "duplicate" ? 409 : err.code === "not_found" ? 404 : 400;
    res.status(status).json({ error: err.message || "Could not save review" });
  }
});

app.get("/api/client/progress", requireFirebaseAuth, async (req, res) => {
  const progress = await getClientProgress(req.user.uid);
  res.status(200).json({ progress });
});

app.post("/api/client/progress", requireFirebaseAuth, async (req, res) => {
  const progress = await saveClientProgress(req.user.uid, req.body || {});
  res.status(200).json({ progress });
});

app.get("/api/client/progress/weight-history", requireFirebaseAuth, async (req, res) => {
  const weightLog = await getWeightHistory(req.user.uid);
  res.status(200).json({ weightLog });
});

app.post("/api/client/progress/weight-entry", requireFirebaseAuth, async (req, res) => {
  try {
    const result = await addWeightEntry(req.user.uid, {
      weight: req.body?.weight,
      date: req.body?.date,
    });
    res.status(201).json({ progress: result, weightLog: result.weightLog });
  } catch (error) {
    res.status(400).json({ error: error.message || "Unable to record weight" });
  }
});

app.get("/api/notifications/my", requireFirebaseAuth, async (req, res) => {
  try {
    const trainer = await getTrainerByAccountUid(req.user.uid);
    const notifications = [];

    if (trainer) {
      const [matches, conversations, sessions] = await Promise.all([
        listTrainerMatches(trainer.id),
        listConversationsForTrainer(trainer.id),
        listTrainerSessions(trainer.id),
      ]);

      for (const match of matches) {
        if (match.status === "pending") {
          notifications.push({
            id: `req_${match.id}`,
            title: "New client request",
            detail: `${match.clientProfile?.firstName || "A new client"} requested you as their coach.`,
            createdAt: match.updatedAt || match.createdAt || "",
            unread: true,
            category: "request",
          });
        }
      }

      const nowIso = new Date().toISOString();
      for (const session of sessions) {
        if (session.status === "scheduled" && session.startTime > nowIso) {
          notifications.push({
            id: `sess_${session.id}`,
            title: "New session booked",
            detail: `${session.clientName || "A client"} booked a session for ${session.startTime}.`,
            createdAt: session.createdAt || "",
            unread: true,
            category: "session",
          });
        }
      }

      for (const convo of conversations) {
        if (convo.lastMessage && convo.lastSenderRole === "client") {
          notifications.push({
            id: `msg_${convo.id}`,
            title: `New message from ${convo.clientName || "your client"}`,
            detail: convo.lastMessage,
            createdAt: convo.lastMessageAt || convo.updatedAt || "",
            unread: true,
            category: "message",
          });
        }
      }
    } else {
      const [requests, conversations] = await Promise.all([
        listClientRequests(req.user.uid),
        listConversationsForClient(req.user.uid),
      ]);

      for (const request of requests) {
        if (request.status === "accepted") {
          notifications.push({
            id: `acc_${request.id}`,
            title: "Your coach accepted",
            detail: `${request.trainerName || "Your coach"} accepted your request. You can start chatting now.`,
            createdAt: request.updatedAt || request.createdAt || "",
            unread: true,
            category: "request",
          });
        }
      }

      for (const convo of conversations) {
        if (convo.lastMessage && convo.lastSenderRole === "trainer") {
          notifications.push({
            id: `msg_${convo.id}`,
            title: `New message from ${convo.trainerName || "your coach"}`,
            detail: convo.lastMessage,
            createdAt: convo.lastMessageAt || convo.updatedAt || "",
            unread: true,
            category: "message",
          });
        }
      }
    }

    notifications.sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
    res.status(200).json({ notifications });
  } catch (error) {
    console.error("Failed to build notifications:", error.message);
    res.status(200).json({ notifications: [] });
  }
});

app.get("/api/conversations/my-threads", requireFirebaseAuth, async (req, res) => {
  const trainer = await getTrainerByAccountUid(req.user.uid);
  if (trainer) {
    const conversations = await listConversationsForTrainer(trainer.id);
    res.status(200).json({ conversations, role: "trainer" });
    return;
  }

  const conversations = await listConversationsForClient(req.user.uid);
  res.status(200).json({ conversations, role: "client" });
});

app.get("/api/conversations/:conversationId/messages", requireFirebaseAuth, async (req, res) => {
  const conversation = await getConversation(req.params.conversationId);
  if (!conversation) {
    res.status(404).json({ error: "Conversation not found" });
    return;
  }

  const trainer = await getTrainerByAccountUid(req.user.uid);
  const canAccess =
    conversation.clientUid === req.user.uid ||
    (trainer && trainer.id === conversation.trainerId);

  if (!canAccess) {
    res.status(403).json({ error: "Conversation access denied" });
    return;
  }

  const messages = await listConversationMessages(conversation.id);
  res.status(200).json({ conversation, messages });
});

app.post("/api/conversations/:conversationId/messages", requireFirebaseAuth, async (req, res) => {
  const conversation = await getConversation(req.params.conversationId);
  if (!conversation) {
    res.status(404).json({ error: "Conversation not found" });
    return;
  }

  const trainer = await getTrainerByAccountUid(req.user.uid);
  const canAccess =
    conversation.clientUid === req.user.uid ||
    (trainer && trainer.id === conversation.trainerId);

  if (!canAccess) {
    res.status(403).json({ error: "Conversation access denied" });
    return;
  }

  const senderRole = trainer && trainer.id === conversation.trainerId ? "trainer" : "client";
  const senderName =
    senderRole === "trainer"
      ? trainer?.name || req.user.name || req.user.email || "Trainer"
      : req.user.name || req.user.email || "Client";

  try {
    const message = await sendConversationMessage({
      conversationId: conversation.id,
      senderUid: req.user.uid,
      senderRole,
      senderName,
      text: String(req.body?.text || "").trim(),
    });

    const recipientEmail =
      senderRole === "trainer"
        ? conversation.clientEmail
        : trainer?.email || "";

    if (recipientEmail) {
      sendEmail(
        recipientEmail,
        "New MONTRA message",
        chatMessageEmailHtml(senderName, message.text)
      ).catch((error) => console.error("Failed to send chat notification email:", error.message));
    }

    // Push to the recipient
    const recipientUid = senderRole === "trainer" ? conversation.clientUid : trainer?.accountUid;
    if (recipientUid) {
      sendPushToUid(recipientUid, {
        title: `Message from ${senderName}`,
        body: message.text.length > 100 ? message.text.slice(0, 97) + "…" : message.text,
        data: { category: "message", conversationId: conversation.id },
      }).catch(() => {});
    }

    res.status(201).json({ message });
  } catch (error) {
    res.status(400).json({ error: error.message || "Unable to send message" });
  }
});

app.get("/api/admin/trainer-applications", requireFirebaseAuth, requireAdmin, async (req, res) => {
  const status = String(req.query.status || "").trim().toLowerCase();
  const statuses = status ? [status] : ["pending", "approved", "rejected"];
  const trainers = await listTrainers({ includeInactive: true, statuses });
  const applications = trainers.map((trainer) => ({
    trainer,
    hiringEvaluation: evaluateTrainerApplication(trainer),
  }));
  res.status(200).json({ applications });
});

app.post("/api/admin/trainers/:id/approve", requireFirebaseAuth, requireAdmin, async (req, res) => {
  const trainer = await approveTrainer(req.params.id);
  if (!trainer) {
    res.status(404).json({ error: "Trainer not found" });
    return;
  }

  await finalizeTrainerApproval(trainer, "admin-approve-trainer");

  res.status(200).json({ trainer });
});

// Records admin-confirmed vetting outcomes. These — not approval alone — gate the
// "ID Verified" / "Background Checked" / "MONTRA Certified™" trust badges so the
// platform never claims a check it didn't actually perform.
app.post("/api/admin/trainers/:id/verification", requireFirebaseAuth, requireAdmin, async (req, res) => {
  const allowed = ["idVerified", "backgroundCheckCleared", "montraCertified"];
  const flags = {};
  for (const key of allowed) {
    if (typeof req.body?.[key] === "boolean") flags[key] = req.body[key];
  }
  if (Object.keys(flags).length === 0) {
    res.status(400).json({ error: `Provide at least one boolean flag: ${allowed.join(", ")}` });
    return;
  }
  const trainer = await setTrainerVerification(req.params.id, flags);
  if (!trainer) {
    res.status(404).json({ error: "Trainer not found" });
    return;
  }
  res.status(200).json({ trainer });
});

app.post("/api/admin/trainers/:id/reject", requireFirebaseAuth, requireAdmin, async (req, res) => {
  const trainer = await rejectTrainer(req.params.id);
  if (!trainer) {
    res.status(404).json({ error: "Trainer not found" });
    return;
  }
  if (trainer.email) {
    const evaluation = evaluateTrainerApplication(trainer);
    sendEmail(trainer.email, "Your MONTRA trainer application", rejectionEmailHtml(trainer.name, evaluation.concerns))
      .catch((e) => console.error("Failed to send rejection email:", e.message));
  }
  res.status(200).json({ trainer });
});

app.post("/api/admin/trainers", requireFirebaseAuth, requireAdmin, async (req, res) => {
  try {
    const trainer = await createTrainer(req.body || {});
    res.status(201).json({ trainer });
  } catch (error) {
    res.status(400).json({ error: error.message || "Unable to create trainer" });
  }
});

app.put("/api/admin/trainers/:id", requireFirebaseAuth, requireAdmin, async (req, res) => {
  try {
    const trainer = await updateTrainer(req.params.id, req.body || {});
    if (!trainer) {
      res.status(404).json({ error: "Trainer not found" });
      return;
    }
    res.status(200).json({ trainer });
  } catch (error) {
    res.status(400).json({ error: error.message || "Unable to update trainer" });
  }
});

app.delete("/api/admin/trainers/:id", requireFirebaseAuth, requireAdmin, async (req, res) => {
  const deleted = await deleteTrainer(req.params.id);
  if (!deleted) {
    res.status(404).json({ error: "Trainer not found" });
    return;
  }
  res.status(204).send();
});

app.post("/api/ai/coach-suggestion", requireFirebaseAuth, (req, res) => {
  const goal = String(req.body.goal || "General Fitness").trim() || "General Fitness";
  const mood = String(req.body.mood || "Focused").trim() || "Focused";
  const availability = Array.isArray(req.body.availability)
    ? req.body.availability.filter(Boolean)
    : [];

  const lines = [
    `Today, prioritize a ${goal.toLowerCase()} session with clear form cues and moderate intensity.`,
    `Your mood marker is ${mood.toLowerCase()}, so start with a 5-minute ramp-up and then progress load gradually.`,
    availability.length > 0
      ? `Best scheduling window this week: ${availability.slice(0, 3).join(", ")}.`
      : "No schedule preference supplied, so default to 3 evenly spaced sessions this week.",
  ];

  res.status(200).json({
    model: "montra-rules-v1",
    suggestion: lines.join(" "),
  });
});

// Admin-only endpoint to test Resend integration without going through a full trainer flow
app.post("/api/admin/test-email", requireFirebaseAuth, requireAdmin, async (req, res) => {
  const to = String(req.body.to || req.user.email || "").trim();
  if (!to) {
    return res.status(400).json({ error: "Provide a 'to' email address in the request body" });
  }
  try {
    await sendEmail(
      to,
      "MONTRA — Email Test",
      `<!DOCTYPE html><html><body style="background:#0a0a0a;font-family:sans-serif;padding:48px 24px">
        <p style="color:#FF6820;font-size:11px;font-weight:700;letter-spacing:2px">MONTRA</p>
        <h1 style="color:#fff;font-size:24px">Email test successful</h1>
        <p style="color:#ccc;font-size:15px">If you are reading this, Resend is correctly configured and sending from the verified domain.</p>
        <p style="color:#555;font-size:11px">MONTRA &middot; Powered by Elite Home Fitness</p>
      </body></html>`
    );
    res.status(200).json({ ok: true, to, from: process.env.FROM_EMAIL || "MONTRA <noreply@montra.com>" });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

// Admin-only cleanup endpoint for test accounts in Auth + trainer records.
app.post("/api/admin/cleanup-test-accounts", requireFirebaseAuth, requireAdmin, async (_req, res) => {
  const targets = [
    "aaronhwitz@gmail.com",
    "horwina@gmail.com",
    "aaronhorowitz97@gmail.com",
  ];

  const report = [];
  const db = getFirestore();
  const auth = getAuth();

  for (const email of targets) {
    const item = { email, authDeleted: false, trainerDocsDeleted: 0 };

    try {
      const user = await auth.getUserByEmail(email);
      await auth.deleteUser(user.uid);
      item.authDeleted = true;
    } catch (error) {
      if (error.code !== "auth/user-not-found") {
        item.authError = error.message;
      }
    }

    try {
      const snapshot = await db.collection("trainers").where("email", "==", email).get();
      for (const doc of snapshot.docs) {
        await doc.ref.delete();
      }
      item.trainerDocsDeleted = snapshot.size;
    } catch (error) {
      item.firestoreError = error.message;
    }

    report.push(item);
  }

  res.status(200).json({ ok: true, cleaned: report });
});

// ─── STRIPE PAYMENT ROUTES ────────────────────────────────────────────────────

// Webhook MUST be registered before express.json() to get the raw body.
// We use express.raw() scoped to just this route.
app.post(
  "/api/stripe/webhook",
  express.raw({ type: "application/json" }),
  async (req, res) => {
    const sig = req.headers["stripe-signature"];
    let event;
    try {
      event = constructWebhookEvent(req.body, sig);
    } catch (err) {
      console.error("Stripe webhook signature error:", err.message);
      res.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }
    const db = getFirestore();

    // One-time intro session confirmed
    if (event.type === "payment_intent.succeeded") {
      const pi = event.data.object;
      const { type, trainerId, trainerName } = pi.metadata;
      if (type === "intro_session") {
        db.collection("payments").add({
          stripePaymentIntentId: pi.id,
          amountCents: pi.amount,
          currency: pi.currency,
          type: "intro_session",
          status: "paid",
          paidAt: new Date().toISOString(),
          trainerId, trainerName,
        }).catch((e) => console.error("payment record:", e.message));
      }
    }

    // Subscription invoice paid — first payment or monthly renewal
    if (event.type === "invoice.paid") {
      const invoice = event.data.object;
      const subId = invoice.subscription;
      if (!subId) { res.json({ received: true }); return; }

      // Find our Firestore subscription record and mark active
      const subSnap = await db.collection("subscriptions")
        .where("stripeSubscriptionId", "==", subId).limit(1).get();

      const now = new Date().toISOString();
      const periodEnd = invoice.lines?.data?.[0]?.period?.end
        ? new Date(invoice.lines.data[0].period.end * 1000).toISOString()
        : null;

      if (!subSnap.empty) {
        subSnap.docs[0].ref.update({ status: "active", currentPeriodEnd: periodEnd, lastPaidAt: now })
          .catch((e) => console.error("sub update:", e.message));
      }

      // Record each invoice payment
      db.collection("payments").add({
        stripeInvoiceId: invoice.id,
        stripeSubscriptionId: subId,
        amountCents: invoice.amount_paid,
        currency: invoice.currency,
        type: "program_subscription_payment",
        status: "paid",
        paidAt: now,
        periodEnd,
      }).catch((e) => console.error("invoice payment record:", e.message));
    }

    // Subscription invoice payment failed — mark past_due
    if (event.type === "invoice.payment_failed") {
      const invoice = event.data.object;
      const subId = invoice.subscription;
      if (subId) {
        const subSnap = await db.collection("subscriptions")
          .where("stripeSubscriptionId", "==", subId).limit(1).get();
        if (!subSnap.empty) {
          subSnap.docs[0].ref.update({ status: "past_due" })
            .catch((e) => console.error("sub past_due:", e.message));
        }
      }
    }

    // Subscription deleted (cancelled or lapsed after failed payments)
    if (event.type === "customer.subscription.deleted") {
      const sub = event.data.object;
      const subSnap = await db.collection("subscriptions")
        .where("stripeSubscriptionId", "==", sub.id).limit(1).get();
      if (!subSnap.empty) {
        subSnap.docs[0].ref.update({ status: "cancelled", cancelledAt: new Date().toISOString() })
          .catch((e) => console.error("sub cancelled:", e.message));
      }
    }

    res.json({ received: true });
  }
);

// Publishable key — safe to expose; lets the client init Stripe.js
app.get("/api/stripe/config", (_req, res) => {
  try {
    res.json({ publishableKey: getPublishableKey() });
  } catch (_) {
    // Return a placeholder so the UI can still render; card submit will fail until
    // STRIPE_PUBLISHABLE_KEY is set in Railway env.
    res.json({ publishableKey: null, unconfigured: true });
  }
});

// Create a PaymentIntent for an intro session booking
app.post("/api/payments/intro-session", async (req, res) => {
  try {
    const { trainerId, customerEmail } = req.body;
    if (!trainerId) { res.status(400).json({ error: "trainerId required" }); return; }
    const pkg = await getTrainerPackages(trainerId);
    if (!pkg) { res.status(404).json({ error: "Trainer not found" }); return; }
    const amountCents = Math.round((pkg.introSession?.price || 149) * 100);
    const trainer = { name: "" };
    const t = await (await import("./trainerStore.js")).getTrainer(trainerId);
    const result = await createIntroSessionIntent({
      trainerId,
      trainerName: t?.name || "",
      amountCents,
      customerEmail,
    });
    res.json(result);
  } catch (err) {
    console.error("intro-session intent:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// Create a recurring Stripe Subscription for a coaching program purchase.
// The returned clientSecret is from the subscription's first invoice PaymentIntent
// and works identically with Stripe PaymentSheet / Payment Element on iOS + web.
app.post("/api/payments/program", async (req, res) => {
  try {
    const { trainerId, months, freqPerWeek, customerEmail, customerName } = req.body;
    if (!trainerId || !months) { res.status(400).json({ error: "trainerId + months required" }); return; }
    if (!customerEmail) { res.status(400).json({ error: "customerEmail required for subscriptions" }); return; }

    const pkg = await getTrainerPackages(trainerId);
    if (!pkg) { res.status(404).json({ error: "Trainer not found" }); return; }
    const commitment = (pkg.commitments || []).find((c) => c.months === Number(months));
    if (!commitment) { res.status(400).json({ error: "Invalid program tier" }); return; }

    const freq = Number(freqPerWeek) || commitment.defaultFreq;
    const monthly = commitment.monthlyFrom + Math.max(0, freq - 1) * commitment.freqStep;
    const amountCents = Math.round(monthly * 100);
    const t = await (await import("./trainerStore.js")).getTrainer(trainerId);

    // Try to get the authenticated client's uid (optional — web may be unauthenticated)
    let clientUid = null;
    const authHeader = req.headers.authorization;
    if (authHeader?.startsWith("Bearer ")) {
      try {
        const decoded = await getAuth().verifyIdToken(authHeader.slice(7));
        clientUid = decoded.uid;
      } catch { /* unauthenticated web client — ok */ }
    }

    const result = await createProgramSubscription({
      trainerId,
      trainerName: t?.name || "",
      programTitle: commitment.title,
      months: Number(months),
      freqPerWeek: freq,
      amountCents,
      freeIntro: true,
      customerEmail,
      customerName: customerName || "",
    });

    // Create Firestore subscription record (status=pending until invoice.paid fires)
    const db = getFirestore();
    await db.collection("subscriptions").add({
      stripeSubscriptionId: result.subscriptionId,
      stripeCustomerId: result.customerId,
      clientUid,
      customerEmail,
      trainerId,
      trainerName: t?.name || "",
      programTitle: commitment.title,
      months: Number(months),
      freqPerWeek: freq,
      monthlyAmountCents: amountCents,
      freeIntro: true,
      status: "pending",
      createdAt: new Date().toISOString(),
      currentPeriodEnd: null,
    });

    res.json({
      ...result,
      monthly,
      programTitle: commitment.title,
      freeIntro: true,
      introSessionPrice: pkg.introSession?.price,
    });
  } catch (err) {
    console.error("program subscription:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// List active subscriptions for the authenticated client
app.get("/api/client/subscriptions", requireFirebaseAuth, async (req, res) => {
  const db = getFirestore();
  // Single-field filter only — filter + sort in JS to avoid a composite index
  const snap = await db.collection("subscriptions")
    .where("clientUid", "==", req.user.uid)
    .get();
  const active = snap.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .filter((s) => ["pending", "active", "past_due"].includes(s.status))
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  res.json({ subscriptions: active });
});

// Cancel a subscription at end of current billing period
app.delete("/api/client/subscriptions/:subscriptionId", requireFirebaseAuth, async (req, res) => {
  const db = getFirestore();
  const snap = await db.collection("subscriptions")
    .where("stripeSubscriptionId", "==", req.params.subscriptionId)
    .where("clientUid", "==", req.user.uid)
    .limit(1).get();

  if (snap.empty) { res.status(404).json({ error: "Subscription not found or not yours" }); return; }
  const sub = snap.docs[0].data();
  if (sub.status === "cancelled") { res.status(409).json({ error: "Already cancelled" }); return; }

  await cancelSubscription(req.params.subscriptionId);
  await snap.docs[0].ref.update({ cancelAtPeriodEnd: true });
  res.json({ ok: true, message: "Subscription will cancel at end of current billing period" });
});

// ─── SESSION BOOKING ──────────────────────────────────────────────────────────

// Available time slots for a coach on a given date (deterministic for now;
// real availability from the coach's calendar when scheduling is integrated).
app.get("/api/trainers/:id/availability", async (req, res) => {
  try {
    const trainer = await getTrainer(req.params.id);
    if (!trainer) { res.status(404).json({ error: "Trainer not found" }); return; }
    const dateStr = req.query.date; // YYYY-MM-DD
    if (!dateStr || !/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) {
      res.status(400).json({ error: "date required (YYYY-MM-DD)" }); return;
    }
    // Derive available slots from working hours if present; otherwise default 8am–5pm
    const wh = trainer.workingHours || {};
    const parseHour = (t) => {
      if (!t) return null;
      const m = /^(\d{1,2}):(\d{2})\s*(AM|PM)$/i.exec(t.trim());
      if (!m) return null;
      let h = Number(m[1]) % 12;
      if (/pm/i.test(m[3])) h += 12;
      return h;
    };
    const startH = parseHour(wh.start) ?? 8;
    const endH = parseHour(wh.end) ?? 17;
    const slots = [];
    for (let h = startH; h < endH; h++) {
      slots.push(`${h === 12 ? 12 : h % 12}:00 ${h < 12 ? "AM" : "PM"}`);
      if (h + 0.5 < endH) slots.push(`${h === 12 ? 12 : h % 12}:30 ${h < 12 ? "AM" : "PM"}`);
    }
    // Mark a few slots as unavailable using deterministic seeded hash so it feels real
    const dayHash = Array.from(dateStr).reduce((a, c) => a ^ c.charCodeAt(0), 0);
    const available = slots.filter((_, i) => ((dayHash + i * 7) % 5) !== 0);
    res.json({ date: dateStr, slots: available, timezone: "ET" });
  } catch (err) {
    console.error("availability:", err.message);
    res.status(500).json({ error: "Could not load availability" });
  }
});

// Book an intro session — records in Firestore, links to a payment intent
app.post("/api/bookings/intro-session", async (req, res) => {
  try {
    const { trainerId, clientName, clientEmail, clientPhone, date, time, address, addressType, paymentIntentId } = req.body;
    if (!trainerId || !date || !time || !clientName || !clientPhone) {
      res.status(400).json({ error: "trainerId, date, time, clientName, clientPhone required" }); return;
    }
    const trainer = await getTrainer(trainerId);
    if (!trainer) { res.status(404).json({ error: "Trainer not found" }); return; }
    const db = getFirestore();
    const booking = {
      type: "intro_session",
      trainerId,
      trainerName: trainer.name,
      clientName, clientEmail: clientEmail || null, clientPhone,
      date, time,
      address: address || null, addressType: addressType || null,
      paymentIntentId: paymentIntentId || null,
      status: "confirmed",
      createdAt: new Date().toISOString(),
    };
    const ref = await db.collection("bookedSessions").add(booking);
    res.status(201).json({ bookingId: ref.id, ...booking });
  } catch (err) {
    console.error("intro booking:", err.message);
    res.status(500).json({ error: "Could not book session" });
  }
});

app.listen(port, () => {
  console.log(`montra-backend listening on ${port}`);
});
