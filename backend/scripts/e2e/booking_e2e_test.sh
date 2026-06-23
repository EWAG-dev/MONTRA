#!/usr/bin/env bash
# E2E test for backend-persisted session booking (commits 2249cd3, 54decfe), run against
# production since there's no staging env. Requires ALLOW_DEV_ENDPOINTS=true set temporarily
# on Railway, and an admin account (email in ADMIN_EMAILS) to drive the admin-gated dev endpoints.
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_TRAINER_EMAIL="e2e-booking-trainer@example.com"
TEST_TRAINER_PASSWORD="TempTest123!"
TEST_CLIENT_EMAIL="e2e-booking-client@example.com"
TEST_CLIENT_PASSWORD="TempTest123!"

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== creating test trainer (approved) =="
TRAINER_UID=$(create_test_trainer "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD" "E2E Booking Trainer")
require "trainer creation" "$TRAINER_UID"

echo "== creating test client =="
CLIENT_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E Booking Client")
require "client creation" "$CLIENT_UID"

echo "== signing in trainer + client =="
TRAINER_TOKEN=$(sign_in "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD")
CLIENT_TOKEN=$(sign_in "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD")

echo "== looking up trainer doc id via directory =="
TRAINER_DOC_ID=$(trainer_doc_id_by_email "$TEST_TRAINER_EMAIL")
require "trainer doc id" "$TRAINER_DOC_ID"

echo "== client requests trainer =="
REQUEST_RESP=$(curl -s -X POST "$BASE_URL/api/client/requests" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"clientProfile\":{\"firstName\":\"E2E\"}}")
REQUEST_ID=$(echo "$REQUEST_RESP" | jq -r '.request.id')
require "client request" "$REQUEST_ID"

echo "== trainer accepts request =="
curl -s -X POST "$BASE_URL/api/trainers/matches/${REQUEST_ID}/accept" -H "Authorization: Bearer ${TRAINER_TOKEN}" > /dev/null

echo "== client books a session =="
START_TIME=$(iso_in_days 1)
BOOK_RESP=$(curl -s -X POST "$BASE_URL/api/client/sessions" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"startTime\":\"${START_TIME}\",\"durationMin\":60,\"clientName\":\"E2E Booking Client\"}")
SESSION_ID=$(echo "$BOOK_RESP" | jq -r '.session.id')
require "booking" "$SESSION_ID"

CLIENT_SEES=$(curl -s "$BASE_URL/api/client/sessions" -H "Authorization: Bearer ${CLIENT_TOKEN}" | jq -r --arg id "$SESSION_ID" '.sessions[] | select(.id==$id) | .id')
require "client sees session" "$CLIENT_SEES"
pass "client sees booked session"

TRAINER_SEES=$(curl -s "$BASE_URL/api/trainers/my-sessions" -H "Authorization: Bearer ${TRAINER_TOKEN}" | jq -r --arg id "$SESSION_ID" '.sessions[] | select(.id==$id) | .id')
require "trainer sees session" "$TRAINER_SEES"
pass "trainer sees booked session"

NOTIF=$(curl -s "$BASE_URL/api/notifications/my" -H "Authorization: Bearer ${TRAINER_TOKEN}" | jq -r --arg id "$SESSION_ID" '.notifications[] | select(.id=="sess_" + $id) | .id')
require "trainer notification" "$NOTIF"
pass "trainer notification fired"

echo "== cleanup =="
cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" | jq
pass "booking E2E test"
