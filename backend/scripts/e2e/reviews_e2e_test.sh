#!/usr/bin/env bash
# E2E test for verified client reviews (POST /api/client/reviews, GET /api/trainers/:id/reviews).
# Books + completes a session, then verifies:
#   - a not-yet-completed session cannot be reviewed (409)
#   - an out-of-range rating is rejected (400)
#   - the client can review a completed session (201)
#   - the same session cannot be reviewed twice (409)
#   - another client cannot review someone else's session (403)
#   - the public reviews endpoint returns the review + summary
#   - the trainer's aggregate rating/reviewCount is recomputed from real reviews
# Run against production; requires ALLOW_DEV_ENDPOINTS=true on Railway + admin account.
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_TRAINER_EMAIL="e2e-review-trainer@example.com"
TEST_TRAINER_PASSWORD="TempTest123!"
TEST_CLIENT_EMAIL="e2e-review-client@example.com"
TEST_CLIENT_PASSWORD="TempTest123!"
TEST_CLIENT2_EMAIL="e2e-review-client2@example.com"
TEST_CLIENT2_PASSWORD="TempTest123!"

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== creating test trainer (approved) =="
TRAINER_UID=$(create_test_trainer "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD" "E2E Review Trainer")
require "trainer creation" "$TRAINER_UID"

echo "== creating test clients =="
CLIENT_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E Review Client")
require "client creation" "$CLIENT_UID"
CLIENT2_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT2_EMAIL" "$TEST_CLIENT2_PASSWORD" "E2E Review Client Two")
require "client2 creation" "$CLIENT2_UID"

cleanup() {
  cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" > /dev/null 2>&1 || true
  cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT2_UID" > /dev/null 2>&1 || true
}

echo "== signing in trainer + clients =="
TRAINER_TOKEN=$(sign_in "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD")
CLIENT_TOKEN=$(sign_in "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD")
CLIENT2_TOKEN=$(sign_in "$TEST_CLIENT2_EMAIL" "$TEST_CLIENT2_PASSWORD")

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
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"startTime\":\"${START_TIME}\",\"durationMin\":60,\"clientName\":\"E2E Review Client\"}")
SESSION_ID=$(echo "$BOOK_RESP" | jq -r '.session.id')
require "booking" "$SESSION_ID"

echo "== reviewing a not-yet-completed session is rejected (409) =="
EARLY_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/client/reviews" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"sessionId\":\"${SESSION_ID}\",\"rating\":5,\"text\":\"too soon\"}")
[ "$EARLY_CODE" = "409" ] && pass "uncompleted session cannot be reviewed (409)" || { echo "FAIL: expected 409, got $EARLY_CODE" >&2; cleanup; exit 1; }

echo "== waiting for the session start time to pass, then completing =="
sleep 7
curl -s -X POST "$BASE_URL/api/client/sessions/${SESSION_ID}/complete" -H "Authorization: Bearer ${CLIENT_TOKEN}" > /dev/null

echo "== out-of-range rating is rejected (400) =="
BAD_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/client/reviews" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"sessionId\":\"${SESSION_ID}\",\"rating\":7,\"text\":\"out of range\"}")
[ "$BAD_CODE" = "400" ] && pass "out-of-range rating rejected (400)" || { echo "FAIL: expected 400, got $BAD_CODE" >&2; cleanup; exit 1; }

echo "== another client cannot review this session (403) =="
FORBIDDEN_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/client/reviews" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT2_TOKEN}" \
  -d "{\"sessionId\":\"${SESSION_ID}\",\"rating\":1,\"text\":\"not my session\"}")
[ "$FORBIDDEN_CODE" = "403" ] && pass "cross-client review rejected (403)" || { echo "FAIL: expected 403, got $FORBIDDEN_CODE" >&2; cleanup; exit 1; }

echo "== client reviews the completed session (201) =="
REVIEW_RESP=$(curl -s -X POST "$BASE_URL/api/client/reviews" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"sessionId\":\"${SESSION_ID}\",\"rating\":5,\"text\":\"Incredible coach — pushed me hard and kept it fun.\"}")
REVIEW_ID=$(echo "$REVIEW_RESP" | jq -r '.review.id')
require "review created" "$REVIEW_ID"
REVIEW_RATING=$(echo "$REVIEW_RESP" | jq -r '.review.rating')
[ "$REVIEW_RATING" = "5" ] && pass "review persisted with rating 5" || { echo "FAIL: rating $REVIEW_RATING ($REVIEW_RESP)" >&2; cleanup; exit 1; }

echo "== same session cannot be reviewed twice (409) =="
DUP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/client/reviews" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"sessionId\":\"${SESSION_ID}\",\"rating\":4,\"text\":\"again\"}")
[ "$DUP_CODE" = "409" ] && pass "duplicate review rejected (409)" || { echo "FAIL: expected 409, got $DUP_CODE" >&2; cleanup; exit 1; }

echo "== public reviews endpoint returns the review =="
PUB_RESP=$(curl -s "$BASE_URL/api/trainers/${TRAINER_DOC_ID}/reviews")
PUB_COUNT=$(echo "$PUB_RESP" | jq '.reviews | length')
[ "$PUB_COUNT" = "1" ] && pass "public endpoint returns 1 review" || { echo "FAIL: expected 1 review, got $PUB_COUNT ($PUB_RESP)" >&2; cleanup; exit 1; }
PUB_TEXT=$(echo "$PUB_RESP" | jq -r '.reviews[0].text')
[ -n "$PUB_TEXT" ] && pass "review text exposed publicly" || echo "WARN: empty review text"

echo "== trainer aggregate recomputed from real reviews =="
AGG=$(curl -s "$BASE_URL/api/trainers/${TRAINER_DOC_ID}")
AGG_RATING=$(echo "$AGG" | jq -r '.trainer.rating')
AGG_COUNT=$(echo "$AGG" | jq -r '.trainer.reviewCount')
[ "$AGG_RATING" = "5" ] && pass "trainer rating recomputed to 5" || { echo "FAIL: rating $AGG_RATING" >&2; cleanup; exit 1; }
[ "$AGG_COUNT" = "1" ] && pass "trainer reviewCount recomputed to 1" || { echo "FAIL: reviewCount $AGG_COUNT" >&2; cleanup; exit 1; }

echo "== cleanup =="
cleanup
pass "reviews E2E test"
