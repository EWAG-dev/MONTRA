#!/usr/bin/env bash
# E2E test: two different clients try to book the same trainer at the same startTime ->
# second booking should be rejected with the same-slot conflict check in sessionStore.js.
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_TRAINER_EMAIL="e2e-conflict-trainer@example.com"
TEST_TRAINER_PASSWORD="TempTest123!"
TEST_CLIENT_A_EMAIL="e2e-conflict-client-a@example.com"
TEST_CLIENT_B_EMAIL="e2e-conflict-client-b@example.com"
TEST_CLIENT_PASSWORD="TempTest123!"

request_and_accept() {
  local trainer_doc_id="$1" client_token="$2" trainer_token="$3"
  local request_id
  request_id=$(curl -s -X POST "$BASE_URL/api/client/requests" \
    -H "Content-Type: application/json" -H "Authorization: Bearer ${client_token}" \
    -d "{\"trainerId\":\"${trainer_doc_id}\",\"clientProfile\":{\"firstName\":\"E2E\"}}" | jq -r '.request.id')
  curl -s -X POST "$BASE_URL/api/trainers/matches/${request_id}/accept" -H "Authorization: Bearer ${trainer_token}" > /dev/null
}

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== creating test trainer + two clients =="
TRAINER_UID=$(create_test_trainer "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD" "E2E Conflict Trainer")
require "trainer creation" "$TRAINER_UID"
CLIENT_A_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT_A_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E Conflict Client A")
require "client A creation" "$CLIENT_A_UID"
CLIENT_B_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT_B_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E Conflict Client B")
require "client B creation" "$CLIENT_B_UID"

TRAINER_TOKEN=$(sign_in "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD")
CLIENT_A_TOKEN=$(sign_in "$TEST_CLIENT_A_EMAIL" "$TEST_CLIENT_PASSWORD")
CLIENT_B_TOKEN=$(sign_in "$TEST_CLIENT_B_EMAIL" "$TEST_CLIENT_PASSWORD")
TRAINER_DOC_ID=$(trainer_doc_id_by_email "$TEST_TRAINER_EMAIL")
require "trainer doc id" "$TRAINER_DOC_ID"

cleanup_both() {
  cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_A_UID" > /dev/null
  cleanup_test_data "$ADMIN_TOKEN" "" "$CLIENT_B_UID" > /dev/null
}

echo "== both clients request + get accepted by the trainer =="
request_and_accept "$TRAINER_DOC_ID" "$CLIENT_A_TOKEN" "$TRAINER_TOKEN"
request_and_accept "$TRAINER_DOC_ID" "$CLIENT_B_TOKEN" "$TRAINER_TOKEN"

START_TIME=$(iso_in_days 1)

echo "== client A books the slot =="
SESSION_A=$(curl -s -X POST "$BASE_URL/api/client/sessions" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_A_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"startTime\":\"${START_TIME}\",\"durationMin\":60,\"clientName\":\"Client A\"}" | jq -r '.session.id')
require "booking A" "$SESSION_A"
pass "client A booked the slot"

echo "== client B tries to book the same slot (should be rejected) =="
RESP=$(curl -s -w '\n%{http_code}' -X POST "$BASE_URL/api/client/sessions" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_B_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"startTime\":\"${START_TIME}\",\"durationMin\":60,\"clientName\":\"Client B\"}")
HTTP_CODE=$(echo "$RESP" | tail -n1)
BODY=$(echo "$RESP" | sed '$d')
if [ "$HTTP_CODE" = "400" ] && echo "$BODY" | jq -e '.error | test("already booked")' > /dev/null; then
  pass "double-booking correctly rejected ($BODY)"
else
  echo "FAIL: expected 400 'already booked', got $HTTP_CODE ($BODY)"
  cleanup_both
  exit 1
fi

echo "== sanity: client B can book a different slot =="
OTHER_START_TIME=$(iso_in_days 3)
SESSION_B=$(curl -s -X POST "$BASE_URL/api/client/sessions" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_B_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"startTime\":\"${OTHER_START_TIME}\",\"durationMin\":60,\"clientName\":\"Client B\"}" | jq -r '.session.id')
require "booking B (different slot)" "$SESSION_B"
pass "client B booked a different slot without issue"

echo "== cleanup =="
cleanup_both
pass "conflict E2E test"
