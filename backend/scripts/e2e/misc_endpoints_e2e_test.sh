#!/usr/bin/env bash
# Smoke test for the remaining read/utility endpoints not covered by the other E2E scripts:
# /api/me, /api/trainers/match (public matching), /api/client/match (authenticated matching),
# /api/ai/coach-suggestion (rules-based suggestion, no real model behind it).
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_CLIENT_EMAIL="e2e-misc-client@example.com"
TEST_CLIENT_PASSWORD="TempTest123!"

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== creating test client =="
CLIENT_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E Misc Client")
require "client creation" "$CLIENT_UID"
CLIENT_TOKEN=$(sign_in "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD")

echo "== GET /api/me reflects signed-in client identity =="
ME_RESP=$(curl -s "$BASE_URL/api/me" -H "Authorization: Bearer ${CLIENT_TOKEN}")
echo "$ME_RESP"
[ "$(echo "$ME_RESP" | jq -r '.uid')" = "$CLIENT_UID" ] || { echo "FAIL: /api/me uid mismatch"; exit 1; }
[ "$(echo "$ME_RESP" | jq -r '.email')" = "$TEST_CLIENT_EMAIL" ] || { echo "FAIL: /api/me email mismatch"; exit 1; }
[ "$(echo "$ME_RESP" | jq -r '.role')" = "client" ] || { echo "FAIL: /api/me role should default to client, got $(echo "$ME_RESP" | jq -r '.role')"; exit 1; }
[ "$(echo "$ME_RESP" | jq -r '.isAdmin')" = "false" ] || { echo "FAIL: test client should not be admin"; exit 1; }
pass "/api/me reflects identity and non-admin role"

echo "== GET /api/me as admin reflects isAdmin=true =="
ME_ADMIN=$(curl -s "$BASE_URL/api/me" -H "Authorization: Bearer ${ADMIN_TOKEN}")
[ "$(echo "$ME_ADMIN" | jq -r '.isAdmin')" = "true" ] || { echo "FAIL: admin account should report isAdmin=true ($ME_ADMIN)"; exit 1; }
pass "/api/me reports isAdmin=true for the admin account"

echo "== GET /api/trainers/match (public, unauthenticated) returns only approved trainers =="
MATCH_RESP=$(curl -s "$BASE_URL/api/trainers/match?goal=Strength")
NON_APPROVED=$(echo "$MATCH_RESP" | jq -r '.trainers[] | select(.status != "approved") | .id')
[ -z "$NON_APPROVED" ] || { echo "FAIL: /api/trainers/match returned a non-approved trainer: $NON_APPROVED"; exit 1; }
pass "/api/trainers/match only returns approved trainers"

echo "== POST /api/client/match (authenticated) returns the same shape =="
CLIENT_MATCH_RESP=$(curl -s -X POST "$BASE_URL/api/client/match" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d '{"goal":"Strength","location":"Boston, MA","gender":"Any","preferredDays":["Monday","Wednesday"]}')
echo "$CLIENT_MATCH_RESP" | jq '.filters'
[ "$(echo "$CLIENT_MATCH_RESP" | jq -r '.filters.goal')" = "Strength" ] || { echo "FAIL: /api/client/match did not echo filters correctly"; exit 1; }
pass "/api/client/match echoes filters and returns trainers array"

echo "== POST /api/ai/coach-suggestion returns a non-empty rules-based suggestion =="
SUGGESTION_RESP=$(curl -s -X POST "$BASE_URL/api/ai/coach-suggestion" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d '{"goal":"Weight Loss","mood":"Tired","availability":["Monday AM","Wednesday PM"]}')
echo "$SUGGESTION_RESP"
SUGGESTION_TEXT=$(echo "$SUGGESTION_RESP" | jq -r '.suggestion')
require "ai coach suggestion text" "$SUGGESTION_TEXT"
pass "/api/ai/coach-suggestion returns a suggestion"

echo "== unauthenticated request to an authenticated endpoint is rejected =="
UNAUTH_CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL/api/me")
[ "$UNAUTH_CODE" = "401" ] || { echo "FAIL: expected 401 with no auth header, got $UNAUTH_CODE"; exit 1; }
pass "unauthenticated /api/me request correctly rejected (401)"

echo "== cleanup =="
cleanup_test_data "$ADMIN_TOKEN" "" "$CLIENT_UID" | jq
pass "misc endpoints E2E test"
