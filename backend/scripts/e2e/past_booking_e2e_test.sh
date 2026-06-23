#!/usr/bin/env bash
# Verify that booking a session in the past is rejected — there's currently no
# validation for this, so the test is expected to FAIL first (confirming the bug),
# then pass after the fix is deployed.
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_TRAINER_EMAIL="e2e-pastbook-trainer@example.com"
TEST_TRAINER_PASSWORD="TempTest123!"
TEST_CLIENT_EMAIL="e2e-pastbook-client@example.com"
TEST_CLIENT_PASSWORD="TempTest123!"

echo "== setup =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"
TRAINER_UID=$(create_test_trainer "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD" "E2E PastBook Trainer")
require "trainer" "$TRAINER_UID"
CLIENT_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E PastBook Client")
require "client" "$CLIENT_UID"
TRAINER_TOKEN=$(sign_in "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD")
CLIENT_TOKEN=$(sign_in "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD")
TRAINER_DOC_ID=$(trainer_doc_id_by_email "$TEST_TRAINER_EMAIL")
require "trainer doc id" "$TRAINER_DOC_ID"

REQ_ID=$(curl -s -X POST "$BASE_URL/api/client/requests" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"clientProfile\":{\"firstName\":\"E2E\"}}" | jq -r '.request.id')
require "request" "$REQ_ID"
curl -s -X POST "$BASE_URL/api/trainers/matches/${REQ_ID}/accept" \
  -H "Authorization: Bearer ${TRAINER_TOKEN}" > /dev/null

PAST_TIME=$(date -u -v-2d +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -d "-2 days" +"%Y-%m-%dT%H:%M:%S.000Z")

echo "== booking with a past startTime should be rejected =="
RESP=$(curl -s -w '\n%{http_code}' -X POST "$BASE_URL/api/client/sessions" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"startTime\":\"${PAST_TIME}\",\"durationMin\":60,\"clientName\":\"Test\"}")
CODE=$(echo "$RESP" | tail -n1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$CODE" = "400" ]; then
  pass "past booking rejected (400: $BODY)"
else
  echo "FAIL: expected 400 for past startTime, got $CODE ($BODY)"
  cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" > /dev/null
  exit 1
fi

echo "== booking with a future startTime still works =="
FUTURE_TIME=$(iso_in_days 1)
FUTURE_RESP=$(curl -s -X POST "$BASE_URL/api/client/sessions" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"startTime\":\"${FUTURE_TIME}\",\"durationMin\":60,\"clientName\":\"Test\"}")
SESSION_ID=$(echo "$FUTURE_RESP" | jq -r '.session.id')
require "future booking" "$SESSION_ID"
pass "future booking still works"

echo "== cleanup =="
cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" | jq
pass "past booking validation E2E test"
