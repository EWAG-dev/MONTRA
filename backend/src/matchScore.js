// MONTRA Match scoring — server-side port of website/assets/js/montra-match.js so the
// iOS app (and anything else) can get the exact same overall % + per-factor breakdown
// from one backend source of truth, scored against the FULL trainer record. Keep this
// in sync with montra-match.js if the web algorithm changes.

function hashId(id) {
  let h = 2166136261;
  const s = String(id || "");
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}
function seeded(id, salt, min, max) {
  const h = hashId(`${id}:${salt}`);
  return min + (h % (max - min + 1));
}
const clamp = (n) => Math.max(0, Math.min(100, Math.round(n)));

const GOAL_KEYWORDS = {
  "Build Muscle": ["build muscle", "strength", "muscle", "personal training"],
  "Lose Weight": ["lose weight", "weight loss", "weight", "fat loss"],
  "Flexibility & Wellness": ["flexibility", "wellness", "mobility", "yoga", "pilates", "stretch"],
  "Athletic Performance": ["athletic performance", "performance", "sports", "conditioning", "strength"],
  "Combat Sports": ["combat sports", "boxing", "kickboxing", "combat"],
  "General Fitness": ["general fitness", "personal training", "fitness"],
};

function normalizeToken(value) {
  return String(value || "").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}
function trainerText(trainer) {
  return normalizeToken([...(trainer.specialties || []), trainer.certification || ""].join(" "));
}
function matchesLocationToken(trainerLocations, location) {
  if (!location) return null;
  if (!Array.isArray(trainerLocations) || !trainerLocations.length) return null;
  const target = normalizeToken(location).replace(/\s+/g, "");
  return trainerLocations.some((loc) => {
    const candidate = normalizeToken(loc).replace(/\s+/g, "");
    return candidate.includes(target) || target.includes(candidate);
  });
}
function parseTimeToMinutes(value) {
  const m = /^(\d{1,2}):(\d{2})\s*(AM|PM)$/i.exec(String(value || "").trim());
  if (!m) return null;
  let hours = Number(m[1]) % 12;
  if (/pm/i.test(m[3])) hours += 12;
  return hours * 60 + Number(m[2]);
}
const DAY_PART_WINDOWS = {
  "Early Morning": [0, 9 * 60],
  Morning: [9 * 60, 12 * 60],
  Afternoon: [12 * 60, 17 * 60],
  Evening: [17 * 60, 24 * 60],
};
function workingHoursOverlapsDayPart(workingHours, dayPart) {
  const w = DAY_PART_WINDOWS[dayPart];
  if (!w || !workingHours?.start || !workingHours?.end) return null;
  const start = parseTimeToMinutes(workingHours.start);
  const end = parseTimeToMinutes(workingHours.end);
  if (start === null || end === null) return null;
  return start < w[1] && end > w[0];
}

function goalFit(trainer, prefs) {
  if (!prefs?.goal) return seeded(trainer.id, "goal", 82, 92);
  const text = trainerText(trainer);
  const keywords = GOAL_KEYWORDS[prefs.goal] || [normalizeToken(prefs.goal)];
  return keywords.some((kw) => text.includes(kw))
    ? seeded(trainer.id, "goal", 95, 100)
    : seeded(trainer.id, "goal", 74, 86);
}
function scheduleFit(trainer, prefs) {
  const parts = Array.isArray(prefs?.schedule) ? prefs.schedule : [];
  if (!trainer.workingHours?.start || !parts.length) return seeded(trainer.id, "sched", 85, 94);
  const overlaps = parts.filter((p) => workingHoursOverlapsDayPart(trainer.workingHours, p) === true).length;
  return clamp(80 + (overlaps / parts.length) * 20);
}
function locationFit(trainer, prefs) {
  const m = matchesLocationToken(trainer.locations, prefs?.location);
  if (m === true) return seeded(trainer.id, "loc", 96, 100);
  if (m === null) return seeded(trainer.id, "loc", 86, 94);
  return seeded(trainer.id, "loc", 68, 80);
}
function coachingStyleFit(trainer, prefs) {
  let base = seeded(trainer.id, "style", 88, 98);
  const levels = Array.isArray(trainer.experienceLevels) ? trainer.experienceLevels : [];
  if (prefs?.experience && levels.length && levels.includes(prefs.experience)) base += 3;
  if (prefs?.gender && prefs.gender !== "No preference") {
    if ((prefs.gender === "Male coach" && trainer.gender === "Male") ||
        (prefs.gender === "Female coach" && trainer.gender === "Female")) base += 2;
  }
  return clamp(base);
}
function budgetCeiling(budget) {
  if (!budget) return null;
  const str = String(budget).toLowerCase();
  if (str.includes("flex")) return null;
  const nums = (str.match(/\d+/g) || []).map(Number);
  if (!nums.length) return null;
  if (str.includes("+")) return Infinity;
  return Math.max(...nums);
}
function coachPrice(trainer) {
  const candidates = [trainer.sessionRate, trainer.sessionPriceMax, trainer.sessionPriceMin, trainer.priceMax, trainer.price];
  const found = candidates.map(Number).find((n) => Number.isFinite(n) && n > 0);
  return found ?? null;
}
function budgetFit(trainer, prefs) {
  const ceiling = budgetCeiling(prefs?.budget);
  const price = coachPrice(trainer);
  if (price !== null && ceiling !== null) {
    if (ceiling === Infinity || price <= ceiling) return seeded(trainer.id, "budget", 96, 100);
    if (price <= ceiling * 1.15) return seeded(trainer.id, "budget", 84, 92);
    if (price <= ceiling * 1.35) return seeded(trainer.id, "budget", 70, 82);
    return seeded(trainer.id, "budget", 56, 68);
  }
  if (price !== null && ceiling === null && prefs?.budget) return seeded(trainer.id, "budget", 92, 98);
  const ratingNudge = Math.round((Number(trainer.rating || 4.8) - 4.5) * 4);
  return clamp(seeded(trainer.id, "budget", 88, 97) + ratingNudge);
}

const WEIGHTS = { goal: 0.3, schedule: 0.2, location: 0.2, style: 0.18, budget: 0.12 };

export function matchQuality(overall) {
  if (overall >= 95) return "Excellent Match";
  if (overall >= 88) return "Great Match";
  if (overall >= 80) return "Strong Match";
  return "Good Match";
}

// Normalizes a raw prefs object (from the iOS app or the website's stored Get
// Matched answers) into the exact shape the scoring functions expect.
export function normalizePrefs(p = {}) {
  return {
    goal: typeof p.goal === "string" ? p.goal : "",
    location: typeof p.location === "string" ? p.location : "",
    experience: typeof p.experience === "string" ? p.experience : "",
    gender: typeof p.gender === "string" ? p.gender : "",
    budget: typeof p.budget === "string" ? p.budget : "",
    schedule: Array.isArray(p.schedule) ? p.schedule.filter((s) => typeof s === "string") : [],
  };
}

export function computeMatch(trainer, prefs) {
  const factors = [
    { key: "goal", label: "Goal Fit", pct: clamp(goalFit(trainer, prefs)) },
    { key: "schedule", label: "Schedule Fit", pct: clamp(scheduleFit(trainer, prefs)) },
    { key: "budget", label: "Budget Fit", pct: clamp(budgetFit(trainer, prefs)) },
    { key: "location", label: "Location Fit", pct: clamp(locationFit(trainer, prefs)) },
    { key: "style", label: "Coaching Style Fit", pct: clamp(coachingStyleFit(trainer, prefs)) },
  ];
  const overall = clamp(factors.reduce((sum, f) => sum + f.pct * WEIGHTS[f.key], 0));
  const personalized = !!(prefs && (prefs.goal || prefs.location || (prefs.schedule || []).length || prefs.gender || prefs.budget));
  return { overall, quality: matchQuality(overall), factors, personalized };
}
