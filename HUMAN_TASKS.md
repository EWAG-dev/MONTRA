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
