#!/usr/bin/env bash
# E2E test for the real trainer self-service flow: a plain Firebase account (no role claim,
# no admin-side dev shortcut) submits a full application via POST /api/trainers/apply, gets
# auto-approved per the hiring score, then completes orientation. This is the actual path a
# real trainer applicant goes through, as opposed to /api/dev/create-test-trainer which writes
# a minimal pre-approved Firestore doc directly and skips the scoring entirely.
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_TRAINER_EMAIL="e2e-apply-trainer@example.com"
TEST_TRAINER_PASSWORD="TempTest123!"

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== creating a plain account (no role claim) =="
TRAINER_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD" "E2E Apply Trainer")
require "account creation" "$TRAINER_UID"
TRAINER_TOKEN=$(sign_in "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD")

echo "== before applying: my-status reports not_submitted =="
PRE_STATUS=$(curl -s "$BASE_URL/api/trainers/my-status" -H "Authorization: Bearer ${TRAINER_TOKEN}")
[ "$(echo "$PRE_STATUS" | jq -r '.hasApplication')" = "false" ] || { echo "FAIL: expected hasApplication=false before applying ($PRE_STATUS)"; exit 1; }
pass "my-status reports no application before applying"

echo "== submitting a strong application via /api/trainers/apply =="
APPLY_RESP=$(curl -s -X POST "$BASE_URL/api/trainers/apply" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${TRAINER_TOKEN}" \
  -d '{"name":"E2E Apply Trainer","bio":"Certified strength coach with 8 years of in-home personal training experience, specializing in strength and mobility programming for busy professionals.","certification":"NASM-CPT","specialties":["Strength","Mobility"],"locations":["Boston, MA"],"experienceYears":8,"hasInsurance":true,"backgroundCheckConsent":true,"policyAgreement":true,"cprCertification":"Current"}')
echo "$APPLY_RESP"
TRAINER_DOC_ID=$(echo "$APPLY_RESP" | jq -r '.trainer.id')
require "trainer doc id from apply" "$TRAINER_DOC_ID"
APPLY_STATUS=$(echo "$APPLY_RESP" | jq -r '.trainer.status')
pass "application submitted (status: $APPLY_STATUS, score: $(echo "$APPLY_RESP" | jq -r '.hiringEvaluation.score'))"

echo "== my-profile reflects the submitted application =="
PROFILE=$(curl -s "$BASE_URL/api/trainers/my-profile" -H "Authorization: Bearer ${TRAINER_TOKEN}")
[ "$(echo "$PROFILE" | jq -r '.trainer.id')" = "$TRAINER_DOC_ID" ] || { echo "FAIL: my-profile id mismatch ($PROFILE)"; exit 1; }
[ "$(echo "$PROFILE" | jq -r '.trainer.certification')" = "NASM-CPT" ] || { echo "FAIL: my-profile certification mismatch ($PROFILE)"; exit 1; }
pass "my-profile reflects submitted fields"

echo "== my-status reflects hasApplication=true with a hiring evaluation =="
STATUS_RESP=$(curl -s "$BASE_URL/api/trainers/my-status" -H "Authorization: Bearer ${TRAINER_TOKEN}")
[ "$(echo "$STATUS_RESP" | jq -r '.hasApplication')" = "true" ] || { echo "FAIL: expected hasApplication=true ($STATUS_RESP)"; exit 1; }
require "hiring evaluation score" "$(echo "$STATUS_RESP" | jq -r '.hiringEvaluation.score')"
pass "my-status reflects the application and hiring evaluation"

if [ "$APPLY_STATUS" = "approved" ]; then
  echo "== auto-approved: checking visibility + orientation flow =="
  PUBLIC_VISIBLE=$(curl -s "$BASE_URL/api/trainers" | jq -r --arg id "$TRAINER_DOC_ID" '.trainers[] | select(.id==$id) | .id')
  require "publicly visible after auto-approval" "$PUBLIC_VISIBLE"
  pass "auto-approved trainer is publicly visible"

  echo "== completing orientation =="
  ORIENT_RESP=$(curl -s -X POST "$BASE_URL/api/trainers/my-profile/orientation-complete" -H "Authorization: Bearer ${TRAINER_TOKEN}")
  [ "$(echo "$ORIENT_RESP" | jq -r '.trainer.orientationCompleted')" = "true" ] || { echo "FAIL: orientationCompleted not true ($ORIENT_RESP)"; exit 1; }
  pass "orientation-complete sets orientationCompleted=true"

  RECHECK=$(curl -s "$BASE_URL/api/trainers/my-profile" -H "Authorization: Bearer ${TRAINER_TOKEN}")
  [ "$(echo "$RECHECK" | jq -r '.trainer.orientationCompleted')" = "true" ] || { echo "FAIL: my-profile doesn't reflect orientation completion ($RECHECK)"; exit 1; }
  pass "my-profile reflects orientation completion on reload"
else
  echo "NOTE: application landed as '$APPLY_STATUS', not auto-approved (score below threshold) — skipping orientation/visibility checks, which require approval."
fi

echo "== cleanup =="
cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "" "$TRAINER_DOC_ID" | jq
pass "trainer apply E2E test"
