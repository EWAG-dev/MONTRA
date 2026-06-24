#!/usr/bin/env bash
# E2E test for the device token endpoints used by the push notification pipeline:
# - POST /api/me/device-token: saves a token for the authenticated user
# - DELETE /api/me/device-token: removes it (called on sign-out)
# - Verifies the backend correctly gates both by requireFirebaseAuth
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_CLIENT_EMAIL="e2e-push-client@example.com"
TEST_CLIENT_PASSWORD="TempTest123!"
FAKE_FCM_TOKEN="fake-fcm-token-$(date +%s)"

echo "== setup =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"
CLIENT_UID=$(create_test_client "$ADMIN_TOKEN" "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD" "E2E Push Client")
require "client" "$CLIENT_UID"
CLIENT_TOKEN=$(sign_in "$TEST_CLIENT_EMAIL" "$TEST_CLIENT_PASSWORD")

echo "== unauthenticated registration is rejected =="
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE_URL/api/me/device-token" \
  -H "Content-Type: application/json" -d "{\"token\":\"${FAKE_FCM_TOKEN}\"}")
[ "$CODE" = "401" ] || { echo "FAIL: expected 401 unauthenticated, got $CODE"; cleanup_test_data "$ADMIN_TOKEN" "" "$CLIENT_UID" > /dev/null; exit 1; }
pass "unauthenticated token registration blocked (401)"

echo "== save device token =="
SAVE_RESP=$(curl -s -X POST "$BASE_URL/api/me/device-token" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d "{\"token\":\"${FAKE_FCM_TOKEN}\"}")
[ "$(echo "$SAVE_RESP" | jq -r '.ok')" = "true" ] || { echo "FAIL: save token: $SAVE_RESP"; cleanup_test_data "$ADMIN_TOKEN" "" "$CLIENT_UID" > /dev/null; exit 1; }
pass "device token saved"

echo "== empty token is rejected =="
EMPTY_RESP=$(curl -s -w '\n%{http_code}' -X POST "$BASE_URL/api/me/device-token" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${CLIENT_TOKEN}" \
  -d '{"token":""}')
EMPTY_CODE=$(echo "$EMPTY_RESP" | tail -n1)
[ "$EMPTY_CODE" = "400" ] || { echo "FAIL: empty token should be 400, got $EMPTY_CODE"; cleanup_test_data "$ADMIN_TOKEN" "" "$CLIENT_UID" > /dev/null; exit 1; }
pass "empty token correctly rejected (400)"

echo "== delete device token (sign-out) =="
DELETE_RESP=$(curl -s -X DELETE "$BASE_URL/api/me/device-token" \
  -H "Authorization: Bearer ${CLIENT_TOKEN}")
[ "$(echo "$DELETE_RESP" | jq -r '.ok')" = "true" ] || { echo "FAIL: delete token: $DELETE_RESP"; cleanup_test_data "$ADMIN_TOKEN" "" "$CLIENT_UID" > /dev/null; exit 1; }
pass "device token deleted on sign-out"

echo "== cleanup =="
cleanup_test_data "$ADMIN_TOKEN" "" "$CLIENT_UID" | jq
pass "push token E2E test"
