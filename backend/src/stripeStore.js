// Stripe payment operations — uses createRequire because the stripe npm package
// is CJS and the backend is ESM.
import { createRequire } from "module";
const require = createRequire(import.meta.url);

function getStripe() {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) throw new Error("STRIPE_SECRET_KEY not configured");
  const Stripe = require("stripe");
  return new Stripe(key, { apiVersion: "2024-06-20" });
}

// ─── Customers ───────────────────────────────────────────────────────────────

/**
 * Returns an existing Stripe Customer for the given email, or creates one.
 * Avoids duplicate customers across purchases from the same client.
 */
export async function getOrCreateCustomer({ email, name }) {
  const stripe = getStripe();
  const existing = await stripe.customers.list({ email, limit: 1 });
  if (existing.data.length > 0) return existing.data[0];
  return stripe.customers.create({ email, name: name || email });
}

// ─── One-time payments (intro sessions) ─────────────────────────────────────

/**
 * Creates a one-time Stripe PaymentIntent for a coach intro session.
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

// ─── Subscriptions (coaching programs) ──────────────────────────────────────

/**
 * Creates a monthly recurring Stripe Subscription for a coaching program.
 *
 * Uses payment_behavior: 'default_incomplete' so the subscription starts in
 * an incomplete state — the client must confirm the first payment using the
 * returned clientSecret. Subsequent months are charged automatically.
 *
 * Returns { clientSecret, subscriptionId, customerId, amount }.
 * clientSecret is from the subscription's first invoice PaymentIntent and
 * works identically with Stripe PaymentSheet / Payment Element.
 */
export async function createProgramSubscription({
  trainerId, trainerName, programTitle, months, freqPerWeek,
  amountCents, freeIntro, customerEmail, customerName,
}) {
  const stripe = getStripe();
  const customer = await getOrCreateCustomer({ email: customerEmail, name: customerName });

  const subscription = await stripe.subscriptions.create({
    customer: customer.id,
    items: [{
      price_data: {
        currency: "usd",
        product_data: {
          name: `MONTRA — ${programTitle}`,
          metadata: { trainerId: String(trainerId), trainerName: String(trainerName) },
        },
        unit_amount: amountCents,
        recurring: { interval: "month" },
      },
    }],
    payment_behavior: "default_incomplete",
    payment_settings: { save_default_payment_method: "on_subscription" },
    expand: ["latest_invoice.payment_intent"],
    metadata: {
      type: "program_subscription",
      trainerId: String(trainerId),
      trainerName: String(trainerName),
      programTitle: String(programTitle),
      months: String(months),
      freqPerWeek: String(freqPerWeek),
      freeIntro: freeIntro ? "true" : "false",
    },
  });

  const pi = subscription.latest_invoice.payment_intent;
  return {
    clientSecret: pi.client_secret,
    subscriptionId: subscription.id,
    customerId: customer.id,
    amount: amountCents,
  };
}

/**
 * Cancels a subscription at the end of the current billing period.
 * The client keeps access until period end; no future invoices are generated.
 */
export async function cancelSubscription(subscriptionId) {
  const stripe = getStripe();
  return stripe.subscriptions.update(subscriptionId, { cancel_at_period_end: true });
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

// ─── Publishable key ─────────────────────────────────────────────────────────

export function getPublishableKey() {
  const key = process.env.STRIPE_PUBLISHABLE_KEY;
  if (!key) throw new Error("STRIPE_PUBLISHABLE_KEY not configured");
  return key;
}
