# MONTRA Backend Starter

## What this includes
- Express server with CORS and JSON parsing
- Firebase Admin initialization
- Health endpoint: `/health`
- Firebase client config endpoint: `/api/firebase/client-config`
- Protected endpoint using Firebase ID token: `/api/me`
- Firestore-backed trainer directory endpoints
- Trainer self-application endpoint with scoring-based auto approval
- Trainer match endpoint for the iOS onboarding flow
- Railway deployment file: `railway.json`

## Quick start
1. Copy `.env.example` to `.env` and fill values.
2. Install dependencies:
   - `npm install`
3. Start server:
   - `npm run dev`

## Environment
- `PORT`
- `ALLOWED_ORIGINS`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_SERVICE_ACCOUNT_JSON`
- `FIREBASE_WEB_API_KEY`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_APP_ID`
- `ADMIN_EMAILS`
- `AUTO_APPROVE_TRAINERS`
- `HIRING_SCORE_APPROVE_THRESHOLD`

## API surface
- `GET /health`
- `GET /api/firebase/client-config`
- `POST /api/trainers/apply`
- `GET /api/trainers/my-status`
- `GET /api/trainers`
- `GET /api/trainers/:id`
- `GET /api/trainers/match?goal=...&location=...&gender=...`
- `POST /api/client/match`
- `POST /api/client/requests`
- `GET /api/client/requests`
- `GET /api/trainers/my-matches`
- `POST /api/ai/coach-suggestion`
- `POST /api/admin/trainers`
- `PUT /api/admin/trainers/:id`
- `DELETE /api/admin/trainers/:id`

By default, trainer applications are auto-approved when the hiring score reaches the configured threshold.

Admin endpoints are optional and require a valid Firebase ID token and either:
- a custom claim like `role=admin` or `role=trainer_admin`
- `admin: true`
- or a matching email in `ADMIN_EMAILS`

## Railway
- Create a Railway project from this repo.
- Set service root to `backend`.
- Add env vars from `.env.example`.
- Deploy.
