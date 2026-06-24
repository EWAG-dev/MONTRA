#!/usr/bin/env bash
# E2E test for Impact Credits.
# Covers: booking a session unlocks a $10 credit, the client lists it as "unlocked",
# directing it to a cause requires a valid cause, a different client can't direct it
# (403), directing flips status to "directed", re-directing is blocked (409), and the
# community aggregate reflects the directed amount.
# Run against production; requires ALLOW_DEV_ENDPOINTS=true on Railway + admin account.
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_TRAINER_EMAIL="e2e-impact-trainer@example.com"
TEST_TRAINER_PASSWORD="TempTest123!"
TEST_CLIENT_EMAIL="e2e-impact-client@example.com"
TEST_CLIENT_PASSWORD="TempTest123!"
OTHER_CLIENT_EMAIL="e2e-impact-other-client@example.com"

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== creating trainer + two clients =="
TRAINER_UID=$(create_test_trainer "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD" "E2E Impact Trainer")
require "trainer creation" "$TRAINER_UID"
CLIENT_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E Impact Client")
require "client creation" "$CLIENT_UID"
OTHER_CLIENT_UID=$(create_test_client "$ADMIN_TOKEN" "$OTHER_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E Other Client")
require "other client creation" "$OTHER_CLIENT_UID"

# Always clean up, even on a mid-test failure.
trap 'cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" > /dev/null 2>&1; cleanup_test_data "$ADMIN_TOKEN" "" "$OTHER_CLIENT_UID" > /dev/null 2>&1' EXIT

TRAINER_TOKEN=$(sign_in "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD")
CLIENT_TOKEN=$(sign_in "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD")
OTHER_CLIENT_TOKEN=$(sign_in "$OTHER_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD")
TRAINER_DOC_ID=$(trainer_doc_id_by_email "$TEST_TRAINER_EMAIL")
require "trainer doc id" "$TRAINER_DOC_ID"

echo "== client requests trainer, trainer accepts =="
REQ=$(curl -s -X POST "$BASE_URL/api/client/requests" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"clientProfile\":{\"firstName\":\"Impact\"}}")
REQUEST_ID=$(echo "$REQ" | jq -r '.request.id')
require "client request" "$REQUEST_ID"
curl -s -X POST "$BASE_URL/api/trainers/matches/${REQUEST_ID}/accept" -H "Authorization: Bearer ${TRAINER_TOKEN}" > /dev/null

echo "== booking a session unlocks a \$10 impact credit =="
START_TIME=$(iso_in_days 3)
BOOK=$(curl -s -X POST "$BASE_URL/api/client/sessions" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"startTime\":\"${START_TIME}\",\"durationMin\":60,\"clientName\":\"E2E Impact Client\"}")
SESSION_ID=$(echo "$BOOK" | jq -r '.session.id')
require "booking" "$SESSION_ID"
CREDIT_ID=$(echo "$BOOK" | jq -r '.impactCredit.id')
require "credit unlocked on booking" "$CREDIT_ID"
[ "$(echo "$BOOK" | jq -r '.impactCredit.amount')" = "10" ] || { echo "FAIL: credit amount not 10 ($BOOK)"; exit 1; }
[ "$(echo "$BOOK" | jq -r '.impactCredit.status')" = "unlocked" ] || { echo "FAIL: credit not unlocked"; exit 1; }
pass "booking unlocked a \$10 credit"

echo "== the credit appears in the client's impact-credits list =="
LIST=$(curl -s "$BASE_URL/api/client/impact-credits" -H "Authorization: Bearer ${CLIENT_TOKEN}")
[ "$(echo "$LIST" | jq -r --arg id "$CREDIT_ID" '.impactCredits[] | select(.id==$id) | .status')" = "unlocked" ] || { echo "FAIL: credit not in client list ($LIST)"; exit 1; }
pass "client sees the unlocked credit"

echo "== directing requires a valid cause for a donate (400) =="
BADCAUSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/client/impact-credits/${CREDIT_ID}/direct" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" -d '{"type":"donate","causeId":"not_real"}')
[ "$BADCAUSE" = "400" ] || { echo "FAIL: expected 400 invalid cause, got $BADCAUSE"; exit 1; }
pass "donate with invalid cause rejected (400)"

echo "== a different client cannot direct this credit (403) =="
OTHER_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/client/impact-credits/${CREDIT_ID}/direct" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${OTHER_CLIENT_TOKEN}" -d '{"type":"donate","causeId":"mental_wellness"}')
[ "$OTHER_CODE" = "403" ] || { echo "FAIL: expected 403 cross-client direct, got $OTHER_CODE"; exit 1; }
pass "cross-client direct blocked (403)"

echo "== capture community total before, then direct the credit =="
BEFORE=$(curl -s "$BASE_URL/api/impact/community" | jq -r '.community.amountDirected')
require "community before" "$BEFORE"

DIRECT=$(curl -s -X POST "$BASE_URL/api/client/impact-credits/${CREDIT_ID}/direct" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" -d '{"type":"donate","causeId":"mental_wellness"}')
[ "$(echo "$DIRECT" | jq -r '.impactCredit.status')" = "directed" ] || { echo "FAIL: credit not directed ($DIRECT)"; exit 1; }
[ "$(echo "$DIRECT" | jq -r '.impactCredit.allocation.type')" = "donate" ] || { echo "FAIL: allocation type wrong"; exit 1; }
[ "$(echo "$DIRECT" | jq -r '.impactCredit.allocation.causeLabel')" = "Mental Wellness" ] || { echo "FAIL: cause label wrong"; exit 1; }
pass "credit directed to Mental Wellness"

echo "== re-directing an already-directed credit is blocked (409) =="
REDIR=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/client/impact-credits/${CREDIT_ID}/direct" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" -d '{"type":"coaching"}')
[ "$REDIR" = "409" ] || { echo "FAIL: expected 409 re-direct, got $REDIR"; exit 1; }
pass "re-directing blocked (409)"

echo "== community total increased by \$10 =="
AFTER=$(curl -s "$BASE_URL/api/impact/community" | jq -r '.community.amountDirected')
[ "$AFTER" = "$((BEFORE + 10))" ] || { echo "FAIL: community total expected $((BEFORE + 10)), got $AFTER"; exit 1; }
pass "community amount reflects the \$10 credit"

echo "== cleanup =="
cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" | jq
cleanup_test_data "$ADMIN_TOKEN" "" "$OTHER_CLIENT_UID" | jq
pass "impact credits E2E test"
