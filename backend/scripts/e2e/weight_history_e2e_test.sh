#!/usr/bin/env bash
# E2E test for weight-history tracking:
#   GET  /api/client/progress/weight-history  -> sorted weightLog
#   POST /api/client/progress/weight-entry    -> append, sync current/start weight
# Verifies: empty log on first load, entries append & sort by date, startWeight is
# seeded from the earliest entry, currentWeight tracks the latest, invalid weight rejected.
#
# NOTE: like progress_e2e_test.sh, cleanup deletes the Firebase Auth account but the
# clientProgress doc (keyed by the now-deleted uid) is orphaned, not an issue in practice.
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_CLIENT_EMAIL="e2e-weight-client@example.com"
TEST_CLIENT_PASSWORD="TempTest123!"

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== creating test client =="
CLIENT_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E Weight Client")
require "client creation" "$CLIENT_UID"
CLIENT_TOKEN=$(sign_in "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD")

# Always clean up, even if an assertion fails midway (otherwise a reused test email
# keeps a stale clientProgress doc that breaks the next run's empty-state assertion).
trap 'cleanup_test_data "$ADMIN_TOKEN" "" "$CLIENT_UID" > /dev/null 2>&1' EXIT

echo "== first weight-history load is empty =="
HIST=$(curl -s "$BASE_URL/api/client/progress/weight-history" -H "Authorization: Bearer ${CLIENT_TOKEN}")
[ "$(echo "$HIST" | jq -r '.weightLog | length')" = "0" ] || { echo "FAIL: expected empty weightLog ($HIST)"; exit 1; }
pass "empty weight history on first load"

echo "== add three entries out of date order =="
curl -s -X POST "$BASE_URL/api/client/progress/weight-entry" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d '{"weight":190,"date":"2026-01-15T08:00:00.000Z"}' > /dev/null
curl -s -X POST "$BASE_URL/api/client/progress/weight-entry" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d '{"weight":195,"date":"2026-01-01T08:00:00.000Z"}' > /dev/null
LAST=$(curl -s -X POST "$BASE_URL/api/client/progress/weight-entry" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d '{"weight":185,"date":"2026-02-01T08:00:00.000Z"}')
echo "$LAST"

echo "== history is sorted by date ascending =="
HIST=$(curl -s "$BASE_URL/api/client/progress/weight-history" -H "Authorization: Bearer ${CLIENT_TOKEN}")
[ "$(echo "$HIST" | jq -r '.weightLog | length')" = "3" ] || { echo "FAIL: expected 3 entries ($HIST)"; exit 1; }
[ "$(echo "$HIST" | jq -r '.weightLog[0].weight')" = "195" ] || { echo "FAIL: first entry should be earliest (195)"; exit 1; }
[ "$(echo "$HIST" | jq -r '.weightLog[2].weight')" = "185" ] || { echo "FAIL: last entry should be latest (185)"; exit 1; }
pass "weight history sorted by date"

echo "== currentWeight = latest, startWeight = earliest =="
PROG=$(curl -s "$BASE_URL/api/client/progress" -H "Authorization: Bearer ${CLIENT_TOKEN}")
[ "$(echo "$PROG" | jq -r '.progress.currentWeight')" = "185" ] || { echo "FAIL: currentWeight should be 185 ($PROG)"; exit 1; }
[ "$(echo "$PROG" | jq -r '.progress.startWeight')" = "195" ] || { echo "FAIL: startWeight should be seeded to 195 ($PROG)"; exit 1; }
pass "current/start weight synced from log"

echo "== invalid weight is rejected (400) =="
BAD_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/client/progress/weight-entry" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d '{"weight":-5}')
[ "$BAD_CODE" = "400" ] || { echo "FAIL: expected 400 for negative weight, got $BAD_CODE"; exit 1; }
pass "invalid weight rejected (400)"

echo "== entry without explicit date defaults to now and appends =="
curl -s -X POST "$BASE_URL/api/client/progress/weight-entry" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d '{"weight":183}' > /dev/null
HIST=$(curl -s "$BASE_URL/api/client/progress/weight-history" -H "Authorization: Bearer ${CLIENT_TOKEN}")
[ "$(echo "$HIST" | jq -r '.weightLog | length')" = "4" ] || { echo "FAIL: expected 4 entries after dateless add ($HIST)"; exit 1; }
[ "$(echo "$HIST" | jq -r '.weightLog[3].weight')" = "183" ] || { echo "FAIL: dateless entry should sort last (now)"; exit 1; }
pass "dateless entry defaults to now"

echo "== cleanup =="
cleanup_test_data "$ADMIN_TOKEN" "" "$CLIENT_UID" | jq
pass "weight history E2E test"
