import { getTrainer } from "./trainerStore.js";

// Deterministic per-coach pseudo-random so derived pricing is stable across
// requests until real per-coach rates exist. Same approach as insightStore.js.
function hashId(id) {
  let h = 2166136261;
  const str = String(id || "");
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return Math.abs(h);
}
function seeded(id, salt, min, max) {
  const h = hashId(`${id}:${salt}`);
  return min + (h % (max - min + 1));
}

// Session pack sizes and the volume discount each earns off the coach's single-
// session rate. Bigger commitment → lower per-session price.
const SESSION_TIERS = [5, 10, 20, 40];
const DISCOUNT = { 5: 0.03, 10: 0.07, 20: 0.12, 40: 0.18 };
const FREQUENCIES = [1, 2, 3, 4, 5];

const TIER_COPY = {
  5: { blurb: "Build momentum and start strong.", badge: null },
  10: { blurb: "Lock in a consistent routine.", badge: "MOST POPULAR" },
  20: { blurb: "Stay consistent and see real, lasting results.", badge: "BEST VALUE" },
  40: { blurb: "Full transformation with habits that stick.", badge: null },
};

function packageFeatures(n) {
  return [
    `${n} one-on-one training sessions`,
    "Flexible scheduling",
    "Personalized workouts",
    "Progress tracking",
    n >= 20 ? "Priority coach support" : "Messaging support",
  ];
}

/**
 * Returns the coach's session packages, frequency options, and à-la-carte add-ons.
 * Pricing is real when the coach has a `sessionRate` (forward-compatible with the
 * future Storefront), otherwise a deterministic per-coach rate so numbers are
 * stable and believable. `derived: true` flags the placeholder pricing.
 */
export async function getTrainerPackages(id) {
  const trainer = await getTrainer(id);
  if (!trainer) return null;

  const realRate = Number(trainer.sessionRate ?? trainer.sessionPriceMax);
  const hasRealRate = Number.isFinite(realRate) && realRate > 0;

  // Single-session ("à la carte") rate, nudged up by experience so seasoned coaches
  // price higher. Rounded to the nearest $1.
  const base = hasRealRate
    ? Math.round(realRate)
    : 90 + Math.min(Number(trainer.experienceYears || 0), 10) * 2 + seeded(id, "rate", 0, 5) * 3;

  const packages = SESSION_TIERS.map((n) => {
    const perSession = Math.round(base * (1 - (DISCOUNT[n] || 0)));
    const copy = TIER_COPY[n] || { blurb: "", badge: null };
    return {
      sessions: n,
      perSession,
      total: perSession * n,
      badge: copy.badge,
      recommended: n === 20,
      blurb: copy.blurb,
      features: packageFeatures(n),
    };
  });

  const frequencies = FREQUENCIES.map((f) => ({
    perWeek: f,
    label: `${f} session${f > 1 ? "s" : ""} per week`,
  }));

  const addOns = [
    { key: "single", title: "Single Training Session", desc: "One-on-one personalized training session.", price: base, unit: "session", icon: "dumbbell" },
    { key: "nutrition", title: "Nutrition Coaching", desc: "Personalized nutrition plan and guidance.", price: Math.round(base * 1.5), unit: "session", icon: "clipboard" },
    { key: "form", title: "Form & Technique", desc: "Video analysis and form improvement.", price: Math.round(base * 0.8), unit: "session", icon: "run" },
    { key: "accountability", title: "Accountability Session", desc: "Check-in and goal-review session.", price: Math.round(base * 0.8), unit: "session", icon: "calendar" },
    { key: "custom", title: "Custom Session", desc: "Have a specific need? Let's build it together.", price: null, unit: "varies", icon: "dots" },
  ];

  return {
    currency: "USD",
    packages,
    frequencies,
    addOns,
    guarantee: "MONTRA Match Guarantee™",
    derived: !hasRealRate,
  };
}
