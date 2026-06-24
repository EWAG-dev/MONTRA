#!/usr/bin/env bash
# E2E test for session completion marking (POST /api/{trainers,client}/sessions/:id/complete).
# Books a session a few seconds in the future, waits for it to start, then verifies:
#   - a future session cannot be completed (409)
#   - the trainer can mark a started session complete (status -> "completed")
#   - a cancelled session cannot be completed (409)
# Run against production; requires ALLOW_DEV_ENDPOINTS=true on Railway + admin account.
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_TRAINER_EMAIL="e2e-complete-trainer@example.com"
TEST_TRAINER_PASSWORD="TempTest123!"
TEST_CLIENT_EMAIL="e2e-complete-client@example.com"
TEST_CLIENT_PASSWORD="TempTest123!"

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== creating test trainer (approved) =="
TRAINER_UID=$(create_test_trainer "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD" "E2E Complete Trainer")
require "trainer creation" "$TRAINER_UID"

echo "== creating test client =="
CLIENT_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E Complete Client")
require "client creation" "$CLIENT_UID"

echo "== signing in trainer + client =="
TRAINER_TOKEN=$(sign_in "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD")
CLIENT_TOKEN=$(sign_in "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD")

echo "== looking up trainer doc id via directory =="
TRAINER_DOC_ID=$(trainer_doc_id_by_email "$TEST_TRAINER_EMAIL")
require "trainer doc id" "$TRAINER_DOC_ID"

echo "== client requests trainer, trainer accepts =="
REQUEST_RESP=$(curl -s -X POST "$BASE_URL/api/client/requests" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"clientProfile\":{\"firstName\":\"E2E\"}}")
REQUEST_ID=$(echo "$REQUEST_RESP" | jq -r '.request.id')
require "client request" "$REQUEST_ID"
curl -s -X POST "$BASE_URL/api/trainers/matches/${REQUEST_ID}/accept" -H "Authorization: Bearer ${TRAINER_TOKEN}" > /dev/null

echo "== client books a near-future session (starts in ~5s) =="
START_TIME=$(iso_in_seconds 5)
BOOK_RESP=$(curl -s -X POST "$BASE_URL/api/client/sessions" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"startTime\":\"${START_TIME}\",\"durationMin\":60,\"clientName\":\"E2E Complete Client\"}")
SESSION_ID=$(echo "$BOOK_RESP" | jq -r '.session.id')
require "booking" "$SESSION_ID"

echo "== completing a not-yet-started session should be rejected (409) =="
EARLY_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/trainers/sessions/${SESSION_ID}/complete" \
  -H "Authorization: Bearer ${TRAINER_TOKEN}")
if [ "$EARLY_CODE" = "409" ]; then
  pass "future session cannot be completed (409)"
else
  echo "FAIL: expected 409 completing a future session, got $EARLY_CODE" >&2
  cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" > /dev/null
  exit 1
fi

echo "== waiting for the session start time to pass =="
sleep 7

echo "== trainer marks session complete =="
COMPLETE_RESP=$(curl -s -X POST "$BASE_URL/api/trainers/sessions/${SESSION_ID}/complete" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${TRAINER_TOKEN}" \
  -d "{\"notes\":\"Great session, hit all sets.\"}")
STATUS=$(echo "$COMPLETE_RESP" | jq -r '.session.status')
require "completion status" "$STATUS"
if [ "$STATUS" = "completed" ]; then
  pass "trainer marked session complete"
else
  echo "FAIL: expected status 'completed', got '$STATUS' ($COMPLETE_RESP)" >&2
  cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" > /dev/null
  exit 1
fi

NOTES=$(echo "$COMPLETE_RESP" | jq -r '.session.completionNotes')
[ "$NOTES" = "Great session, hit all sets." ] && pass "completion notes persisted" || echo "WARN: completion notes not persisted ($NOTES)"

echo "== both parties see the completed status =="
CLIENT_STATUS=$(curl -s "$BASE_URL/api/client/sessions" -H "Authorization: Bearer ${CLIENT_TOKEN}" | jq -r --arg id "$SESSION_ID" '.sessions[] | select(.id==$id) | .status')
[ "$CLIENT_STATUS" = "completed" ] && pass "client sees completed session" || { echo "FAIL: client status $CLIENT_STATUS" >&2; cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" > /dev/null; exit 1; }

echo "== cancelled session cannot be completed (409) =="
START_TIME2=$(iso_in_days 1)
BOOK2=$(curl -s -X POST "$BASE_URL/api/client/sessions" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"startTime\":\"${START_TIME2}\",\"durationMin\":60,\"clientName\":\"E2E Complete Client\"}")
SESSION_ID2=$(echo "$BOOK2" | jq -r '.session.id')
require "second booking" "$SESSION_ID2"
curl -s -X POST "$BASE_URL/api/client/sessions/${SESSION_ID2}/cancel" -H "Authorization: Bearer ${CLIENT_TOKEN}" > /dev/null
CANCEL_COMPLETE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/trainers/sessions/${SESSION_ID2}/complete" \
  -H "Authorization: Bearer ${TRAINER_TOKEN}")
[ "$CANCEL_COMPLETE_CODE" = "409" ] && pass "cancelled session cannot be completed (409)" || { echo "FAIL: expected 409, got $CANCEL_COMPLETE_CODE" >&2; cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" > /dev/null; exit 1; }

echo "== cleanup =="
cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" | jq
pass "complete session E2E test"
