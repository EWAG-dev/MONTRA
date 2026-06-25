# Human Tasks

> **Status legend:** ✅ Done · ⬜ Pending

Tasks that require manual action in Xcode, Apple Developer Portal, Firebase Console, or Railway dashboard. Code is ready; these are the remaining setup steps.

---

## Push Notifications (FCM)

The full push notification pipeline is implemented:
- iOS registers for APNs, gets an FCM token, and sends it to the backend (`POST /api/me/device-token`)
- Backend sends push via Firebase Admin SDK Messaging on: new client request, trainer accepted, new message, session booked, session cancelled
- Notification toggles in ProfileMenuSheet gate each push type

**What a human must do before push notifications fire:**

### 1. Apple Developer Portal ✅
- [x] Enable **Push Notifications** capability for `com.elitehomefitness.montra`
- [x] Create an **APNs Auth Key** (`.p8` file)

### 2. Firebase Console ✅
- [x] Upload APNs Auth Key (`.p8`), Key ID, and Team ID
- [x] `com.elitehomefitness.montra` listed as the iOS bundle ID

### 3. Xcode — Capabilities ✅
- [x] Push Notifications capability added
- [x] Background Modes → Remote notifications checked

### 4. Xcode — FirebaseMessaging Package ✅
- [x] FirebaseMessaging SPM package added to MONTRA target

### 5. project.yml ✅
- [x] `UIBackgroundModes: [remote-notification]` and `aps-environment: development` added

### 6. Switch to production entitlement before App Store release ⬜
- [ ] Change `project.yml` → `com.apple.developer.aps-environment: development` → `production`, then `xcodegen generate` before archiving for TestFlight/App Store

---

## Railway Environment Variables

- [ ] `FIREBASE_AUTH_DOMAIN` was set to `montra-27532.firebaseapp.co` (missing `m`) — fix to `montra-27532.firebaseapp.com` ✅ Fixed by user 2026-06-24
- [ ] After push notifications are configured, no new Railway vars are needed — the backend uses the existing `FIREBASE_SERVICE_ACCOUNT_JSON` which already has messaging scope

---

## Resend Email (Transactional)

### Rate-limit trigger — exact record (2026-06-23)
Hit the **Resend free-tier daily limit (100 emails/day)** during E2E test runs. Here is exactly what sent emails:

| Action that sends email | Emails sent per E2E run |
|---|---|
| `POST /api/trainers/provision` (auto-approved) | 2 — application-received + approval-with-password-link |
| `POST /api/admin/trainers/:id/approve` | 1 — approval-with-password-link |
| `POST /api/client/requests` (trainer has email) | 1 — "new client request" to trainer |
| `POST /api/trainers/matches/:id/accept` (client has email) | 1 — "your coach accepted" to client |
| `POST /api/client/sessions` (trainer has email) | 1 — "new session booked" to trainer |
| `POST /api/conversations/:id/messages` (recipient has email) | 1 per message |
| `POST /api/admin/test-email` | 1 — test email to admin |

**How we hit the limit:** we ran all 15 E2E scripts in sequence on the same day. Each script that creates a trainer via the provision endpoint (admin_review, website_trainer_form, past_booking, trainer_apply) sends 2 emails. Combined with chat/booking/accept scripts, a single full suite run sends ~25–35 emails. Running the full suite 3–4 times in one day exhausts the 100-email free quota.

**Fix:** upgrade Resend to a paid plan for production volume. No code change needed — all sends already use `.catch(console.error)` so quota errors don't break the request flow, they just log silently.

- [ ] Upgrade Resend plan at resend.com when transactional email volume grows

---

## App Store / TestFlight

- [ ] Archive via Product → Archive in Xcode once push notifications are wired
- [ ] Upload to TestFlight for real-device push notification testing (simulator cannot receive push)

---

## Future Features (require design + backend schema decisions before code)

### Verified Reviews ✅ (shipped)
Real client reviews, anchored to completed sessions so nothing is fabricated.
- Backend: `reviewStore.js` (`reviews` collection). `POST /api/client/reviews`
  (auth; guards: 404 no session, 403 not-your-session, 409 not-completed / already
  reviewed, 400 rating out of 1–5; one review per session) and public
  `GET /api/trainers/:id/reviews` (returns `reviews[]` + `summary{rating,reviewCount}`).
  Creating a review **recomputes the trainer's `rating`/`reviewCount`** from actual
  visible reviews (replaces the seeded 4.9/0 default with real data). Reviews are
  cleaned up in the dev reset path and re-aggregated.
- Website: `coach-profile.html` "What Clients Say" now renders real review cards
  (avatar initial, name, Verified badge, stars, relative date, body) from the public
  endpoint; falls back to the aggregate-only note when a coach has none yet.
- iOS: client SessionsView surfaces a "PAST SESSIONS" section for completed sessions
  with a "Leave a Review" button → `ReviewSheet` (star rating + optional text) →
  `BookingAPI.submitReview`. Rows flip to "Reviewed ✓" after submit.
- E2E: `reviews_e2e_test.sh` covers uncompleted-409, out-of-range-400, cross-client-403,
  create-201, duplicate-409, public listing, and aggregate recompute.

### Budget Fit ✅ (shipped, real once coach pricing exists)
Get Matched now has a budget step (step 7: Under $60 / $60–90 / $90–120 / $120+ /
Flexible), saved into `localStorage['montra:prefs'].budget`. `montra-match.js`
`budgetFit(trainer, prefs)` compares the client's ceiling to the coach's per-session
price when the data model has one (`sessionRate`/`sessionPriceMax`/…). **Coaches have
no price field yet** (see Storefront below), so today it still falls back to a seeded
baseline — but the moment Storefront pricing lands, Budget Fit becomes a true signal
with no further match-engine changes.

### Trust-stack verification gating ✅ (shipped)
The ID Verified / Background Checked / MONTRA Certified™ badges no longer render for
every approved coach — each is gated on a real, admin-confirmed per-trainer flag.
- Backend schema: `idVerified`, `backgroundCheckCleared`, `montraCertified` booleans
  on the trainer (default false). These are distinct from the existing
  `backgroundCheckConsent` (the applicant's consent, not a completed check) and are
  **deliberately ignored from apply/provision input** — `normalizeTrainerPayload`
  only carries them forward from the existing doc, so a trainer cannot self-claim them.
- Admin route: `POST /api/admin/trainers/:id/verification` (requireAdmin) sets any of
  the three booleans via a direct merge write (`setTrainerVerification`); 400 on empty
  body, 404 unknown trainer. This is the **only** path that can turn a badge on.
- Website: `coach-profile.html` `renderTrustStack` gates each badge on its flag and
  hides the whole "A Coach You Can Trust" card when there's nothing real to show.
- **Admin UI**: `website/admin.html` (`/admin.html`, noindex, not linked) — Firebase
  admin sign-in, lists every coach with three toggles that call the verification route
  and save immediately. Full instructions in `ADMIN_GUIDE.md`.
- E2E: `trust_verification_e2e_test.sh` (defaults false, self-set-via-apply ignored,
  non-admin 403, empty-body 400, admin sets exactly the flags given, flags survive a
  later profile edit).

**HUMAN ACTION:** an admin must turn each badge on at `/admin.html` once the real check
clears (or wire a vetting vendor to call `POST /api/admin/trainers/:id/verification`).
Until then the badges stay off — correct, not a bug.

### Coach profile insights / client-proof cards ⬜ (built; some values are derived placeholders)
The coach profile now has a sidebar "Meet Your Coach" video card, a **MONTRA Insights™**
card, and a **What Clients Are Saying** card. **Nothing is hardcoded in the page** — it
all comes from `GET /api/trainers/:id/insights` (`insightStore.js`). What's real vs.
derived today:
- **Real now:** "accepting new clients" (status/active), "background verified & certified"
  (the admin flags above), demand / "In High Demand" (counts actual bookings in the last
  7 days), the featured review + "happy clients" count + rating (real reviews only — no
  fabricated names), and the intro-video card (real `introVideoUrl`, else a placeholder).
- **Derived placeholders** (deterministic per coach, each flagged `derived: true` in the
  API response so they're easy to find and swap): availability window, "Top X% match",
  "highly aligned with your schedule", responsiveness %, and the **Top Client Results**
  stats (e.g. "18 lbs average weight loss", "95% goal achievement"). These are believable
  but **not measured** — before leaning on them in marketing/legal terms, replace the
  derivations in `insightStore.js` with real tracked outcomes (and consider a disclosure).
  Featured testimonials are deliberately NOT synthesized — they only show once real
  reviews exist.

### Choose Your Session Package builder ⬜ (built; pricing derived until Storefront)
The coach profile has an interactive **Choose Your Session Package** section: a gradient
slider (5/10/20/40 sessions), a selected-package card (features + total + per-session
price), a **Session Frequency** dropdown, and a **live Estimated Duration** that
recomputes as `ceil(sessions ÷ sessions-per-week)` (e.g. 20 sessions @ 2/wk = 10 weeks).
Below it sit the **3/6/12-month Coaching Commitment** cards (each with its own weekly-
frequency picker and a live monthly price) and a compact À-La-Carte add-ons row.
**Nothing is hardcoded** — it all comes from `GET /api/trainers/:id/packages`
(`packageStore.js`), which returns `packages`, `commitments`, and `addOns`.
- **Real when available:** if a coach ever has a `sessionRate`/`sessionPriceMax`, the
  builder prices off it. The volume-discount tiers, frequency→duration math, and feature
  lists are real product logic.
- **Derived until then:** with no per-coach rate yet (Storefront below), the single-
  session base is a deterministic per-coach figure (~$90–$130, nudged by experience) and
  packages discount off it (5%/7%/12%/18%). Response is flagged `derived: true`, and the
  UI shows an "indicative pricing — coach confirms final rate" note. Replace the base-rate
  derivation in `packageStore.js` with the real Storefront price to make it fully real.

### MONTRA Match™ — follow-ups
All three original follow-ups (real reviews, budget step, trust-stack gating) are now
shipped — see the sections above. Budget Fit becomes a true signal once Storefront
pricing exists (below).

### MONTRA Team concierge chat (Maya) ⬜ (built; CRM/SMS hooks pending)
A self-injecting concierge widget (`website/assets/js/montra-chat.js`) is on every
public page: a "Chat With The MONTRA Team" launcher → premium black/orange panel with
Maya, 6 quick actions, a guided discovery flow (goal → training location → city →
start timing → match-or-browse) that always drives toward **Book Consultation**, the
Match Guarantee™ copy, and a **Talk To A Human** callback form. Human-first language
throughout (never "AI"/"bot").
- Backend: `leadStore.js` (`leads` collection) + `POST /api/leads/callback` (public)
  creates a lead, applies **priority routing** (coach_profile/pricing/homepage →
  sales, existing_client → support, coach_application/for_trainers → recruiting), and
  emails the team via Resend. `GET /api/admin/leads` lists them. E2E:
  `leads_e2e_test.sh`. Dev cleanup takes `leadPhone`.
- **What's real:** lead capture + Firestore storage + routing + **email** notification
  to `ADMIN_EMAILS`.
- **HUMAN ACTIONS / follow-ups:**
  - **SMS to assigned rep** — no SMS provider wired. Add Twilio (or similar) and send
    from `notifyLeadTeam` in `index.js`; today only email fires.
  - **Real CRM** — `leads` is a lightweight stand-in. Point `createLead`/notification
    at the real CRM (HubSpot/Salesforce/etc.) or forward via webhook when chosen.
  - **Team inboxes** — all routed teams currently email `ADMIN_EMAILS`. Add per-team
    addresses (sales/support/recruiting) and pick by `lead.team`.
  - **Maya avatar** — the widget uses an SVG avatar placeholder; drop a real Maya
    headshot into `montra-chat.js` (`PERSON_SVG` / `.mtc-av img`) for the concierge look.
  - **Business hours / urgent phone** — the confirmation says "call our main office";
    add the real phone number and (optionally) gate the 10–15 min ETA to business hours.

### Trainer Storefront & Pricing ⬜
The Storefront tab currently shows "coming soon." Fully building this requires:
- Stripe Connect integration for trainer payouts (or a similar payment processor)
- New backend schema: trainer `sessionPriceMin` / `sessionPriceMax`, `packagesOffered`, `stripeAccountId`
- New backend routes: `POST /api/trainers/my-storefront`, Stripe webhook handlers
- iOS: actual Stripe SDK or WKWebView for Stripe Connect onboarding
- Website: pricing displayed per-trainer on coach-profile.html (currently shows no pricing because no schema exists)

### Trainer Programs ✅ (shipped)
Full end-to-end program authoring + assignment.
- Backend: `programStore.js` (collections `trainerPrograms` templates + `clientPrograms` assignments) with 6 routes in `index.js`: list/create/update/delete templates (`/api/trainers/programs[/:id]`), assign (`POST /api/trainers/programs/:id/assign`, requires ownership + an accepted match with the client), and the client's view (`GET /api/client/programs`). Assignments store an **immutable snapshot** of the template, so later template edits don't mutate what a client is already following. Blank workouts/exercises are normalized out; weeks clamped 1..52.
- iOS trainer: `ProgramAPI.swift` (models + CRUD/assign/loadClientPrograms), `TrainerProgramsView.swift` (live list + stats), `ProgramBuilderSheet.swift` (create/edit builder with dynamic workouts + exercises, and an assign-to-matched-client picker).
- iOS client: `AssignedProgramCard.swift` (expandable card) surfaced in the Workouts tab of `ProgressView`, fed by `GET /api/client/programs`.
- Tests: `programs_e2e_test.sh` covers create/normalize, missing-title 400, cross-trainer 403, update, assign-without-match 403, successful assign, client snapshot visibility, snapshot immutability, and delete — all passing against production.

### MONTRA Team / Support In-App Chat ⬜
MessagesView has MONTRA Team and Support tabs that currently show a mailto: link.
To wire real in-app support chat:
- Decide whether EHF will use a real support Firebase account or a service like Intercom
- If real account: add a backend-known `MONTRA_TEAM_TRAINER_ID` env var, create a special conversation thread type that routes to the admin account
- Update `GET /api/conversations/my-threads` to include this thread for all clients

### Weight History Tracking ✅ (shipped)
Implemented end-to-end:
- `weightLog: [{date: ISO, weight: number}]` on `clientProgress`; startWeight/currentWeight
  derived from the log (earliest/latest)
- `GET /api/client/progress/weight-history`, `POST /api/client/progress/weight-entry`
  (400 on invalid weight; dateless entries default to now)
- iOS: "Log Weight" button + entry sheet in the Body Stats tab, WeightLineChart plotting
  weight over time (y-axis auto-scaled to the data range)
- E2E: `weight_history_e2e_test.sh`

### Session Completion Marking ✅ (shipped)
Implemented end-to-end:
- `status: "completed"` + `completedAt` + optional `completionNotes` on `bookedSessions`
- `POST /api/trainers/sessions/:id/complete` and `POST /api/client/sessions/:id/complete`
  (guards: 403 not-your-session, 409 if cancelled or not yet started); both push the other party
- iOS: "Mark Complete" button on started sessions in TrainerSessionsView (Past tab now
  surfaces completed sessions with a green Completed badge)
- E2E: `complete_session_e2e_test.sh`

Remaining optional enhancement (not blocking): capture per-session calories / structured
post-workout notes beyond the freeform `completionNotes` field, and surface a completion
flow on the client SessionsView too.

### Impact Credits ✅ (shipped)
Booking an Intro Session unlocks a $10 Impact Credit the client can direct to a cause.
Implemented end-to-end:
- Backend: `impactStore.js` (`impactCredits` collection; `IMPACT_CAUSES` catalog — youth_sports,
  fitness_access, mental_wellness, community_health, survivor_support). Credit is created
  idempotently per `sessionId` inside `POST /api/client/sessions`. Routes:
  `GET /api/client/impact-credits`, `POST /api/client/impact-credits/:id/direct`
  (allocations: donate / coaching / gift / split — donate+split require a valid cause,
  split sets `splitCausePct:50`, gift requires `giftEmail`; 404 unknown, 403 not-yours,
  409 already-directed), and the public `GET /api/impact/community` aggregate
  (amountDirected / creditsActivated / causesSupported / causesActive / livesImpacted,
  plus `IMPACT_BASELINE_*` env offsets, default 0). Credits cleaned up in dev reset.
- iOS: `ImpactAPI.swift` (cause catalog + models + load/direct/community), `ImpactFlowView.swift`
  (3-screen flow: Session Confirmed → Direct Your $10 Impact Credit → Thank You), shown as a
  `fullScreenCover` after booking in `SessionsView`. `ImpactSummaryView.swift` renders the
  "MONTRA Community Impact" stat panel. DashboardView surfaces a "YOUR IMPACT" card that
  re-opens the direct flow for any still-pending credit and links to the community summary.
- E2E: `impact_credits_e2e_test.sh` covers unlock, list, invalid-cause 400, cross-client 403,
  direct, re-direct 409, and community total increment — all passing against production.

Optional future enhancement (not blocking): actually fan out gifted credits to the recipient's
account by email, and wire real charity disbursement / receipts behind the directed totals.
