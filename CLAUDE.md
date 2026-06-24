# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo layout

This single repo (`EWAG-dev/MONTRA` on GitHub) contains three independently-deployed pieces that share a backend and a Firebase project:

- `MONTRA/` — iOS app source (SwiftUI). `MONTRA.xcodeproj` is the Xcode project; `project.yml` is the [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec it's generated from (bundle id `com.elitehomefitness.montra`, iOS 17 deployment target).
- `backend/` — Express API (Node, ESM) deployed to Railway, backed by Firestore via `firebase-admin`.
- `website/` — Vite-built multi-page static marketing/trainer-onboarding site, deployed to Firebase Hosting.

A separate, unrelated clone of the website (`~/EHF Website`) exists elsewhere on disk — don't confuse it with `website/` in this repo; this repo's copy is the one under active development and git history.

## Commands

### Backend (`backend/`)
```
npm install
npm run dev      # node --watch src/index.js
npm start        # node src/index.js
```
There is no real test suite yet — `backend/src/__tests__/` exists but the files are stubs with no test runner wired up (no jest/vitest config or devDependency). Don't assume `npm test` does anything meaningful.

Backend config is via `.env` (copy from `.env.example`). Key vars: `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT_JSON`, `ALLOWED_ORIGINS`, `ADMIN_EMAILS`, `AUTO_APPROVE_TRAINERS`, `HIRING_SCORE_APPROVE_THRESHOLD`, `RESEND_API_KEY`/`FROM_EMAIL` (transactional email), `ALLOW_DEV_ENDPOINTS` (must be unset/falsy in production — gates the `/api/dev/*` routes, 404s otherwise).

Deploys to Railway; `railway.json` configures the service, root is `backend`.

### Website (`website/`)
```
npm install
npm run dev       # vite dev server
npm run build     # outputs to website/dist — hosting serves this, not raw html
npm run preview
```
Deploy: `firebase deploy --only hosting` from the repo root (root `firebase.json` points hosting `public` at `website/dist`). Always `npm run build` immediately before deploying — there's no CI step that does it for you, so deploying stale `dist` is a real footgun here.

### iOS (`MONTRA/`)
Open `MONTRA.xcodeproj` in Xcode and build/run normally (Cmd-R), or archive via Product > Archive for TestFlight. If `project.yml` changes, regenerate the project with `xcodegen generate` before opening Xcode. No CLI test target is configured.

## Cross-cutting architecture

All three surfaces integrate only through the backend + Firebase Auth — there are no direct code imports between them.

- **Backend base URL**: `https://montra-production.up.railway.app` (Railway). iOS reads it from `MONTRA_API_BASE_URL` (env var, then Info.plist, then localhost fallback — see `LiveDataConnectivity.swift`). Website pages set a `BACKEND_URL` constant pointing at the same host.
- **Auth**: Firebase Auth everywhere. iOS uses native FirebaseAuth; website trainer flows use the Firebase Web SDK with config pulled from the backend's `GET /api/firebase/client-config` (the backend is the single source of Firebase client config, not a baked-in website constant).
- **Trainer role**: determined by the Firebase custom claim `role=trainer`, set server-side (e.g. via `/api/dev/set-trainer-claim` in dev, or the approval flow in prod). `requireAdmin` in `backend/src/index.js` additionally accepts `role=admin`/`role=trainer_admin` custom claims, an `admin: true` claim, or an email match against `ADMIN_EMAILS`.
- **Trainer profile schema** is shared conceptually across iOS/website/backend (name, certification, bio, specialties, locations, availability) but each surface has slightly different field conventions (e.g. location formatting drifts: "Boston MA" vs "Boston, MA") — don't assume a single canonical shape without checking `trainerStore.js`.

### Backend (`backend/src/`)
- `index.js` — all Express routes live here (single file, ~1000 lines). Routes are grouped by prefix: `/api/trainers/*` (directory, apply, match, my-profile/status/matches), `/api/trainers/matches/:requestId/{accept,decline,open-chat}` (trainer responding to a client request), `/api/client/*` (match + requests), `/api/conversations/*` (chat threads/messages), `/api/notifications/my`, `/api/admin/*` (requires `requireFirebaseAuth` + `requireAdmin`), and `/api/dev/*` (gated behind `ALLOW_DEV_ENDPOINTS`, otherwise 404).
- `trainerStore.js` — Firestore-backed trainer directory: applications, scoring-based auto-approval (`AUTO_APPROVE_TRAINERS` + `HIRING_SCORE_APPROVE_THRESHOLD`), CRUD.
- `matchStore.js` — client↔trainer match/request records.
- `chatStore.js` — conversation/message persistence backing `/api/conversations/*`.
- `firebase.js` — lazy Firebase Admin SDK init (`initFirebaseAdmin`, `getAuth`, `getFirestore`); reads `FIREBASE_SERVICE_ACCOUNT_JSON`.
- Two auth middlewares used throughout `index.js`: `requireFirebaseAuth` (verifies bearer ID token) and `requireAdmin` (checks claims/email after auth).

### iOS app (`MONTRA/`)
Read `MONTRA/MONTRA_AND_WEBSITE_ARCHITECTURE_GUIDE.md` for the full breakdown — the essentials:

- **Entry/routing**: `MONTRAApp.swift` configures Firebase and hosts `RootView`, a global state machine: splash while auth resolves → `LoginView` if signed out → trainer gates (`TrainerAgreementView` → `TrainerOrientationView` → `TrainerTabView`) if `role=trainer` → `OnboardingQuizView` if client onboarding incomplete → `ContentView` (client shell) otherwise. Trace routing bugs here first.
- **Auth**: `AuthManager.swift` wraps FirebaseAuth, resolves role from ID token claims, and supports a `demoRole` bypass for previewing either role without a backend account.
- **Client shell** (`ContentView.swift`): 4 tabs — Dashboard, Sessions, WorkoutProgress, CoachChat.
- **Trainer shell** (`TrainerTabView.swift`): 5 tabs — Dashboard, Sessions, Storefront, Programs, Inbox. Of these, only `TrainerInboxView`'s Requests tab calls a live backend endpoint (`GET /api/trainers/my-profile`); the rest still render sample data.
- **Important**: large parts of both shells (dashboard stats, sessions booking, progress charts, messages) are local `AppStorage`/sample-data simulations, not backend-wired. Before "fixing" a data bug, check whether the view is actually live-wired or still sample/preview — don't assume API integration exists just because the UI looks complete.
- **Design system**: `Theme.swift` (light/dark `Color.montra*` tokens) + `SharedComponents.swift` (cards, buttons, section headers) — make global visual changes here, not per-view.

### Website (`website/`)
- Static multi-page HTML with inline JS, Tailwind via CDN, built/bundled by Vite (`vite.config.js` lists each page as a build input: index, find-a-coach, coach-profile, for-trainers, how-it-works, pricing, services, quiz).
- `assets/js/nav.js` handles nav highlighting; `data/trainers.json` is a local trainer dataset used by client-side matching/filtering (quiz, find-a-coach) — this is independent of the backend's matching logic, so the two can diverge.
- `quiz.html` does client-side-only scoring against `data/trainers.json` and does not submit to the backend.
- `trainer-application.html` posts to `POST /api/trainers/provision` (no auth).
- `trainer-onboarding.html` is the authenticated trainer flow: Firebase Web sign-in → `GET /api/firebase/client-config` → `GET /api/trainers/my-profile` (prefill) → `POST /api/trainers/apply` (save), all with a bearer ID token.
