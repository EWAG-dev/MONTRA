#!/usr/bin/env bash
# E2E test: trainer declines a client's request -> client should be blocked from booking (403).
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_TRAINER_EMAIL="e2e-decline-trainer@example.com"
TEST_TRAINER_PASSWORD="TempTest123!"
TEST_CLIENT_EMAIL="e2e-decline-client@example.com"
TEST_CLIENT_PASSWORD="TempTest123!"

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== creating test trainer + client =="
TRAINER_UID=$(create_test_trainer "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD" "E2E Decline Trainer")
require "trainer creation" "$TRAINER_UID"
CLIENT_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E Decline Client")
require "client creation" "$CLIENT_UID"

TRAINER_TOKEN=$(sign_in "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD")
CLIENT_TOKEN=$(sign_in "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD")
TRAINER_DOC_ID=$(trainer_doc_id_by_email "$TEST_TRAINER_EMAIL")
require "trainer doc id" "$TRAINER_DOC_ID"

echo "== client requests trainer =="
REQUEST_RESP=$(curl -s -X POST "$BASE_URL/api/client/requests" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"clientProfile\":{\"firstName\":\"E2E\"}}")
REQUEST_ID=$(echo "$REQUEST_RESP" | jq -r '.request.id')
require "client request" "$REQUEST_ID"

echo "== trainer declines request =="
DECLINE_RESP=$(curl -s -X POST "$BASE_URL/api/trainers/matches/${REQUEST_ID}/decline" -H "Authorization: Bearer ${TRAINER_TOKEN}")
DECLINE_STATUS=$(echo "$DECLINE_RESP" | jq -r '.request.status')
[ "$DECLINE_STATUS" = "declined" ] || { echo "FAIL: expected status=declined, got $DECLINE_STATUS ($DECLINE_RESP)"; exit 1; }
pass "request marked declined"

echo "== client attempts to book anyway (should be blocked) =="
START_TIME=$(iso_in_days 1)
BOOK_RESP=$(curl -s -w '\n%{http_code}' -X POST "$BASE_URL/api/client/sessions" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"startTime\":\"${START_TIME}\",\"durationMin\":60,\"clientName\":\"E2E Decline Client\"}")
HTTP_CODE=$(echo "$BOOK_RESP" | tail -n1)
BODY=$(echo "$BOOK_RESP" | sed '$d')
if [ "$HTTP_CODE" = "403" ]; then
  pass "booking correctly blocked with 403 ($BODY)"
else
  echo "FAIL: expected 403, got $HTTP_CODE ($BODY)"
  echo "== cleanup (after failure) =="
  cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" > /dev/null
  exit 1
fi

echo "== cleanup =="
cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" | jq
pass "decline E2E test"
