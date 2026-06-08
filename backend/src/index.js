import "dotenv/config";
import cors from "cors";
import express from "express";
import { getAuth, initFirebaseAdmin } from "./firebase.js";
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

app.use(express.json());
app.use(
  cors({
    origin: allowedOrigins.length ? allowedOrigins : true,
  })
);

initFirebaseAdmin();

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
  res.status(200).json({ trainer });
});

app.post("/api/admin/trainers/:id/reject", requireFirebaseAuth, requireAdmin, async (req, res) => {
  const trainer = await rejectTrainer(req.params.id);
  if (!trainer) {
    res.status(404).json({ error: "Trainer not found" });
    return;
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
