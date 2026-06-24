# Human Tasks

Tasks that require manual action in Xcode, Apple Developer Portal, Firebase Console, or Railway dashboard. Code is ready; these are the remaining setup steps.

---

## Push Notifications (FCM)

The full push notification pipeline is implemented:
- iOS registers for APNs, gets an FCM token, and sends it to the backend (`POST /api/me/device-token`)
- Backend sends push via Firebase Admin SDK Messaging on: new client request, trainer accepted, new message, session booked, session cancelled
- Notification toggles in ProfileMenuSheet gate each push type

**What a human must do before push notifications fire:**

### 1. Apple Developer Portal
- [ ] Enable **Push Notifications** capability for the app identifier `com.elitehomefitness.montra` at developer.apple.com → Certificates, Identifiers & Profiles → Identifiers
- [ ] Create an **APNs Auth Key** (`.p8` file) under Keys if one doesn't exist — note the Key ID and download the file

### 2. Firebase Console
- [ ] Go to Firebase Console → Project Settings → Cloud Messaging
- [ ] Under "Apple app configuration" upload the APNs Auth Key (`.p8`), Key ID, and Team ID
- [ ] Verify `com.elitehomefitness.montra` is listed as the iOS bundle ID

### 3. Xcode — Capabilities
- [ ] Open `MONTRA.xcodeproj` in Xcode
- [ ] Select the MONTRA target → Signing & Capabilities
- [ ] Click **+ Capability** → add **Push Notifications**
- [ ] Click **+ Capability** → add **Background Modes**, then check **Remote notifications**

### 4. Xcode — FirebaseMessaging Package
- [ ] File → Add Package Dependencies → search `https://github.com/firebase/firebase-ios-sdk`
- [ ] Select **FirebaseMessaging** (FirebaseAnalytics is optional)
- [ ] Add to the MONTRA target
- [ ] Re-run `xcodegen generate` is NOT needed — SPM packages are managed directly in Xcode

### 5. project.yml (so xcodegen doesn't lose the capability)
- [ ] After adding Push Notifications and Background Modes in Xcode, open `project.yml` and add under the MONTRA target settings:
  ```yaml
  entitlements:
    com.apple.developer.aps-environment: development  # change to 'production' for release
  ```
  and under `info` → `properties`:
  ```yaml
  UIBackgroundModes: [remote-notification]
  ```

---

## Railway Environment Variables

- [ ] `FIREBASE_AUTH_DOMAIN` was set to `montra-27532.firebaseapp.co` (missing `m`) — fix to `montra-27532.firebaseapp.com` ✅ Fixed by user 2026-06-24
- [ ] After push notifications are configured, no new Railway vars are needed — the backend uses the existing `FIREBASE_SERVICE_ACCOUNT_JSON` which already has messaging scope

---

## Resend Email (Transactional)

- [ ] Daily email quota was hit during E2E testing (2026-06-23). Upgrade the Resend plan or wait for quota reset. No code change needed.

---

## App Store / TestFlight

- [ ] Archive via Product → Archive in Xcode once push notifications are wired
- [ ] Upload to TestFlight for real-device push notification testing (simulator cannot receive push)
