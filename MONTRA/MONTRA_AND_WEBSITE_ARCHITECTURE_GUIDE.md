# MONTRA + EHF Website Architecture Guide

Last updated: 2026-06-20
Audience: Advanced engineers onboarding to MONTRA stack
Goal: Ship iOS build to TestFlight today and start high-signal manual testing

## 1) System Map (Authoritative)

There are two related codebases on this machine:

- iOS app source (this repo): /Users/taylorolsen-vogt/MONTRA/MONTRA
- iOS project root (contains Xcode project): /Users/taylorolsen-vogt/MONTRA
- Website repo (separate path): /Users/taylorolsen-vogt/EHF Website

High-level architecture:

1. Web and iOS both connect to the same backend base URL:
   - https://montra-production.up.railway.app
2. Authentication is Firebase Auth for both app and trainer web onboarding.
3. Trainer role is determined by Firebase custom claim role=trainer in iOS.
4. Large parts of iOS client and trainer UX are currently preview/sample data, with selective live backend calls wired.
5. Website is a Vite-built multi-page static site deployed to Firebase Hosting.

## 2) iOS App (MONTRA) Architecture

### 2.1 Entry and Bootstrapping

Primary startup flow:

- MONTRAApp.swift
  - Configures Firebase from GoogleService-Info.plist at launch.
  - Injects AuthManager as environment object.
  - Uses RootView as the global router.
- Info.plist
  - MONTRA_API_BASE_URL defaults to https://montra-production.up.railway.app
  - Portrait-only for iPhone.
  - CFBundleVersion currently 4.

Connectivity model:

- LiveDataConnectivity.swift
  - Probes candidate base URLs via health-like endpoints:
    - /health
    - /api/health
    - /api/ping
    - /
  - Candidate base URLs come from:
    1) MONTRA_API_BASE_URL process env
    2) MONTRA_API_BASE_URL in Info.plist
    3) localhost fallbacks for local dev

### 2.2 Global Route State Machine

RootView routing (MONTRAApp.swift):

1. Splash while auth state is resolving.
2. If unauthenticated and not in demo role: LoginView.
3. If trainer role:
   - TrainerAgreementView until accepted.
   - TrainerOrientationView until completed.
   - Then TrainerTabView.
4. If client role and onboarding not complete: OnboardingQuizView.
5. Else client app shell: ContentView.

This is the most important runtime logic to understand first.

### 2.3 Authentication and Roles

AuthManager.swift is the auth backbone:

- Uses FirebaseAuth state listener.
- Role resolution:
  - Reads getIDTokenResult claims.
  - role == trainer => trainer; otherwise user.
- Supports demo bypass role via demoRole.
- Exposes auth actions:
  - signIn
  - createAccount
  - signOut
  - sendPasswordReset
  - deleteAccount

LoginView.swift:

- Handles login + reset-password UX.
- Contains Create new account action that re-enters onboarding pre-auth flow.
- Uses AppStorage-heavy state reset for quiz draft keys.

### 2.4 Client App Surface

Client shell:

- ContentView.swift
  - Custom 4-tab shell over TabView:
    - DashboardView
    - SessionsView
    - WorkoutProgressView
    - CoachChatSheet

Key client screens:

- DashboardView.swift
  - Mix of profile, next session, weekly progress, schedule.
  - Uses AppStorage goals/weight keys and TrainerProgressSnapshot.sample.
  - Includes Rematch action by toggling onboarding flags.
- SessionsView.swift
  - Booking UX from AppStorage-defined trainer availability.
  - Persists bookings in sessions.booked (string serialization).
  - Mostly local state simulation.
- ProgressView.swift + TrainerProgress.swift
  - Charts and nutrition planning around sample snapshot data.
  - Goal metrics derived from local AppStorage targets.
- MessagesView.swift and NotificationsView.swift
  - Primarily local/static UI data.

### 2.5 Trainer App Surface

Trainer shell:

- TrainerTabView.swift
  - Tabs: Dashboard, Sessions, Storefront, Programs, Inbox

Trainer views are partially wired:

- TrainerDashboardView.swift: sample schedule/stat data.
- TrainerSessionsView.swift: sample sessions.
- TrainerProgramsView.swift: sample programs.
- TrainerInboxView.swift:
  - Requests tab can call live backend using Firebase ID token.
  - Endpoint used: GET /api/trainers/my-profile
  - Other segments still sample.
- TrainerAgreementView.swift: local acceptance gate.
- TrainerOrientationView.swift: local video completion gate.

### 2.6 Onboarding + Matching

OnboardingQuizView.swift:

- Multi-step onboarding with extensive AppStorage persistence.
- Contains embedded trainer dataset fallback and filtering logic.
- Uses liveDataConnected flag to signal live vs preview behavior.

Important implication:

- App behavior in several paths is production-shaped UX with local state + placeholders, not end-to-end production data.

### 2.7 UI Design System

Theme.swift + SharedComponents.swift establish shared primitives:

- Dynamic light/dark palettes (Color.montra* tokens).
- Shared card styles and button style.
- Reusable section headers, top bars, notification controls.

This is where to make global visual changes.

## 3) iOS Build/Release Reality for Today (TestFlight)

Project metadata source:

- /Users/taylorolsen-vogt/MONTRA/project.yml
  - iOS target: 17.0
  - Bundle ID: com.elitehomefitness.montra
  - Firebase package dependency included
  - Development team configured: X29HP9D526
- Xcode project location:
  - /Users/taylorolsen-vogt/MONTRA/MONTRA.xcodeproj

Release-critical checks before archive:

1. Confirm signing/team/profile in Xcode for Release.
2. Ensure GoogleService-Info.plist matches production Firebase iOS app.
3. Increment build number in Info.plist/target (CFBundleVersion).
4. Validate launch on physical device:
   - auth sign-in
   - role routing
   - onboarding completion and tab shells
5. Archive + validate + upload to App Store Connect.
6. Add tester groups in TestFlight and start external/internal testing.

High-risk truth:

- App can be shipped for controlled testing, but many screens still run sample/preview data. Position this as functional beta, not full live data parity.

## 4) Website Repo (/Users/taylorolsen-vogt/EHF Website) Architecture

### 4.1 Stack and Build

- package.json:
  - Vite dev/build/preview scripts
  - No test runner configured
- vite.config.js:
  - Multi-page build inputs (index, find-a-coach, coach-profile, for-trainers, how-it-works, pricing, services, quiz)
- firebase.json:
  - Hosting public directory: dist
  - Deploy target is built output, not raw html files
- No .firebaserc in this repo (project alias must be set manually per machine)

### 4.2 Website Runtime Model

- Primarily static HTML pages with inline JavaScript.
- Tailwind loaded by CDN in pages.
- assets/js/nav.js handles active nav highlighting.
- data/trainers.json provides local trainer dataset for quiz/find flows.

### 4.3 Key Functional Pages

Client-side:

- quiz.html
  - 7-step matching quiz.
  - Loads trainers from /data/trainers.json.
  - Client-side scoring/matching; renders top 3 cards.
  - No backend submission in the current flow; booking action is alert-based.
- find-a-coach.html
  - Catalog/filter experience.
  - Uses data from local storage and trainer profile data conventions.
  - Heavy client-side filtering logic.

Trainer-side:

- trainer-application.html
  - Form submits to backend endpoint:
    - POST /api/trainers/provision
  - Uses BACKEND_URL constant pointing to Railway production.
- trainer-onboarding.html
  - Firebase Web SDK auth sign-in.
  - Fetches Firebase client config from backend:
    - GET /api/firebase/client-config
  - Pulls existing trainer profile:
    - GET /api/trainers/my-profile (Bearer token)
  - Saves trainer profile:
    - POST /api/trainers/apply (Bearer token)

## 5) Cross-Repo Contract Surface (What Actually Connects)

Shared integration axis is backend + auth, not direct repo imports.

Common backend base:

- iOS Info.plist MONTRA_API_BASE_URL
- Website BACKEND_URL constants
- Both point to montra-production.up.railway.app

Auth:

- iOS: native FirebaseAuth
- Web trainer onboarding: Firebase Web Auth via backend-provided client config

Trainer profile schema overlaps across app/web concepts:

- name
- certification
- bio
- specialties
- locations
- availability fields (varies by surface)

Known schema/style drift risk:

- Location formatting differs between contexts, e.g. Boston MA vs Boston, MA.
- Some client matching in iOS and web is still local/fallback and may diverge from backend matching logic.

## 6) What Is Live vs Mock Today

Clearly live/wired:

- iOS Firebase auth and role claim resolution.
- iOS backend connectivity probing.
- iOS trainer inbox requests endpoint usage in TrainerInboxView.
- Website trainer provisioning/application endpoints.
- Website trainer onboarding authenticated profile read/write.

Mostly mocked/local:

- Large portions of client dashboard/sessions/messages/progress in iOS.
- Large portions of trainer dashboard/sessions/programs in iOS.
- Public website quiz booking conversion beyond local matching display.

## 7) Manual Testing Plan (Today)

### 7.1 iOS TestFlight-focused smoke set

1. Cold launch and splash routing.
2. Login failure/success cases.
3. Role switch behavior (user vs trainer account).
4. Trainer gates:
   - agreement completion
   - orientation completion
   - trainer tab availability
5. Client onboarding completion and rematch path.
6. Sessions booking persistence across relaunch.
7. Trainer inbox requests load with live authenticated token.
8. Appearance modes (light/dark/system) and core nav stability.

### 7.2 Website smoke set

1. npm run build completes and regenerates dist.
2. quiz.html flow completes and renders matches from data/trainers.json.
3. trainer-application.html successfully posts to /api/trainers/provision.
4. trainer-onboarding.html:
   - Firebase sign-in succeeds
   - existing profile prefill works
   - save profile to /api/trainers/apply succeeds
5. Firebase hosting deploy serves latest dist output.

## 8) Deploy Command Reference

iOS (from Xcode):

- Open /Users/taylorolsen-vogt/MONTRA/MONTRA.xcodeproj
- Product > Archive
- Validate + Distribute to App Store Connect

Website (EHF Website repo):

1. npm install
2. npm run build
3. firebase use <project-id>
4. firebase deploy --only hosting

Important: Because hosting serves dist, deploying without a fresh build can publish stale pages.

## 9) Immediate CTO Guidance

For today:

1. Ship TestFlight as a controlled beta and document mocked areas to testers.
2. Focus manual testing on auth/role/onboarding and any live API paths first.
3. Keep website deployment disciplined: build then deploy, every time.
4. Treat trainer profile endpoints as the highest-value cross-platform integration to validate early.

For next engineering iteration:

- Replace sample datasets in iOS trainer/client dashboards with backend-backed repositories.
- Normalize location and taxonomy values across iOS, website, backend.
- Move website inline scripts to modular JS files and add basic automated smoke tests.
