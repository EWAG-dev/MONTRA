#!/usr/bin/env bash
# Edge case tests for the booking/notification flow:
# 1. Cancelling an already-cancelled session is a safe no-op (200, status stays cancelled)
# 2. After a match is declined, the same client can make a NEW request (re-apply)
# 3. After a session is booked, trainer notification feed reflects it; after cancel, session
#    still shows (as cancelled) so both parties know what happened
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_TRAINER_EMAIL="e2e-edge-trainer@example.com"
TEST_TRAINER_PASSWORD="TempTest123!"
TEST_CLIENT_EMAIL="e2e-edge-client@example.com"
TEST_CLIENT_PASSWORD="TempTest123!"

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== setup: trainer + client =="
TRAINER_UID=$(create_test_trainer "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD" "E2E Edge Trainer")
require "trainer" "$TRAINER_UID"
CLIENT_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E Edge Client")
require "client" "$CLIENT_UID"
TRAINER_TOKEN=$(sign_in "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD")
CLIENT_TOKEN=$(sign_in "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD")
TRAINER_DOC_ID=$(trainer_doc_id_by_email "$TEST_TRAINER_EMAIL")
require "trainer doc id" "$TRAINER_DOC_ID"

# ── Edge case 1: re-apply after declined ────────────────────────────────────

echo "== edge 1: client requests, trainer declines, client re-requests =="
REQ1_ID=$(curl -s -X POST "$BASE_URL/api/client/requests" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"clientProfile\":{\"firstName\":\"E2E\"}}" | jq -r '.request.id')
require "request 1" "$REQ1_ID"

curl -s -X POST "$BASE_URL/api/trainers/matches/${REQ1_ID}/decline" -H "Authorization: Bearer ${TRAINER_TOKEN}" > /dev/null

# Second request after decline should be allowed (creates a new doc, not idempotent-returned)
REQ2_RESP=$(curl -s -X POST "$BASE_URL/api/client/requests" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"clientProfile\":{\"firstName\":\"E2E\"}}")
REQ2_ID=$(echo "$REQ2_RESP" | jq -r '.request.id')
require "request 2 after decline" "$REQ2_ID"
[ "$REQ2_ID" != "$REQ1_ID" ] || { echo "FAIL: re-apply after decline should create a new request, not return the declined one"; exit 1; }
REQ2_STATUS=$(echo "$REQ2_RESP" | jq -r '.request.status')
[ "$REQ2_STATUS" = "pending" ] || { echo "FAIL: new request should be pending, got $REQ2_STATUS"; exit 1; }
pass "client can re-apply after being declined (new pending request created)"

# ── Edge case 2: double-cancel is safe ─────────────────────────────────────

echo "== edge 2: trainer accepts, client books, client cancels twice =="
curl -s -X POST "$BASE_URL/api/trainers/matches/${REQ2_ID}/accept" -H "Authorization: Bearer ${TRAINER_TOKEN}" > /dev/null

SESSION_ID=$(curl -s -X POST "$BASE_URL/api/client/sessions" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"startTime\":\"$(iso_in_days 1)\",\"durationMin\":60,\"clientName\":\"E2E\"}" | jq -r '.session.id')
require "session" "$SESSION_ID"

# First cancel
S1=$(curl -s -X POST "$BASE_URL/api/client/sessions/${SESSION_ID}/cancel" -H "Authorization: Bearer ${CLIENT_TOKEN}")
[ "$(echo "$S1" | jq -r '.session.status')" = "cancelled" ] || { echo "FAIL: first cancel"; exit 1; }
pass "first cancel succeeds"

# Second cancel on same session
HTTP2=$(curl -s -w '\n%{http_code}' -X POST "$BASE_URL/api/client/sessions/${SESSION_ID}/cancel" -H "Authorization: Bearer ${CLIENT_TOKEN}")
CODE2=$(echo "$HTTP2" | tail -n1)
BODY2=$(echo "$HTTP2" | sed '$d')
# Should succeed (idempotent 200) or fail gracefully — NOT crash the server
[ "$CODE2" = "200" ] || [ "$CODE2" = "400" ] || { echo "FAIL: double-cancel returned unexpected HTTP $CODE2: $BODY2"; exit 1; }
pass "double-cancel handled gracefully (HTTP $CODE2)"

# ── Edge case 3: cancelled session still visible in list with status=cancelled ──

echo "== edge 3: cancelled session remains in list (not purged) =="
CLIENT_SESSIONS=$(curl -s "$BASE_URL/api/client/sessions" -H "Authorization: Bearer ${CLIENT_TOKEN}")
SESSION_IN_LIST=$(echo "$CLIENT_SESSIONS" | jq -r --arg id "$SESSION_ID" '.sessions[] | select(.id==$id) | .status')
[ "$SESSION_IN_LIST" = "cancelled" ] || { echo "FAIL: cancelled session missing from list or wrong status: $SESSION_IN_LIST"; exit 1; }
pass "cancelled session retained in client session list with status=cancelled"

TRAINER_SESSIONS=$(curl -s "$BASE_URL/api/trainers/my-sessions" -H "Authorization: Bearer ${TRAINER_TOKEN}")
SESSION_TRAINER=$(echo "$TRAINER_SESSIONS" | jq -r --arg id "$SESSION_ID" '.sessions[] | select(.id==$id) | .status')
[ "$SESSION_TRAINER" = "cancelled" ] || { echo "FAIL: cancelled session missing from trainer list or wrong status: $SESSION_TRAINER"; exit 1; }
pass "cancelled session retained in trainer session list with status=cancelled"

echo "== cleanup =="
cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" | jq
pass "edge cases E2E test"
