# Human Tasks

> Items that require manual action in Xcode, Railway, Firebase, Apple, or Stripe dashboards. Code is ready; these are the remaining setup steps.
> **Status:** ✅ Done · ⬜ Pending

---

## 1. Railway — Set Stripe Keys ⬜

You have Railway open. You need the **Stripe dashboard** open alongside it to get the keys.

In Railway → backend service → Variables, add:

| Variable | Where to get it |
|---|---|
| `STRIPE_SECRET_KEY` | Stripe → Developers → API Keys → Secret key |
| `STRIPE_PUBLISHABLE_KEY` | same page, Publishable key |
| `STRIPE_WEBHOOK_SECRET` | Stripe → Webhooks → Add endpoint → `https://montra-production.up.railway.app/api/stripe/webhook` → copy signing secret |

For the webhook, enable events: `payment_intent.succeeded`, `payment_intent.payment_failed`

---

## 2. Railway — Set Twilio Keys (SMS lead alerts) ⬜

Same Railway service, once you have a Twilio account:

| Variable | Value |
|---|---|
| `TWILIO_ACCOUNT_SID` | Twilio Console → Account Info |
| `TWILIO_AUTH_TOKEN` | same page |
| `TWILIO_FROM` | Your Twilio phone number (`+1…`) |
| `LEAD_SMS_TO` | Your number(s), comma-separated |

---

## 3. Xcode — Resolve Stripe iOS Package ✅ (code done, one Xcode step)

`xcodegen generate` has been run. Open Xcode and let it resolve the Stripe package:

```bash
open /Users/taylorolsen-vogt/MONTRA/MONTRA.xcodeproj
```

Xcode will show "Resolving package dependencies" on first open — wait for that to finish, then build (Cmd-R).

---

## 4. TestFlight — Archive & Upload ⬜

APNs entitlement is already set to `production` in `project.yml`. In Xcode:

1. Select **Any iOS Device** as the run destination (not a simulator)
2. **Product → Archive**
3. In the Organizer: **Distribute App → App Store Connect → Upload**
4. Once processed in App Store Connect, add yourself as a TestFlight tester

---

## 5. Trust-Stack Badges — Turn On Per Coach ⬜

Go to **`https://montra-27532.web.app/admin.html`** → find the coach → toggle the badges once the real checks clear (ID Verified, Background Checked, MONTRA Certified™).

---

## 6. SEO — Set Custom Domain ⬜

Blocked on connecting a real domain to Firebase Hosting. Once that's done:

1. Set `SITE_ORIGIN` GitHub repo variable → `https://your-domain.com`
2. Submit `/sitemap.xml` to Google Search Console

---

## 7. Resend — Upgrade When Volume Grows ⬜

Free tier = 100 emails/day. Upgrade at resend.com when needed. No code change required.

---

## Future Features (product decision required first)

### Trainer Storefront & Pricing
Stripe Connect for trainer payouts + `sessionPriceMin/Max` schema. Unlocks real Budget Fit scoring and exact package/intro pricing.

### In-App Support Chat
MessagesView MONTRA Team / Support tabs currently show mailto. Needs decision: real support Firebase account vs. Intercom/similar.

### Coach Profile Derived Placeholders
`GET /api/trainers/:id/insights` has `derived: true` values (responsiveness %, Top X% match, Top Client Results). Replace with real data before using in marketing copy.
