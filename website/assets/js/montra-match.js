// MONTRA Match (website client). The scoring ALGORITHM now lives in one place —
// the backend (backend/src/matchScore.js) — and this module just stores the
// visitor's Get Matched answers and fetches scores from it. The Performance
// Forecast is web-only presentation, rebuilt here from the fetched match factors
// (it isn't a second copy of the scoring algorithm).

const PREFS_KEY = 'montra:prefs';
const API_BASE = 'https://montra-production.up.railway.app';

// ---- Preference storage (written by the Get Matched flow) -------------------

export function savePreferences(prefs) {
  try {
    localStorage.setItem(PREFS_KEY, JSON.stringify({ ...prefs, savedAt: Date.now() }));
  } catch (_) { /* storage unavailable — scores fall back to non-personalized */ }
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

// ---- Backend-scored match (single source of truth) --------------------------

// Fetches the MONTRA Match for one coach. Returns { overall, quality, factors, personalized }.
export async function fetchMatch(trainerId, prefsArg) {
  const prefs = prefsArg === undefined ? loadPreferences() : prefsArg;
  const res = await fetch(`${API_BASE}/api/trainers/${encodeURIComponent(trainerId)}/match`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ prefs: prefs || {} }),
  });
  if (!res.ok) throw new Error('match failed');
  return res.json();
}

// Fetches match scores for many coaches in one call. Returns a Map id -> { overall, quality }.
export async function fetchMatchBatch(ids, prefsArg) {
  const list = Array.isArray(ids) ? ids.filter(Boolean) : [];
  if (!list.length) return new Map();
  const prefs = prefsArg === undefined ? loadPreferences() : prefsArg;
  try {
    const res = await fetch(`${API_BASE}/api/match/batch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ids: list, prefs: prefs || {} }),
    });
    if (!res.ok) throw new Error('batch failed');
    const { results } = await res.json();
    return new Map((results || []).map((r) => [r.id, r]));
  } catch (_) {
    return new Map();
  }
}

// ---- Performance Forecast (web-only presentation, from a fetched match) ------

const clamp = (n) => Math.max(0, Math.min(100, Math.round(n)));

const KNOWLEDGE_INSIGHTS = [
  'Clients who train at home are 3x more likely to stay consistent because they eliminate travel time, wait times, and distractions found in gyms.',
  'Matching on coaching style and accountability is one of the strongest predictors of whether a client hits their 12-week goals.',
  'Schedule fit drives session attendance — and attendance is the #1 predictor of long-term results.',
  'Clients who start with an intro session are far more likely to commit to a full program and see lasting change.',
];

export function forecastQuality(overall) {
  if (overall >= 90) return 'Excellent Match';
  if (overall >= 80) return 'Strong Match';
  if (overall >= 70) return 'Good Match';
  return 'Promising Match';
}

export function knowledgeInsight(trainer) {
  const id = String(trainer?.id || '');
  let sum = 0;
  for (let i = 0; i < id.length; i++) sum += id.charCodeAt(i);
  return KNOWLEDGE_INSIGHTS[sum % KNOWLEDGE_INSIGHTS.length];
}

// Reframes the backend match factors as predicted *outcomes* for the center of the
// coach profile. `match` is a result from fetchMatch(); `trainer` supplies the
// track record (rating/reviews) used by the long-term projection.
export function computeForecast(match, trainer) {
  const first = (trainer.name || 'your coach').split(' ')[0];
  const f = Object.fromEntries((match.factors || []).map((x) => [x.key, x.pct]));
  const goal = f.goal ?? 90, sched = f.schedule ?? 90, style = f.style ?? 90, loc = f.location ?? 90, budget = f.budget ?? 90;
  const track = clamp(62 + (Number(trainer.rating || 4.8) - 4.0) * 16 + Math.min(Number(trainer.reviewCount || 0), 20) * 0.5);

  const factors = [
    { key: 'goal', icon: '🎯', label: 'Goal Achievement', pct: goal, desc: 'Specializes in your primary objective.' },
    { key: 'consistency', icon: '🔥', label: 'Consistency Prediction', pct: sched, desc: `Your schedule & ${first}'s availability are highly compatible.` },
    { key: 'accountability', icon: '🤝', label: 'Accountability Match', pct: clamp((style + goal) / 2), desc: 'Approach to accountability aligns with what you prefer.' },
    { key: 'motivation', icon: '💬', label: 'Motivation Alignment', pct: style, desc: 'Communication style matches what keeps you engaged.' },
    { key: 'lifestyle', icon: '🗓️', label: 'Lifestyle Compatibility', pct: clamp((loc + budget) / 2), desc: 'Location, training environment & weekly commitment fit.' },
    { key: 'longterm', icon: '⭐', label: 'Long-Term Success', pct: clamp((track + goal + style) / 3), desc: 'Clients with a similar profile achieve strong, sustainable results.' },
  ];
  const overall = clamp(factors.reduce((sum, x) => sum + x.pct, 0) / factors.length);
  const insight = `${first} was selected because their coaching style, expertise, schedule, and accountability approach closely match what clients with goals like yours need to succeed.`;
  return { overall, quality: forecastQuality(overall), factors, insight, personalized: !!match.personalized };
}

// Expose on window so classic (non-module) scripts on index.html + quiz.html can
// share the same backend-scored match.
if (typeof window !== 'undefined') {
  window.MontraMatch = { fetchMatch, fetchMatchBatch, hasPreferences, loadPreferences, savePreferences };
}
