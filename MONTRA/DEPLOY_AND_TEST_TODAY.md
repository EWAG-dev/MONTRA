# Deploy + Test Today (Website URL + iOS TestFlight)

Last updated: 2026-06-20

This is the shortest path to what you asked for:

1. Use the live temporary website URL for manual web testing.
2. Push the iOS app to TestFlight.
3. Run one coordinated smoke test pass across both.

## 1) Current Reality Check

- Website test URL is live: https://montra-27532.web.app/find-a-coach.html
- iOS app is not yet in TestFlight.
- App is configured for production API base URL in [Info.plist](Info.plist).
- Firebase iOS config is present in [GoogleService-Info.plist](GoogleService-Info.plist).

## 2) Website Testing Now (Do This First)

Use only the temporary URL for web QA today.

### 2.1 Core pages to test

- https://montra-27532.web.app/find-a-coach.html
- https://montra-27532.web.app/quiz.html
- https://montra-27532.web.app/trainer-application.html
- https://montra-27532.web.app/trainer-onboarding.html

### 2.2 Fast pass checklist

1. find-a-coach page loads and trainer cards render.
2. quiz flow completes end-to-end and returns matches.
3. trainer-application form submits successfully.
4. trainer-onboarding login works, profile loads, and save works.

### 2.3 If website changes are needed before final QA

Run from your website project folder, then redeploy:

```bash
npm install
npm run build
firebase use montra-27532
firebase deploy --only hosting
```

Then rerun the same 4-page test pass on the web.app URL.

## 3) iOS to TestFlight Today

## 3.1 Pre-archive checks

1. Confirm Apple Developer signing is valid in Xcode for Release.
2. Confirm Bundle Identifier is production one expected by Firebase.
3. Increment build number in [Info.plist](Info.plist) (CFBundleVersion).
4. Keep API base URL as production in [Info.plist](Info.plist).
5. Build and run once on a physical device before archiving.

## 3.2 Archive and upload

1. Open the iOS Xcode project from the parent MONTRA folder.
2. Select Any iOS Device (arm64) as destination.
3. Product -> Archive.
4. In Organizer: Validate App.
5. In Organizer: Distribute App -> App Store Connect -> Upload.
6. Wait for processing in App Store Connect (typically 10-45 min).

## 3.3 Enable TestFlight build

In App Store Connect:

1. Go to your app -> TestFlight tab.
2. Select the new build once processing completes.
3. Add internal testers first (fastest).
4. Optionally add external tester group if you already have compliance metadata ready.

## 4) Unified Manual Test Pass (Website + TestFlight)

After TestFlight build is installable, run this exact flow:

1. Complete website quiz on web.app URL.
2. Submit trainer application path on web.
3. Sign into iOS app on TestFlight build.
4. Validate role routing:
   - client account reaches client shell
   - trainer account reaches trainer flow gates then trainer tabs
5. Validate any trainer profile/request data appears where expected.
6. Capture defects with timestamp, account used, and platform.

## 5) Done Criteria for Today

You are done when all are true:

1. Web test pass completed on https://montra-27532.web.app without blockers.
2. New iOS build is uploaded, processed, and assigned to internal TestFlight testers.
3. At least one full login + core navigation test is completed on TestFlight build.
4. You have a short bug list split by platform: web, iOS, backend integration.

## 6) Common Blockers and Immediate Fix

### 6.1 Firebase deploy fails

- Re-run login and project select:

```bash
firebase login
firebase use montra-27532
firebase deploy --only hosting
```

- Confirm deploy is run from the correct website folder (the one containing firebase.json and built output).

### 6.2 Xcode archive/signing fails

- In Signing and Capabilities:
  - re-select Team
  - ensure Automatically manage signing is enabled
  - clean build folder and archive again

### 6.3 TestFlight build not visible

- Wait for App Store Connect processing to finish.
- Refresh TestFlight tab and confirm build version/build number matches your upload.

## 7) Suggested Order (Fastest Path)

1. Complete website smoke pass on live URL now.
2. Start iOS archive/upload immediately after.
3. While build processes, log web defects.
4. Install TestFlight build and execute iOS smoke pass.




# Notes from Aaron (new dev manual tester)"
# Confirmed it is in testflight
# 