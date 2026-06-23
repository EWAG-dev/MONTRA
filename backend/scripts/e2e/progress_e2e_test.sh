#!/usr/bin/env bash
# E2E test for backend-persisted client progress/goals (GET+POST /api/client/progress):
# defaults on first load, save round-trips correctly, persists across a fresh load.
#
# NOTE: /api/dev/cleanup-test-data deletes the client's Firebase Auth account but doesn't
# know about the clientProgress collection, so the orphaned doc (keyed by a now-deleted uid,
# unreachable by any real user) is left behind. Same caveat as admin_review_e2e_test.sh.
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_CLIENT_EMAIL="e2e-progress-client@example.com"
TEST_CLIENT_PASSWORD="TempTest123!"

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== creating test client =="
CLIENT_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E Progress Client")
require "client creation" "$CLIENT_UID"
CLIENT_TOKEN=$(sign_in "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD")

echo "== first load returns defaults =="
DEFAULTS=$(curl -s "$BASE_URL/api/client/progress" -H "Authorization: Bearer ${CLIENT_TOKEN}")
echo "$DEFAULTS"
[ "$(echo "$DEFAULTS" | jq -r '.progress.strengthWeeklyTarget')" = "5" ] || { echo "FAIL: default strengthWeeklyTarget should be 5"; exit 1; }
[ "$(echo "$DEFAULTS" | jq -r '.progress.currentWeight')" = "" ] || { echo "FAIL: default currentWeight should be empty"; exit 1; }
pass "defaults returned on first load"

echo "== save progress =="
SAVE_RESP=$(curl -s -X POST "$BASE_URL/api/client/progress" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d '{"currentWeight":"182.5","startWeight":"195","weightLossGoal":"170","selectedGoals":["Weight Loss","Build Strength"],"strengthWeeklyTarget":"4","enduranceMinutesTarget":"150","mobilitySessionsTarget":"2","performanceMonthlyTarget":"10","consistencyPercentTarget":"85"}')
echo "$SAVE_RESP"
[ "$(echo "$SAVE_RESP" | jq -r '.progress.currentWeight')" = "182.5" ] || { echo "FAIL: save did not echo currentWeight"; exit 1; }
pass "save returns the new values"

echo "== fresh load reflects saved values =="
RELOAD=$(curl -s "$BASE_URL/api/client/progress" -H "Authorization: Bearer ${CLIENT_TOKEN}")
echo "$RELOAD"
[ "$(echo "$RELOAD" | jq -r '.progress.currentWeight')" = "182.5" ] || { echo "FAIL: reload currentWeight mismatch"; exit 1; }
[ "$(echo "$RELOAD" | jq -r '.progress.startWeight')" = "195" ] || { echo "FAIL: reload startWeight mismatch"; exit 1; }
[ "$(echo "$RELOAD" | jq -r '.progress.selectedGoals | sort | join(",")')" = "Build Strength,Weight Loss" ] || { echo "FAIL: reload selectedGoals mismatch"; exit 1; }
[ "$(echo "$RELOAD" | jq -r '.progress.strengthWeeklyTarget')" = "4" ] || { echo "FAIL: reload strengthWeeklyTarget mismatch"; exit 1; }
pass "reload reflects persisted values"

echo "== a different client gets their own independent defaults (no cross-talk) =="
TEST_CLIENT2_EMAIL="e2e-progress-client-2@example.com"
CLIENT2_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT2_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E Progress Client 2")
require "client2 creation" "$CLIENT2_UID"
CLIENT2_TOKEN=$(sign_in "$TEST_CLIENT2_EMAIL" "$TEST_CLIENT_PASSWORD")
CLIENT2_DEFAULTS=$(curl -s "$BASE_URL/api/client/progress" -H "Authorization: Bearer ${CLIENT2_TOKEN}")
[ "$(echo "$CLIENT2_DEFAULTS" | jq -r '.progress.currentWeight')" = "" ] || { echo "FAIL: client2 should not see client1's data"; exit 1; }
pass "separate client has isolated progress data"

echo "== cleanup =="
cleanup_test_data "$ADMIN_TOKEN" "" "$CLIENT_UID" | jq
cleanup_test_data "$ADMIN_TOKEN" "" "$CLIENT2_UID" | jq
pass "progress E2E test"
