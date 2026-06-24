#!/usr/bin/env bash
# E2E test for trainer programs (templates + assignment) and the client's view.
# Covers: create, list, update, ownership enforcement, assign-requires-accepted-match,
# successful assign (snapshot), client sees assigned program, delete.
# Run against production; requires ALLOW_DEV_ENDPOINTS=true on Railway + admin account.
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_TRAINER_EMAIL="e2e-programs-trainer@example.com"
TEST_TRAINER_PASSWORD="TempTest123!"
TEST_CLIENT_EMAIL="e2e-programs-client@example.com"
TEST_CLIENT_PASSWORD="TempTest123!"
OTHER_TRAINER_EMAIL="e2e-programs-other-trainer@example.com"

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== creating trainer + client + a second trainer =="
TRAINER_UID=$(create_test_trainer "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD" "E2E Programs Trainer")
require "trainer creation" "$TRAINER_UID"
CLIENT_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E Programs Client")
require "client creation" "$CLIENT_UID"
OTHER_TRAINER_UID=$(create_test_trainer "$OTHER_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD" "E2E Other Trainer")
require "other trainer creation" "$OTHER_TRAINER_UID"

# Always clean up, even on a mid-test failure.
trap 'cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" > /dev/null 2>&1; cleanup_test_data "$ADMIN_TOKEN" "$OTHER_TRAINER_UID" "" > /dev/null 2>&1' EXIT

TRAINER_TOKEN=$(sign_in "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD")
CLIENT_TOKEN=$(sign_in "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD")
OTHER_TRAINER_TOKEN=$(sign_in "$OTHER_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD")
TRAINER_DOC_ID=$(trainer_doc_id_by_email "$TEST_TRAINER_EMAIL")
require "trainer doc id" "$TRAINER_DOC_ID"

echo "== create a program =="
CREATE=$(curl -s -X POST "$BASE_URL/api/trainers/programs" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${TRAINER_TOKEN}" \
  -d '{"title":"Beginner Strength","description":"3-day full body","weeks":4,"workouts":[{"day":"Day 1","title":"Lower","exercises":[{"name":"Back Squat","sets":"3","reps":"8","notes":"controlled"},{"name":"","sets":"","reps":"","notes":"drop me"}]},{"title":"","day":"","exercises":[]}]}')
PROGRAM_ID=$(echo "$CREATE" | jq -r '.program.id')
require "program creation" "$PROGRAM_ID"
# Blank exercise and fully-blank workout should have been stripped.
[ "$(echo "$CREATE" | jq -r '.program.workouts | length')" = "1" ] || { echo "FAIL: blank workout not stripped ($CREATE)"; exit 1; }
[ "$(echo "$CREATE" | jq -r '.program.workouts[0].exercises | length')" = "1" ] || { echo "FAIL: blank exercise not stripped"; exit 1; }
pass "program created and normalized"

echo "== title is required (400) =="
NOTITLE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/trainers/programs" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${TRAINER_TOKEN}" -d '{"description":"no title"}')
[ "$NOTITLE_CODE" = "400" ] || { echo "FAIL: expected 400 for missing title, got $NOTITLE_CODE"; exit 1; }
pass "missing title rejected (400)"

echo "== list shows the program =="
LIST=$(curl -s "$BASE_URL/api/trainers/programs" -H "Authorization: Bearer ${TRAINER_TOKEN}")
[ "$(echo "$LIST" | jq -r --arg id "$PROGRAM_ID" '.programs[] | select(.id==$id) | .title')" = "Beginner Strength" ] || { echo "FAIL: program not in list"; exit 1; }
pass "program appears in trainer list"

echo "== a different trainer cannot update it (403) =="
OTHER_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE_URL/api/trainers/programs/${PROGRAM_ID}" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${OTHER_TRAINER_TOKEN}" -d '{"title":"Hijacked"}')
[ "$OTHER_CODE" = "403" ] || { echo "FAIL: expected 403 cross-trainer update, got $OTHER_CODE"; exit 1; }
pass "cross-trainer update blocked (403)"

echo "== update the program =="
UPDATE=$(curl -s -X PUT "$BASE_URL/api/trainers/programs/${PROGRAM_ID}" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${TRAINER_TOKEN}" \
  -d '{"title":"Beginner Strength v2","description":"updated","weeks":6,"workouts":[{"day":"Day 1","title":"Full Body","exercises":[{"name":"Deadlift","sets":"3","reps":"5","notes":""}]}]}')
[ "$(echo "$UPDATE" | jq -r '.program.title')" = "Beginner Strength v2" ] || { echo "FAIL: update title mismatch"; exit 1; }
[ "$(echo "$UPDATE" | jq -r '.program.weeks')" = "6" ] || { echo "FAIL: update weeks mismatch"; exit 1; }
pass "program updated"

echo "== assigning without an accepted match is blocked (403) =="
NOMATCH_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/trainers/programs/${PROGRAM_ID}/assign" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${TRAINER_TOKEN}" -d "{\"clientUid\":\"${CLIENT_UID}\"}")
[ "$NOMATCH_CODE" = "403" ] || { echo "FAIL: expected 403 assign-without-match, got $NOMATCH_CODE"; exit 1; }
pass "assign without accepted match blocked (403)"

echo "== client requests trainer, trainer accepts =="
REQ=$(curl -s -X POST "$BASE_URL/api/client/requests" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"trainerId\":\"${TRAINER_DOC_ID}\",\"clientProfile\":{\"firstName\":\"Prog\"}}")
REQUEST_ID=$(echo "$REQ" | jq -r '.request.id')
require "client request" "$REQUEST_ID"
curl -s -X POST "$BASE_URL/api/trainers/matches/${REQUEST_ID}/accept" -H "Authorization: Bearer ${TRAINER_TOKEN}" > /dev/null

echo "== now assign succeeds =="
ASSIGN=$(curl -s -X POST "$BASE_URL/api/trainers/programs/${PROGRAM_ID}/assign" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${TRAINER_TOKEN}" -d "{\"clientUid\":\"${CLIENT_UID}\"}")
ASSIGN_ID=$(echo "$ASSIGN" | jq -r '.assignment.id')
require "assignment" "$ASSIGN_ID"
[ "$(echo "$ASSIGN" | jq -r '.assignment.title')" = "Beginner Strength v2" ] || { echo "FAIL: assignment snapshot title mismatch"; exit 1; }
pass "program assigned to client"

echo "== client sees the assigned program (snapshot) =="
CLIENT_PROGRAMS=$(curl -s "$BASE_URL/api/client/programs" -H "Authorization: Bearer ${CLIENT_TOKEN}")
[ "$(echo "$CLIENT_PROGRAMS" | jq -r --arg id "$ASSIGN_ID" '.programs[] | select(.id==$id) | .title')" = "Beginner Strength v2" ] || { echo "FAIL: client does not see assigned program ($CLIENT_PROGRAMS)"; exit 1; }
[ "$(echo "$CLIENT_PROGRAMS" | jq -r --arg id "$ASSIGN_ID" '.programs[] | select(.id==$id) | .workouts[0].exercises[0].name')" = "Deadlift" ] || { echo "FAIL: assigned snapshot missing exercise detail"; exit 1; }
pass "client sees assigned program with full snapshot"

echo "== editing the template does NOT change the existing assignment snapshot =="
curl -s -X PUT "$BASE_URL/api/trainers/programs/${PROGRAM_ID}" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${TRAINER_TOKEN}" \
  -d '{"title":"Renamed Template","weeks":8,"workouts":[]}' > /dev/null
CLIENT_PROGRAMS=$(curl -s "$BASE_URL/api/client/programs" -H "Authorization: Bearer ${CLIENT_TOKEN}")
[ "$(echo "$CLIENT_PROGRAMS" | jq -r --arg id "$ASSIGN_ID" '.programs[] | select(.id==$id) | .title')" = "Beginner Strength v2" ] || { echo "FAIL: assignment snapshot changed after template edit"; exit 1; }
pass "assignment snapshot is immutable to template edits"

echo "== delete the program =="
DEL=$(curl -s -X DELETE "$BASE_URL/api/trainers/programs/${PROGRAM_ID}" -H "Authorization: Bearer ${TRAINER_TOKEN}")
[ "$(echo "$DEL" | jq -r '.ok')" = "true" ] || { echo "FAIL: delete did not return ok"; exit 1; }
GONE=$(curl -s "$BASE_URL/api/trainers/programs" -H "Authorization: Bearer ${TRAINER_TOKEN}" | jq -r --arg id "$PROGRAM_ID" '.programs[] | select(.id==$id) | .id')
[ -z "$GONE" ] || { echo "FAIL: program still present after delete"; exit 1; }
pass "program deleted"

echo "== cleanup =="
cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "$CLIENT_UID" | jq
cleanup_test_data "$ADMIN_TOKEN" "$OTHER_TRAINER_UID" "" | jq
pass "programs E2E test"
