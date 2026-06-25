// Stripe payment operations — used by both the program purchase and intro-session
// booking flows. Uses createRequire because stripe's npm package is CJS and the
// backend is ESM.
import { createRequire } from "module";
const require = createRequire(import.meta.url);

function getStripe() {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) throw new Error("STRIPE_SECRET_KEY not configured");
  const Stripe = require("stripe");
  return new Stripe(key, { apiVersion: "2024-06-20" });
}

// ─── Payment Intents ────────────────────────────────────────────────────────

/**
 * Creates a Stripe PaymentIntent for a coach intro session.
 * Returns { clientSecret, paymentIntentId, amount }.
 */
export async function createIntroSessionIntent({ trainerId, trainerName, amountCents, customerEmail }) {
  const stripe = getStripe();
  const intent = await stripe.paymentIntents.create({
    amount: amountCents,
    currency: "usd",
    receipt_email: customerEmail || undefined,
    metadata: {
      type: "intro_session",
      trainerId: String(trainerId),
      trainerName: String(trainerName),
    },
    automatic_payment_methods: { enabled: true },
  });
  return { clientSecret: intent.client_secret, paymentIntentId: intent.id, amount: amountCents };
}

/**
 * Creates a Stripe PaymentIntent for a coaching program purchase.
 * amountCents = first month (intro session FREE when freeIntro=true).
 */
export async function createProgramIntent({ trainerId, trainerName, programTitle, months, freqPerWeek, amountCents, freeIntro, customerEmail }) {
  const stripe = getStripe();
  const intent = await stripe.paymentIntents.create({
    amount: amountCents,
    currency: "usd",
    receipt_email: customerEmail || undefined,
    metadata: {
      type: "program_purchase",
      trainerId: String(trainerId),
      trainerName: String(trainerName),
      programTitle: String(programTitle),
      months: String(months),
      freqPerWeek: String(freqPerWeek),
      freeIntro: freeIntro ? "true" : "false",
    },
    automatic_payment_methods: { enabled: true },
  });
  return { clientSecret: intent.client_secret, paymentIntentId: intent.id, amount: amountCents };
}

// ─── Webhooks ────────────────────────────────────────────────────────────────

/**
 * Verifies a Stripe webhook signature and returns the parsed event.
 * rawBody must be the raw Buffer (not parsed JSON) from the request.
 */
export function constructWebhookEvent(rawBody, signature) {
  const stripe = getStripe();
  const secret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!secret) throw new Error("STRIPE_WEBHOOK_SECRET not configured");
  return stripe.webhooks.constructEvent(rawBody, signature, secret);
}

// ─── Publishable key (safe to expose to client) ──────────────────────────────

export function getPublishableKey() {
  const key = process.env.STRIPE_PUBLISHABLE_KEY;
  if (!key) throw new Error("STRIPE_PUBLISHABLE_KEY not configured");
  return key;
}
