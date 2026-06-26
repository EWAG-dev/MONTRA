# Human Tasks

> Items that require manual action in Xcode, Railway, Firebase, Apple, or Stripe dashboards. Code is ready; these are the remaining setup steps.
> **Status:** ✅ Done · ⬜ Pending

---

## 1. Railway — Environment Variables ⬜

Add these in Railway → backend service → Variables:

**Stripe (required for payments to go live):**
- `STRIPE_SECRET_KEY` — Stripe Dashboard → Developers → API Keys → Secret key
- `STRIPE_PUBLISHABLE_KEY` — same page, Publishable key
- `STRIPE_WEBHOOK_SECRET` — Stripe Dashboard → Webhooks → Add endpoint → `https://montra-production.up.railway.app/api/stripe/webhook` → copy signing secret
  - Enable events: `payment_intent.succeeded`, `payment_intent.payment_failed`

**Twilio (required for SMS lead alerts to fire):**
- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_FROM` — a Twilio number (`+1…`) or Messaging Service SID (`MG…`)
- `LEAD_SMS_TO` — comma-separated recipient numbers (shared fallback)
- Optional per-team routing: `LEAD_SMS_SALES`, `LEAD_SMS_SUPPORT`, `LEAD_SMS_RECRUITING`

---

## 2. Xcode — Run xcodegen (Stripe iOS SDK) ⬜

Stripe iOS SPM was added to `project.yml`. Before building:

```bash
cd /Users/taylorolsen-vogt/MONTRA
xcodegen generate
open MONTRA.xcodeproj
```

Xcode will resolve the `stripe-ios-spm` package on first open (may take a few minutes). Then build normally (Cmd-R).

---

## 3. iOS — Wire Checkout Views into Navigation ⬜

`IntroBookingView` and `ProgramCheckoutView` are built but not yet reachable in the app. Suggested entry points:

- **Dashboard or Sessions** → "Book Intro Session" button → `IntroBookingView(preselectedTrainer: nil)`
- **Coach card / match result** → "Book Intro" → `IntroBookingView(preselectedTrainer: trainer)`
- **Commit card "View Program"** → `ProgramCheckoutView(trainer: trainer, preselectedMonths: months)`

---

## 4. APNs — Switch to Production Entitlement Before App Store ⬜

Before archiving for TestFlight or App Store, in `project.yml` change:
```yaml
com.apple.developer.aps-environment: development
```
to:
```yaml
com.apple.developer.aps-environment: production
```
Then `xcodegen generate` before archiving.

---

## 5. App Store / TestFlight ⬜

- Archive via **Product → Archive** in Xcode
- Upload to TestFlight for real-device push notification testing (simulator cannot receive push)

---

## 6. Trust-Stack Badges — Turn On Per Coach ⬜

Badges (ID Verified / Background Checked / MONTRA Certified™) are off by default. Turn each on once the real check clears:

Go to **`/admin.html`** → find the coach → toggle the badge.

Or call directly: `POST /api/admin/trainers/:id/verification` with e.g. `{ "idVerified": true }`.

---

## 7. SEO — Set Custom Domain ⬜

Once the real domain is connected in Firebase Hosting:

1. Set the `SITE_ORIGIN` **GitHub repo variable** (Settings → Variables) to e.g. `https://montra.com`
2. Submit `/sitemap.xml` in **Google Search Console**

The nightly CI deploy runs `build:seo` automatically so coach pages will pick up the correct domain going forward.

---

## 8. Resend — Upgrade Plan When Volume Grows ⬜

Free tier is 100 emails/day. No code change needed — upgrade at resend.com when transactional volume demands it.

---

## Future Features (design / product decision required first)

### Trainer Storefront & Pricing
Requires Stripe Connect for trainer payouts + new backend schema (`sessionPriceMin/Max`, `stripeAccountId`). Unlocks: Budget Fit becoming a real match signal; package and intro pricing becoming exact (both currently use a derived per-coach estimate).

### In-App Support Chat
`MessagesView` has MONTRA Team and Support tabs showing a mailto link. Needs a product decision: real support Firebase account vs. third-party tool (Intercom, etc.).

### Coach Profile Derived Placeholders
`GET /api/trainers/:id/insights` returns some `derived: true` values (responsiveness %, "Top X% match", Top Client Results stats). These are deterministic estimates. Swap with real tracked data before using in marketing or legal copy.
