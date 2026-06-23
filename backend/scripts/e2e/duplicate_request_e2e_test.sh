#!/usr/bin/env bash
# Tests that submitting the same client→trainer match request twice is handled
# correctly (idempotent — second call returns the existing request, not a new one).
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_TRAINER_EMAIL="e2e-dupcheck-trainer@example.com"
TEST_TRAINER_PASSWORD="TempTest123!"
TEST_CLIENT_EMAIL="e2e-dupcheck-client@example.com"
TEST_CLIENT_PASSWORD="TempTest123!"

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== creating test trainer + client =="
TRAINER_UID=$(create_test_trainer "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD" "E2E DupCheck Trainer")
require "trainer creation" "$TRAINER_UID"
CLIENT_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E DupCheck Client")
require "client creation" "$CLIENT_UID"

CLIENT_TOKEN=$(sign_in "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD")
TRAINER_DOC_ID=$(trainer_doc_id_by_email "$TEST_TRAINER_EMAIL")
require "trainer doc id" "$TRAINER_DOC_ID"

echo "== first request =="
REQ1=$(curl -s -X POST "$BASE_URL/api/client/requests" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"clientProfile\":{\"firstName\":\"E2E\"}}")
ID1=$(echo "$REQ1" | jq -r '.request.id')
require "first request id" "$ID1"
pass "first request created (id: $ID1)"

echo "== second request to same trainer =="
REQ2=$(curl -s -X POST "$BASE_URL/api/client/requests" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"clientProfile\":{\"firstName\":\"E2E\"}}")
ID2=$(echo "$REQ2" | jq -r '.request.id')
require "second request id" "$ID2"

if [ "$ID1" = "$ID2" ]; then
  pass "duplicate request correctly returned existing (idempotent)"
else
  echo "FAIL: duplicate created a NEW request — got $ID2, expected $ID1"
  echo "  first:  $REQ1"
  echo "  second: $REQ2"
  cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" > /dev/null
  exit 1
fi

echo "== list confirms only one request exists for this trainer =="
REQUESTS=$(curl -s "$BASE_URL/api/client/requests" -H "Authorization: Bearer ${CLIENT_TOKEN}")
COUNT=$(echo "$REQUESTS" | jq "[.requests[] | select(.trainerId==\"${TRAINER_DOC_ID}\")] | length")
[ "$COUNT" = "1" ] || { echo "FAIL: expected 1 request, found $COUNT"; cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" > /dev/null; exit 1; }
pass "only one request in client's list"

echo "== cleanup =="
cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" | jq
pass "duplicate request E2E test"
