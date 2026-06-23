#!/usr/bin/env bash
# E2E test: client requests trainer -> trainer accepts (opens conversation thread implicitly
# via accept's conversationId) -> trainer opens chat -> both sides exchange messages -> verify
# both see the full thread and that auth boundaries hold (a third party can't read it).
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_TRAINER_EMAIL="e2e-chat-trainer@example.com"
TEST_TRAINER_PASSWORD="TempTest123!"
TEST_CLIENT_EMAIL="e2e-chat-client@example.com"
TEST_CLIENT_PASSWORD="TempTest123!"
TEST_OUTSIDER_EMAIL="e2e-chat-outsider@example.com"
TEST_OUTSIDER_PASSWORD="TempTest123!"

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== creating test trainer + client + outsider client =="
TRAINER_UID=$(create_test_trainer "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD" "E2E Chat Trainer")
require "trainer creation" "$TRAINER_UID"
CLIENT_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E Chat Client")
require "client creation" "$CLIENT_UID"
OUTSIDER_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_OUTSIDER_EMAIL" "$TEST_OUTSIDER_PASSWORD" "E2E Chat Outsider")
require "outsider creation" "$OUTSIDER_UID"

TRAINER_TOKEN=$(sign_in "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD")
CLIENT_TOKEN=$(sign_in "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD")
OUTSIDER_TOKEN=$(sign_in "$TEST_OUTSIDER_EMAIL" "$TEST_OUTSIDER_PASSWORD")
TRAINER_DOC_ID=$(trainer_doc_id_by_email "$TEST_TRAINER_EMAIL")
require "trainer doc id" "$TRAINER_DOC_ID"

cleanup_all() {
  cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" > /dev/null
  cleanup_test_data "$ADMIN_TOKEN" "" "$OUTSIDER_UID" > /dev/null
}

echo "== client requests trainer =="
REQUEST_ID=$(curl -s -X POST "$BASE_URL/api/client/requests" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"clientProfile\":{\"firstName\":\"E2E\"}}" | jq -r '.request.id')
require "client request" "$REQUEST_ID"

echo "== trainer accepts =="
curl -s -X POST "$BASE_URL/api/trainers/matches/${REQUEST_ID}/accept" -H "Authorization: Bearer ${TRAINER_TOKEN}" > /dev/null

echo "== trainer opens chat =="
OPEN_RESP=$(curl -s -X POST "$BASE_URL/api/trainers/matches/${REQUEST_ID}/open-chat" -H "Authorization: Bearer ${TRAINER_TOKEN}")
CONVERSATION_ID=$(echo "$OPEN_RESP" | jq -r '.conversation.id')
require "conversation id" "$CONVERSATION_ID"
pass "trainer opened conversation thread"

echo "== trainer sends a message =="
MSG1=$(curl -s -X POST "$BASE_URL/api/conversations/${CONVERSATION_ID}/messages" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${TRAINER_TOKEN}" \
  -d '{"text":"Hi from trainer"}')
MSG1_ID=$(echo "$MSG1" | jq -r '.message.id')
require "trainer message send" "$MSG1_ID"
[ "$(echo "$MSG1" | jq -r '.message.senderRole')" = "trainer" ] || { echo "FAIL: expected senderRole=trainer"; cleanup_all; exit 1; }
pass "trainer message sent with correct senderRole"

echo "== client replies =="
MSG2=$(curl -s -X POST "$BASE_URL/api/conversations/${CONVERSATION_ID}/messages" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d '{"text":"Hi from client"}')
MSG2_ID=$(echo "$MSG2" | jq -r '.message.id')
require "client message send" "$MSG2_ID"
[ "$(echo "$MSG2" | jq -r '.message.senderRole')" = "client" ] || { echo "FAIL: expected senderRole=client"; cleanup_all; exit 1; }
pass "client message sent with correct senderRole"

echo "== both sides see full thread (2 messages) =="
TRAINER_COUNT=$(curl -s "$BASE_URL/api/conversations/${CONVERSATION_ID}/messages" -H "Authorization: Bearer ${TRAINER_TOKEN}" | jq '.messages | length')
CLIENT_COUNT=$(curl -s "$BASE_URL/api/conversations/${CONVERSATION_ID}/messages" -H "Authorization: Bearer ${CLIENT_TOKEN}" | jq '.messages | length')
[ "$TRAINER_COUNT" = "2" ] || { echo "FAIL: trainer sees $TRAINER_COUNT messages, expected 2"; cleanup_all; exit 1; }
[ "$CLIENT_COUNT" = "2" ] || { echo "FAIL: client sees $CLIENT_COUNT messages, expected 2"; cleanup_all; exit 1; }
pass "both sides see the full 2-message thread"

echo "== my-threads lists this conversation for both roles =="
TRAINER_HAS_THREAD=$(curl -s "$BASE_URL/api/conversations/my-threads" -H "Authorization: Bearer ${TRAINER_TOKEN}" | jq -r --arg id "$CONVERSATION_ID" '.conversations[] | select(.id==$id) | .id')
require "trainer my-threads" "$TRAINER_HAS_THREAD"
CLIENT_HAS_THREAD=$(curl -s "$BASE_URL/api/conversations/my-threads" -H "Authorization: Bearer ${CLIENT_TOKEN}" | jq -r --arg id "$CONVERSATION_ID" '.conversations[] | select(.id==$id) | .id')
require "client my-threads" "$CLIENT_HAS_THREAD"
pass "conversation shows up in my-threads for both roles"

echo "== outsider cannot read or post to this conversation =="
OUTSIDER_READ=$(curl -s -w '\n%{http_code}' "$BASE_URL/api/conversations/${CONVERSATION_ID}/messages" -H "Authorization: Bearer ${OUTSIDER_TOKEN}")
OUTSIDER_READ_CODE=$(echo "$OUTSIDER_READ" | tail -n1)
[ "$OUTSIDER_READ_CODE" = "403" ] || { echo "FAIL: outsider read expected 403, got $OUTSIDER_READ_CODE ($(echo "$OUTSIDER_READ" | sed '$d'))"; cleanup_all; exit 1; }
pass "outsider blocked from reading conversation (403)"

OUTSIDER_WRITE=$(curl -s -w '\n%{http_code}' -X POST "$BASE_URL/api/conversations/${CONVERSATION_ID}/messages" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${OUTSIDER_TOKEN}" -d '{"text":"intruding"}')
OUTSIDER_WRITE_CODE=$(echo "$OUTSIDER_WRITE" | tail -n1)
[ "$OUTSIDER_WRITE_CODE" = "403" ] || { echo "FAIL: outsider write expected 403, got $OUTSIDER_WRITE_CODE ($(echo "$OUTSIDER_WRITE" | sed '$d'))"; cleanup_all; exit 1; }
pass "outsider blocked from posting to conversation (403)"

echo "== cleanup =="
cleanup_all
pass "chat E2E test"
