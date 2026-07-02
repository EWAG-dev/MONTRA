# Human Tasks

> Items that require manual action in Xcode, Railway, Firebase, Apple, or Stripe dashboards. Code is ready; these are the remaining setup steps.
> **Status:** ✅ Done · ⬜ Pending · ⏸ Deferred/Not Needed Now

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

## 2. Railway — Set Twilio Keys (SMS lead alerts) ⏸

Deferred for now per product direction. Revisit when SMS lead alerts are re-enabled.

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

## 4. TestFlight — Archive & Upload ✅

Completed (confirmed done).

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

---

## Copilot Requests (Needed From You)

### A. Replace Trainer Orientation Video URLs ✅
Done in code: orientation playback now points at Firebase Hosting paths under `/orientation/*` and no longer uses Google Drive URL conversion. 

Current mapping in `MONTRA/TrainerOrientationView.swift`:
1) Welcome to MONTRA → `/orientation/1.MONTRA_Coach_Academy_Onboarding.mp4`
2) MONTRA Standards & Code of Conduct → `/orientation/2.Building_Trust.mp4`
3) Client Request & Session Flow → `/orientation/3.The_Perfect_Intro_Session.mp4`
4) Safety, Liability & Scope of Practice → `/orientation/5.Professiona_Appearance.mp4`
5) Communication & Professionalism → `/orientation/6.Communication_Accountability.mp4`
6) The MONTRA Difference: Coaching Mindset & Client Experience → `/orientation/4.The_MONTRA_Difference_Focus%20on%20Coaching.mp4`

Hosting deployed and links verified live (HTTP 200, `content-type: video/mp4`, `accept-ranges: bytes`).

### B. Email Deliverability + Verification Email Branding ⬜
Code is now updated to send a branded MONTRA verification email with a button from the backend (`/api/auth/send-verification-email`) and iOS now uses a simple "I've verified my account" check + resend flow.

To complete deliverability (spam reduction + brand consistency), I still need these manual settings completed in Resend/domain DNS:
1) Verify sending domain and enable SPF/DKIM/DMARC alignment
2) Final From address selected: MONTRA <noreply@montrafit.com> ✅
3) Confirm whether we should use a custom verification landing page URL (if yes, set `CLIENT_VERIFY_CONTINUE_URL` in Railway)

Once done, I will finalize wording + From identity and mark this item complete.

#### Deliverability hardening runbook (10-20 min)
1) In Resend, open Domains and add/verify montrafit.com (or the exact domain used by noreply@montrafit.com).
2) In your DNS provider, add every Resend-provided record exactly as shown (usually 1 SPF TXT and 2 DKIM CNAME records).
3) Wait for DNS propagation, then click Verify in Resend until domain status is Verified.
4) Add a DMARC TXT record for `_dmarc.montrafit.com`:
	- Start policy (safe rollout): `v=DMARC1; p=none; adkim=s; aspf=s; rua=mailto:dmarc@montrafit.com; fo=1; pct=100`
	- After a few days of clean reports, tighten to quarantine/reject.
5) Ensure there is only one active SPF policy for the root domain (single TXT starting with `v=spf1`).
	- If SPF already exists for another sender, merge includes instead of creating a second SPF TXT.
6) In Resend, set default sender to `MONTRA <noreply@montrafit.com>` and keep using this identity consistently.
7) Send test emails to Gmail, Outlook, and iCloud from the app flow and confirm:
	- Message arrives in Inbox (not Spam/Junk)
	- Header authentication shows SPF=pass, DKIM=pass, DMARC=pass
8) Optional but recommended:
	- Add `List-Unsubscribe` header support for marketing mail only (not required for transactional verification email)
	- Keep plain-text fallback body alongside HTML

### C. Product Decision: Session Dispute Policy ✅
Decision locked for implementation:
1) Completion model: trainer can mark complete; client gets a dispute window.
2) Dispute window: 48 hours from trainer completion timestamp.
3) If no client response: auto-accept completion and finalize as completed.

Implementation notes:
- Client can file "no-show/dispute" during the 48h window.
- While disputed, payout/release actions pause until review resolves.
- If dispute is denied, session returns to completed.

### D. Product Decision: 3-Strike Enforcement Rules ✅
Decision locked for implementation:
1) Strike events:
- Verified trainer no-show.
- Trainer cancellation within 12h of session start (unless emergency override by admin).
- Substantiated serious professionalism/safety complaint.
2) Strike expiration window: rolling 90 days.
3) Enforcement:
- Strike 1: in-app warning + policy reminder acknowledgement required.
- Strike 2: temporary 7-day suspension from new client assignments.
- Strike 3: automatic account deactivation and admin review required for appeal/reactivation.

Implementation notes:
- Severe safety misconduct can bypass strike ladder for immediate admin suspension.
- All strike writes should be auditable (event type, source, evidence refs, reviewer, timestamp).
