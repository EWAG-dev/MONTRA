import { getTrainer } from "./trainerStore.js";
import { listTrainerSessions } from "./sessionStore.js";
import { listTrainerReviews } from "./reviewStore.js";

// Deterministic per-coach pseudo-random so synthesized signals are stable across
// requests (no flicker) until they're backed by measured data. Same approach as
// the website's montra-match engine.
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

/**
 * Returns the derived "MONTRA Insights" + client-proof signals for a coach.
 * Real wherever the data model supports it (accepting status, demand from actual
 * bookings, background-verified from the admin-confirmed flags, featured review +
 * happy-client count from real reviews); deterministic placeholders elsewhere,
 * each marked `derived: true` so the UI/consumers know it isn't measured yet.
 */
export async function getTrainerInsights(id) {
  const trainer = await getTrainer(id);
  if (!trainer) return null;

  const [sessions, reviews] = await Promise.all([
    listTrainerSessions(id).catch(() => []),
    listTrainerReviews(id, { limit: 100 }).catch(() => []),
  ]);

  // ---- Real demand: sessions created in the last 7 days ----
  const weekAgo = Date.now() - 7 * 86400000;
  const introThisWeek = sessions.filter((s) => {
    const t = Date.parse(s.createdAt || s.startTime || "");
    return Number.isFinite(t) && t >= weekAgo && s.status !== "cancelled";
  }).length;

  // ---- Availability window from the days the coach actually offers ----
  const dayCount = Array.isArray(trainer.availabilityDays) ? trainer.availabilityDays.length : 0;
  const availableWithinDays = dayCount >= 5 ? 3 : dayCount >= 3 ? 7 : dayCount >= 1 ? 10 : 14;

  // ---- Goal-match percentile from rating / reviews / experience ----
  const proof =
    Number(trainer.rating || 4.8) * 2 +
    Math.min(Number(trainer.reviewCount || 0), 20) * 0.25 +
    Math.min(Number(trainer.experienceYears || 0), 12) * 0.4;
  const goalPercentile = proof >= 13 ? 5 : proof >= 11 ? 10 : proof >= 9 ? 15 : 20;

  const accepting = trainer.isActive !== false && trainer.status === "approved";
  const backgroundVerified = Boolean(
    trainer.idVerified && (trainer.montraCertified || trainer.backgroundCheckCleared)
  );

  // Each insight carries `on` (whether it's true for this coach) so the UI only
  // surfaces the positive ones. `derived` flags signals not yet measured.
  const insights = [
    { key: "accepting", label: "Currently accepting new clients", on: accepting, derived: false },
    { key: "availability", label: `Available within ${availableWithinDays} days`, on: dayCount > 0, derived: true },
    { key: "goalMatch", label: `Top ${goalPercentile}% match for your goals`, on: true, derived: true },
    { key: "verified", label: "Background verified & certified", on: backgroundVerified, derived: false },
    { key: "schedule", label: "Highly aligned with your schedule", on: Boolean(trainer.workingHours?.start), derived: true },
  ];

  const responsiveness = {
    pct: seeded(id, "resp", 92, 98),
    withinMinutes: 60,
    derived: true,
  };

  const demand = {
    introThisWeek,
    highDemand: introThisWeek >= 2,
    derived: false,
  };

  // ---- Client proof from REAL reviews (never fabricated names/quotes) ----
  const withText = reviews.filter((r) => r.text && r.text.trim());
  const top = withText.slice().sort((a, b) => b.rating - a.rating)[0] || null;
  const featuredReview = top
    ? { text: top.text, author: top.clientName || "Verified Client", rating: top.rating }
    : null;

  // Derived outcome benchmarks — deterministic per coach until real outcome
  // tracking exists. Marked derived so they can be swapped for measured data.
  const topResults = [
    { label: `Average ${(seeded(id, "mult", 19, 26) / 10).toFixed(1)}x better results`, derived: true },
    { label: `${seeded(id, "lbs", 12, 22)} lbs average weight loss`, derived: true },
    { label: `${seeded(id, "str", 80, 92)}% stronger in 12 weeks`, derived: true },
    { label: `${seeded(id, "goal", 90, 97)}% goal achievement rate`, derived: true },
  ];

  return {
    insights,
    responsiveness,
    demand,
    proof: {
      rating: trainer.rating ?? null,
      reviewCount: trainer.reviewCount ?? reviews.length,
      happyClients: reviews.length,
      featuredReview,
      topResults,
    },
  };
}
