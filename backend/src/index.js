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
  listTrainers,
  matchTrainers,
  rejectTrainer,
  upsertTrainerForAccount,
  updateTrainer,
} from "./trainerStore.js";
import {
  createMatchRequest,
  listClientRequests,
  listTrainerMatches,
} from "./matchStore.js";

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

app.use(express.json({ limit: "5mb" }));
app.use(
  cors({
    origin: allowedOrigins.length ? allowedOrigins : true,
  })
);

initFirebaseAdmin();

// ── Email helpers ─────────────────────────────────────────────────────────────

async function sendEmail(to, subject, html) {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    console.log(`[Email skipped — set RESEND_API_KEY] To: ${to} | ${subject}`);
    return;
  }
  const from = process.env.FROM_EMAIL || "MONTRA <noreply@montrafit.com>";
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from, to: [to], subject, html }),
  });
  if (!res.ok) throw new Error(`Resend error: ${await res.text()}`);
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

app.get("/", (_req, res) => {
  res.status(200).json({ ok: true, service: "montra-backend" });
});

app.get("/health", (_req, res) => {
  res.status(200).json({ ok: true, service: "montra-backend" });
});

app.get("/api/firebase/client-config", (_req, res) => {
  res.status(200).json({
    apiKey: process.env.FIREBASE_WEB_API_KEY || "",
    authDomain: process.env.FIREBASE_AUTH_DOMAIN || "",
    appId: process.env.FIREBASE_APP_ID || "",
    projectId: process.env.FIREBASE_PROJECT_ID || "",
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

// DEV ONLY — remove after testing
app.post("/api/dev/create-test-trainer", async (req, res) => {
  if (process.env.NODE_ENV === "production" && !process.env.ALLOW_DEV_ENDPOINTS) {
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
  if (process.env.NODE_ENV === "production" && !process.env.ALLOW_DEV_ENDPOINTS) {
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

app.post("/api/trainers/provision", async (req, res) => {
  try {
    const { firstName, lastName, email, phone, specialties, certifications, coachingStyle, experienceYears } = req.body || {};

    if (!firstName || !lastName || !email) {
      res.status(400).json({ error: "firstName, lastName, and email are required" });
      return;
    }

    const name = `${String(firstName).trim()} ${String(lastName).trim()}`;
    const normalizedEmail = String(email).trim().toLowerCase();

    const trainer = await createTrainer({
      name,
      email: normalizedEmail,
      phone: String(phone || "").trim(),
      specialties: Array.isArray(specialties) ? specialties : [],
      certification: String(certifications || "").trim(),
      bio: String(coachingStyle || "").trim(),
      status: "pending",
      experienceYears: Number.isFinite(Number(experienceYears)) ? Number(experienceYears) : 0,
    });

    res.status(201).json({ ok: true, applicationId: trainer.id });
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

app.get("/api/trainers", async (req, res) => {
  const includeInactive = req.query.includeInactive === "true";
  const trainers = await listTrainers({ includeInactive });
  res.status(200).json({ trainers });
});

app.get("/api/trainers/:id", async (req, res) => {
  const trainer = await getTrainer(req.params.id);
  if (!trainer) {
    res.status(404).json({ error: "Trainer not found" });
    return;
  }
  res.status(200).json({ trainer });
});

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

    res.status(201).json({ request });
  } catch (error) {
    res.status(400).json({ error: error.message || "Unable to create request" });
  }
});

app.get("/api/client/requests", requireFirebaseAuth, async (req, res) => {
  const requests = await listClientRequests(req.user.uid);
  res.status(200).json({ requests });
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

  // Provision Firebase Auth account if not yet created
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
          await updateTrainer(trainer.id, { accountUid: existing.uid });
          trainer.accountUid = existing.uid;
        } catch (e) {
          console.error("Failed to resolve existing auth user:", e.message);
        }
      } else {
        console.error("Failed to provision trainer auth account:", authError.message);
      }
    }
  }

  // Set trainer role claim so iOS routes to TrainerTabView
  if (trainer.accountUid) {
    try {
      await getAuth().setCustomUserClaims(trainer.accountUid, { role: "trainer" });
    } catch (claimError) {
      console.error("Failed to set trainer custom claim:", claimError.message);
    }
  }

  // Send approval email with password-reset + onboarding link
  if (trainer.email) {
    try {
      const onboardingUrl = `${process.env.WEBSITE_URL || "https://montra-27532.web.app"}/trainer-onboarding.html`;
      const resetLink = await getAuth().generatePasswordResetLink(trainer.email, { url: onboardingUrl });
      await sendEmail(trainer.email, "You're approved — welcome to MONTRA!", approvalEmailHtml(trainer.name, resetLink));
    } catch (emailError) {
      console.error("Failed to send approval email:", emailError.message);
      // Fallback: Firebase generic password reset
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

app.listen(port, () => {
  console.log(`montra-backend listening on ${port}`);
});
