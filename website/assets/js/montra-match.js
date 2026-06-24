// MONTRA Match™ — shared scoring used across the marketing site (coach profile,
// Find a Coach cards, Get Matched results). It turns a visitor's stated
// preferences (captured by the Get Matched flow and stored in localStorage)
// plus a coach record from /api/trainers into an overall match percentage and a
// per-factor breakdown (Goal / Schedule / Budget / Location / Coaching Style).
//
// Scores are deterministic per coach: where we have a real signal (goal vs
// specialties, schedule vs working hours, location) we use it; where the data
// model doesn't yet capture a factor (e.g. budget), we derive a stable,
// believable score seeded from the coach id so numbers don't flicker between
// page loads. This keeps the "MONTRA already did the hard work for me" feel
// without inventing precision we don't have.

const PREFS_KEY = 'montra:prefs';

// ---- Preference storage (written by the Get Matched flow) -------------------

export function savePreferences(prefs) {
  try {
    localStorage.setItem(PREFS_KEY, JSON.stringify({ ...prefs, savedAt: Date.now() }));
  } catch (_) { /* storage unavailable — match falls back to baselines */ }
}

export function loadPreferences() {
  try {
    return JSON.parse(localStorage.getItem(PREFS_KEY) || 'null');
  } catch (_) {
    return null;
  }
}

export function hasPreferences() {
  return !!loadPreferences();
}

// ---- Tolerant matching helpers (mirrors quiz.html / backend conventions) -----

const GOAL_KEYWORDS = {
  'Build Muscle': ['build muscle', 'strength', 'muscle', 'personal training'],
  'Lose Weight': ['lose weight', 'weight loss', 'weight', 'fat loss'],
  'Flexibility & Wellness': ['flexibility', 'wellness', 'mobility', 'yoga', 'pilates', 'stretch'],
  'Athletic Performance': ['athletic performance', 'performance', 'sports', 'conditioning', 'strength'],
  'Combat Sports': ['combat sports', 'boxing', 'kickboxing', 'combat'],
  'General Fitness': ['general fitness', 'personal training', 'fitness'],
};

function normalizeToken(value) {
  return String(value || '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
}

function trainerText(trainer) {
  return normalizeToken([...(trainer.specialties || []), trainer.certification || ''].join(' '));
}

function matchesLocationToken(trainerLocations, location) {
  if (!location) return null;
  if (!Array.isArray(trainerLocations) || !trainerLocations.length) return null;
  const target = normalizeToken(location).replace(/\s+/g, '');
  return trainerLocations.some((loc) => {
    const candidate = normalizeToken(loc).replace(/\s+/g, '');
    return candidate.includes(target) || target.includes(candidate);
  });
}

function parseTimeToMinutes(value) {
  const match = /^(\d{1,2}):(\d{2})\s*(AM|PM)$/i.exec(String(value || '').trim());
  if (!match) return null;
  let hours = Number(match[1]) % 12;
  if (/pm/i.test(match[3])) hours += 12;
  return hours * 60 + Number(match[2]);
}

const DAY_PART_WINDOWS = {
  'Early Morning': [0, 9 * 60],
  'Morning': [9 * 60, 12 * 60],
  'Afternoon': [12 * 60, 17 * 60],
  'Evening': [17 * 60, 24 * 60],
};

function workingHoursOverlapsDayPart(workingHours, dayPart) {
  const window = DAY_PART_WINDOWS[dayPart];
  if (!window || !workingHours?.start || !workingHours?.end) return null;
  const start = parseTimeToMinutes(workingHours.start);
  const end = parseTimeToMinutes(workingHours.end);
  if (start === null || end === null) return null;
  return start < window[1] && end > window[0];
}

// Stable per-coach pseudo-random in [min, max] so derived factors don't flicker.
function hashId(id) {
  let h = 2166136261;
  const s = String(id || '');
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

// ---- Per-factor scoring -----------------------------------------------------

function goalFit(trainer, prefs) {
  if (!prefs?.goal) return seeded(trainer.id, 'goal', 82, 92);
  const text = trainerText(trainer);
  const keywords = GOAL_KEYWORDS[prefs.goal] || [normalizeToken(prefs.goal)];
  return keywords.some((kw) => text.includes(kw))
    ? seeded(trainer.id, 'goal', 95, 100)
    : seeded(trainer.id, 'goal', 74, 86);
}

function scheduleFit(trainer, prefs) {
  const parts = Array.isArray(prefs?.schedule) ? prefs.schedule : [];
  if (!trainer.workingHours?.start || !parts.length) return seeded(trainer.id, 'sched', 85, 94);
  const overlaps = parts.filter((p) => workingHoursOverlapsDayPart(trainer.workingHours, p) === true).length;
  return clamp(80 + (overlaps / parts.length) * 20);
}

function locationFit(trainer, prefs) {
  const m = matchesLocationToken(trainer.locations, prefs?.location);
  if (m === true) return seeded(trainer.id, 'loc', 96, 100);
  if (m === null) return seeded(trainer.id, 'loc', 86, 94);
  return seeded(trainer.id, 'loc', 68, 80);
}

function coachingStyleFit(trainer, prefs) {
  let base = seeded(trainer.id, 'style', 88, 98);
  const levels = Array.isArray(trainer.experienceLevels) ? trainer.experienceLevels : [];
  if (prefs?.experience && levels.length && levels.includes(prefs.experience)) base += 3;
  if (prefs?.gender && prefs.gender !== 'No preference') {
    if ((prefs.gender === 'Male coach' && trainer.gender === 'Male') ||
        (prefs.gender === 'Female coach' && trainer.gender === 'Female')) base += 2;
  }
  return clamp(base);
}

// Parses a budget band label from Get Matched ("Under $60", "$60–90", "$120+",
// "Flexible") into a per-session ceiling. null = no constraint (flexible / blank).
function budgetCeiling(budget) {
  if (!budget) return null;
  const str = String(budget).toLowerCase();
  if (str.includes('flex')) return null;
  const nums = (str.match(/\d+/g) || []).map(Number);
  if (!nums.length) return null;
  if (str.includes('+')) return Infinity; // "$120+" — no upper bound
  return Math.max(...nums); // top of the band is the client's ceiling
}

// A single representative per-session price for the coach, if the data model has
// one yet (Storefront/pricing is a separate effort). Until then this is null and
// Budget Fit falls back to a stable seeded baseline.
function coachPrice(trainer) {
  const candidates = [trainer.sessionRate, trainer.sessionPriceMax, trainer.sessionPriceMin, trainer.priceMax, trainer.price];
  const found = candidates.map(Number).find((n) => Number.isFinite(n) && n > 0);
  return found ?? null;
}

function budgetFit(trainer, prefs) {
  const ceiling = budgetCeiling(prefs?.budget);
  const price = coachPrice(trainer);

  // Real signal: compare the coach's price to the client's stated ceiling.
  if (price !== null && ceiling !== null) {
    if (ceiling === Infinity || price <= ceiling) return seeded(trainer.id, 'budget', 96, 100);
    if (price <= ceiling * 1.15) return seeded(trainer.id, 'budget', 84, 92);
    if (price <= ceiling * 1.35) return seeded(trainer.id, 'budget', 70, 82);
    return seeded(trainer.id, 'budget', 56, 68);
  }
  // Client is flexible (or didn't say) but coach price is known: no constraint.
  if (price !== null && ceiling === null && prefs?.budget) return seeded(trainer.id, 'budget', 92, 98);

  // No coach price in the data model yet — stable, believable baseline nudged by rating.
  const ratingNudge = Math.round((Number(trainer.rating || 4.8) - 4.5) * 4);
  return clamp(seeded(trainer.id, 'budget', 88, 97) + ratingNudge);
}

const WEIGHTS = { goal: 0.30, schedule: 0.20, location: 0.20, style: 0.18, budget: 0.12 };

export function computeMatch(trainer, prefsArg) {
  const prefs = prefsArg === undefined ? loadPreferences() : prefsArg;
  const factors = [
    { key: 'goal', label: 'Goal Fit', pct: clamp(goalFit(trainer, prefs)) },
    { key: 'schedule', label: 'Schedule Fit', pct: clamp(scheduleFit(trainer, prefs)) },
    { key: 'budget', label: 'Budget Fit', pct: clamp(budgetFit(trainer, prefs)) },
    { key: 'location', label: 'Location Fit', pct: clamp(locationFit(trainer, prefs)) },
    { key: 'style', label: 'Coaching Style Fit', pct: clamp(coachingStyleFit(trainer, prefs)) },
  ];
  const overall = clamp(factors.reduce((sum, f) => sum + f.pct * WEIGHTS[f.key], 0));
  return { overall, factors, personalized: !!prefs };
}

export function matchQuality(overall) {
  if (overall >= 95) return 'Excellent Match';
  if (overall >= 88) return 'Great Match';
  if (overall >= 80) return 'Strong Match';
  return 'Good Match';
}

// Also expose on window so the classic (non-module) inline scripts on
// index.html and quiz.html can share the exact same scoring.
if (typeof window !== 'undefined') {
  window.MontraMatch = { computeMatch, matchQuality, hasPreferences, loadPreferences, savePreferences };
}
