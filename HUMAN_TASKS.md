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

### Trainer Storefront & Pricing ⬜
The Storefront tab currently shows "coming soon." Fully building this requires:
- Stripe Connect integration for trainer payouts (or a similar payment processor)
- New backend schema: trainer `sessionPriceMin` / `sessionPriceMax`, `packagesOffered`, `stripeAccountId`
- New backend routes: `POST /api/trainers/my-storefront`, Stripe webhook handlers
- iOS: actual Stripe SDK or WKWebView for Stripe Connect onboarding
- Website: pricing displayed per-trainer on coach-profile.html (currently shows no pricing because no schema exists)

### Trainer Programs ⬜
The Programs tab is a stub. Requires:
- New backend schema: program templates (title, description, weeks, workouts[])
- New Firestore collection: `trainerPrograms` + `clientPrograms` (assigned)
- iOS program builder UI + client program view

### MONTRA Team / Support In-App Chat ⬜
MessagesView has MONTRA Team and Support tabs that currently show a mailto: link.
To wire real in-app support chat:
- Decide whether EHF will use a real support Firebase account or a service like Intercom
- If real account: add a backend-known `MONTRA_TEAM_TRAINER_ID` env var, create a special conversation thread type that routes to the admin account
- Update `GET /api/conversations/my-threads` to include this thread for all clients

### Weight History Tracking ⬜
Body Stats tab shows current/start weight (single values). Full history requires:
- New Firestore field in `clientProgress`: `weightLog: [{date: ISO, weight: number}]`
- Backend endpoints: `POST /api/client/progress/weight-entry`, `GET /api/client/progress/weight-history`
- iOS: line chart of weight over time (similar to existing session chart in ProgressView)

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
