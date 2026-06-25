#!/usr/bin/env bash
# E2E test for the MONTRA Team callback lead endpoint (POST /api/leads/callback).
# Verifies lead creation, priority routing by source page, validation, and that the
# admin can list leads. Cleans up the test leads by phone afterward.
# Run against production; requires ALLOW_DEV_ENDPOINTS=true on Railway + admin account.
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_PHONE="+15550000199"

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

cleanup() {
  curl -s -X POST "$BASE_URL/api/dev/cleanup-test-data" \
    -H "Content-Type: application/json" -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -d "{\"leadPhone\":\"${TEST_PHONE}\"}" > /dev/null 2>&1 || true
}
fail() { echo "FAIL: $1" >&2; cleanup; exit 1; }

callback() { # <source> -> prints json
  curl -s -X POST "$BASE_URL/api/leads/callback" \
    -H "Content-Type: application/json" \
    -d "{\"firstName\":\"E2E Lead\",\"phone\":\"${TEST_PHONE}\",\"email\":\"e2e-lead@example.com\",\"message\":\"Choosing a coach\",\"source\":\"$1\",\"sourcePath\":\"/$1\",\"context\":{\"goal\":\"Build Muscle\",\"city\":\"Boston\"}}"
}

echo "== coach_profile callback creates a lead routed to sales (201) =="
RESP=$(callback "coach_profile")
TICKET=$(echo "$RESP" | jq -r '.ticketId')
require "lead created" "$TICKET"
[ "$(echo "$RESP" | jq -r '.team')" = "sales" ] && pass "coach_profile -> sales" || fail "coach_profile routing ($RESP)"
[ "$(echo "$RESP" | jq -r '.etaMinutes')" = "15" ] && pass "eta 15 minutes returned" || fail "eta ($RESP)"

echo "== priority routing by source =="
[ "$(callback "pricing" | jq -r '.team')" = "sales" ] && pass "pricing -> sales" || fail "pricing routing"
[ "$(callback "coach_application" | jq -r '.team')" = "recruiting" ] && pass "coach_application -> recruiting" || fail "recruiting routing"
[ "$(callback "existing_client" | jq -r '.team')" = "support" ] && pass "existing_client -> support" || fail "support routing"

echo "== validation =="
NONAME=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/leads/callback" \
  -H "Content-Type: application/json" -d "{\"phone\":\"${TEST_PHONE}\",\"source\":\"homepage\"}")
[ "$NONAME" = "400" ] && pass "missing first name -> 400" || fail "no-name expected 400, got $NONAME"
NOPHONE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/leads/callback" \
  -H "Content-Type: application/json" -d "{\"firstName\":\"E2E\",\"source\":\"homepage\"}")
[ "$NOPHONE" = "400" ] && pass "missing phone -> 400" || fail "no-phone expected 400, got $NOPHONE"
SHORTPHONE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/leads/callback" \
  -H "Content-Type: application/json" -d "{\"firstName\":\"E2E\",\"phone\":\"123\",\"source\":\"homepage\"}")
[ "$SHORTPHONE" = "400" ] && pass "invalid phone -> 400" || fail "short-phone expected 400, got $SHORTPHONE"

echo "== admin can list leads incl. ours =="
HAS=$(curl -s "$BASE_URL/api/admin/leads" -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  | jq --arg id "$TICKET" 'any(.leads[]; .id == $id)')
[ "$HAS" = "true" ] && pass "admin leads list includes our lead" || fail "admin leads missing our lead"

echo "== admin can update lead status =="
ST=$(curl -s -X POST "$BASE_URL/api/admin/leads/${TICKET}/status" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d '{"status":"contacted"}' | jq -r '.lead.status')
[ "$ST" = "contacted" ] && pass "lead marked contacted" || fail "status update ($ST)"
BADST=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/admin/leads/${TICKET}/status" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${ADMIN_TOKEN}" -d '{"status":"banana"}')
[ "$BADST" = "400" ] && pass "invalid status -> 400" || fail "invalid status expected 400, got $BADST"

echo "== non-admin cannot list leads (401/403) =="
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/admin/leads")
{ [ "$CODE" = "401" ] || [ "$CODE" = "403" ]; } && pass "unauth leads list rejected ($CODE)" || fail "expected 401/403, got $CODE"

echo "== cleanup =="
cleanup
pass "leads callback E2E test"
