#!/usr/bin/env bash
# E2E test: book a session, cancel it from the client side, verify status=cancelled on both
# sides; book a second session, cancel it from the trainer side, verify same.
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_TRAINER_EMAIL="e2e-cancel-trainer@example.com"
TEST_TRAINER_PASSWORD="TempTest123!"
TEST_CLIENT_EMAIL="e2e-cancel-client@example.com"
TEST_CLIENT_PASSWORD="TempTest123!"

book_session() {
  local trainer_doc_id="$1" client_token="$2" start_time="$3"
  curl -s -X POST "$BASE_URL/api/client/sessions" \
    -H "Content-Type: application/json" -H "Authorization: Bearer ${client_token}" \
    -d "{\"trainerId\":\"${trainer_doc_id}\",\"startTime\":\"${start_time}\",\"durationMin\":60,\"clientName\":\"E2E Cancel Client\"}" \
    | jq -r '.session.id'
}

session_status_for_client() {
  curl -s "$BASE_URL/api/client/sessions" -H "Authorization: Bearer $1" | jq -r --arg id "$2" '.sessions[] | select(.id==$id) | .status'
}

session_status_for_trainer() {
  curl -s "$BASE_URL/api/trainers/my-sessions" -H "Authorization: Bearer $1" | jq -r --arg id "$2" '.sessions[] | select(.id==$id) | .status'
}

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== creating test trainer + client =="
TRAINER_UID=$(create_test_trainer "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD" "E2E Cancel Trainer")
require "trainer creation" "$TRAINER_UID"
CLIENT_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E Cancel Client")
require "client creation" "$CLIENT_UID"

TRAINER_TOKEN=$(sign_in "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD")
CLIENT_TOKEN=$(sign_in "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD")
TRAINER_DOC_ID=$(trainer_doc_id_by_email "$TEST_TRAINER_EMAIL")
require "trainer doc id" "$TRAINER_DOC_ID"

echo "== client requests trainer, trainer accepts =="
REQUEST_ID=$(curl -s -X POST "$BASE_URL/api/client/requests" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"clientProfile\":{\"firstName\":\"E2E\"}}" | jq -r '.request.id')
require "client request" "$REQUEST_ID"
curl -s -X POST "$BASE_URL/api/trainers/matches/${REQUEST_ID}/accept" -H "Authorization: Bearer ${TRAINER_TOKEN}" > /dev/null

echo "== book + cancel from client side =="
SESSION_A=$(book_session "$TRAINER_DOC_ID" "$CLIENT_TOKEN" "$(iso_in_days 1)")
require "booking A" "$SESSION_A"
curl -s -X POST "$BASE_URL/api/client/sessions/${SESSION_A}/cancel" -H "Authorization: Bearer ${CLIENT_TOKEN}" > /dev/null

CLIENT_STATUS_A=$(session_status_for_client "$CLIENT_TOKEN" "$SESSION_A")
[ "$CLIENT_STATUS_A" = "cancelled" ] || { echo "FAIL: client-side cancel — expected cancelled, got $CLIENT_STATUS_A"; exit 1; }
pass "client-cancelled session shows cancelled to client"

TRAINER_STATUS_A=$(session_status_for_trainer "$TRAINER_TOKEN" "$SESSION_A")
[ "$TRAINER_STATUS_A" = "cancelled" ] || { echo "FAIL: client-side cancel — expected cancelled on trainer view, got $TRAINER_STATUS_A"; exit 1; }
pass "client-cancelled session shows cancelled to trainer"

echo "== book + cancel from trainer side =="
SESSION_B=$(book_session "$TRAINER_DOC_ID" "$CLIENT_TOKEN" "$(iso_in_days 2)")
require "booking B" "$SESSION_B"
curl -s -X POST "$BASE_URL/api/trainers/sessions/${SESSION_B}/cancel" -H "Authorization: Bearer ${TRAINER_TOKEN}" > /dev/null

CLIENT_STATUS_B=$(session_status_for_client "$CLIENT_TOKEN" "$SESSION_B")
[ "$CLIENT_STATUS_B" = "cancelled" ] || { echo "FAIL: trainer-side cancel — expected cancelled on client view, got $CLIENT_STATUS_B"; exit 1; }
pass "trainer-cancelled session shows cancelled to client"

TRAINER_STATUS_B=$(session_status_for_trainer "$TRAINER_TOKEN" "$SESSION_B")
[ "$TRAINER_STATUS_B" = "cancelled" ] || { echo "FAIL: trainer-side cancel — expected cancelled to trainer, got $TRAINER_STATUS_B"; exit 1; }
pass "trainer-cancelled session shows cancelled to trainer"

echo "== cleanup =="
cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" | jq
pass "cancel E2E test"
