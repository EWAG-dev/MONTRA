#!/usr/bin/env bash
# E2E test for the notification feed — covers all 4 notification categories:
# trainer: new client request, new session booked, new message from client
# client: coach accepted request, new message from trainer
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_TRAINER_EMAIL="e2e-notif-trainer@example.com"
TEST_TRAINER_PASSWORD="TempTest123!"
TEST_CLIENT_EMAIL="e2e-notif-client@example.com"
TEST_CLIENT_PASSWORD="TempTest123!"

echo "== setup =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"
TRAINER_UID=$(create_test_trainer "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD" "E2E Notif Trainer")
require "trainer" "$TRAINER_UID"
CLIENT_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E Notif Client")
require "client" "$CLIENT_UID"
TRAINER_TOKEN=$(sign_in "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD")
CLIENT_TOKEN=$(sign_in "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD")
TRAINER_DOC_ID=$(trainer_doc_id_by_email "$TEST_TRAINER_EMAIL")
require "trainer doc id" "$TRAINER_DOC_ID"

cleanup_all() {
  cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" > /dev/null
}

echo "== [TRAINER] pending request → notification appears =="
REQUEST_ID=$(curl -s -X POST "$BASE_URL/api/client/requests" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"clientProfile\":{\"firstName\":\"E2E\"}}" | jq -r '.request.id')
require "request" "$REQUEST_ID"
TRAINER_NOTIFS=$(curl -s "$BASE_URL/api/notifications/my" -H "Authorization: Bearer ${TRAINER_TOKEN}")
HAS_REQUEST=$(echo "$TRAINER_NOTIFS" | jq --arg id "req_${REQUEST_ID}" '[.notifications[] | select(.id==$id)] | length')
[ "$HAS_REQUEST" = "1" ] || { echo "FAIL: trainer should see 'New client request' notification (got $(echo "$TRAINER_NOTIFS" | jq '.notifications | length') notifications)"; cleanup_all; exit 1; }
pass "trainer sees 'New client request' notification"

echo "== trainer accepts → request notification gone, client sees acceptance =="
curl -s -X POST "$BASE_URL/api/trainers/matches/${REQUEST_ID}/accept" -H "Authorization: Bearer ${TRAINER_TOKEN}" > /dev/null
TRAINER_NOTIFS2=$(curl -s "$BASE_URL/api/notifications/my" -H "Authorization: Bearer ${TRAINER_TOKEN}")
STILL_PENDING=$(echo "$TRAINER_NOTIFS2" | jq --arg id "req_${REQUEST_ID}" '[.notifications[] | select(.id==$id)] | length')
[ "$STILL_PENDING" = "0" ] || { echo "FAIL: accepted request should no longer appear as 'pending' notification"; cleanup_all; exit 1; }
pass "accepted request no longer shows in trainer notifications"
CLIENT_NOTIFS=$(curl -s "$BASE_URL/api/notifications/my" -H "Authorization: Bearer ${CLIENT_TOKEN}")
HAS_ACCEPTED=$(echo "$CLIENT_NOTIFS" | jq --arg id "acc_${REQUEST_ID}" '[.notifications[] | select(.id==$id)] | length')
[ "$HAS_ACCEPTED" = "1" ] || { echo "FAIL: client should see 'Your coach accepted' notification"; cleanup_all; exit 1; }
pass "client sees 'Your coach accepted' notification"

echo "== client books session → trainer sees 'New session booked' =="
SESSION_ID=$(curl -s -X POST "$BASE_URL/api/client/sessions" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"startTime\":\"$(iso_in_days 1)\",\"durationMin\":60,\"clientName\":\"E2E Notif Client\"}" | jq -r '.session.id')
require "session" "$SESSION_ID"
TRAINER_NOTIFS3=$(curl -s "$BASE_URL/api/notifications/my" -H "Authorization: Bearer ${TRAINER_TOKEN}")
HAS_SESSION=$(echo "$TRAINER_NOTIFS3" | jq --arg id "sess_${SESSION_ID}" '[.notifications[] | select(.id==$id)] | length')
[ "$HAS_SESSION" = "1" ] || { echo "FAIL: trainer should see 'New session booked' notification"; cleanup_all; exit 1; }
pass "trainer sees 'New session booked' notification"

echo "== client sends message → trainer sees message notification =="
CONVO_ID=$(curl -s -X POST "$BASE_URL/api/trainers/matches/${REQUEST_ID}/open-chat" \
  -H "Authorization: Bearer ${TRAINER_TOKEN}" | jq -r '.conversation.id')
require "conversation" "$CONVO_ID"
curl -s -X POST "$BASE_URL/api/conversations/${CONVO_ID}/messages" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d '{"text":"Hey trainer!"}' > /dev/null
TRAINER_NOTIFS4=$(curl -s "$BASE_URL/api/notifications/my" -H "Authorization: Bearer ${TRAINER_TOKEN}")
HAS_MSG=$(echo "$TRAINER_NOTIFS4" | jq --arg id "msg_${CONVO_ID}" '[.notifications[] | select(.id==$id)] | length')
[ "$HAS_MSG" = "1" ] || { echo "FAIL: trainer should see message notification from client"; cleanup_all; exit 1; }
pass "trainer sees client message notification"

echo "== trainer replies → client sees message notification =="
curl -s -X POST "$BASE_URL/api/conversations/${CONVO_ID}/messages" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${TRAINER_TOKEN}" \
  -d '{"text":"Hey client!"}' > /dev/null
CLIENT_NOTIFS2=$(curl -s "$BASE_URL/api/notifications/my" -H "Authorization: Bearer ${CLIENT_TOKEN}")
HAS_CLIENT_MSG=$(echo "$CLIENT_NOTIFS2" | jq --arg id "msg_${CONVO_ID}" '[.notifications[] | select(.id==$id)] | length')
[ "$HAS_CLIENT_MSG" = "1" ] || { echo "FAIL: client should see message notification from trainer"; cleanup_all; exit 1; }
pass "client sees trainer message notification"

echo "== cleanup =="
cleanup_all
pass "notification E2E test"
