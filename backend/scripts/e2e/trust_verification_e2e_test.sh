#!/usr/bin/env bash
# E2E test for trust-stack verification gating.
# Verifies the ID Verified / Background Checked / MONTRA Certified™ flags:
#   - default to false on a freshly approved trainer
#   - cannot be self-set by a trainer via /api/trainers/apply
#   - require admin to set via POST /api/admin/trainers/:id/verification
#   - reject a non-admin caller (403) and an empty body (400)
#   - persist exactly the flags an admin sets (others stay false)
# Run against production; requires ALLOW_DEV_ENDPOINTS=true on Railway + admin account.
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_TRAINER_EMAIL="e2e-verify-trainer@example.com"
TEST_TRAINER_PASSWORD="TempTest123!"

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== creating test trainer (approved) =="
TRAINER_UID=$(create_test_trainer "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD" "E2E Verify Trainer")
require "trainer creation" "$TRAINER_UID"

TRAINER_TOKEN=$(sign_in "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD")
TRAINER_DOC_ID=$(trainer_doc_id_by_email "$TEST_TRAINER_EMAIL")
require "trainer doc id" "$TRAINER_DOC_ID"

cleanup() { cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "" "$TRAINER_DOC_ID" > /dev/null 2>&1 || true; }

flags_of() {
  curl -s "$BASE_URL/api/trainers/${TRAINER_DOC_ID}" \
    | jq -r '"\(.trainer.idVerified) \(.trainer.backgroundCheckCleared) \(.trainer.montraCertified)"'
}

echo "== flags default to false on a new trainer =="
[ "$(flags_of)" = "false false false" ] && pass "verification flags default false" || { echo "FAIL: defaults $(flags_of)" >&2; cleanup; exit 1; }

echo "== trainer cannot self-set flags via apply =="
curl -s -X POST "$BASE_URL/api/trainers/apply" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${TRAINER_TOKEN}" \
  -d '{"name":"E2E Verify Trainer","bio":"Test bio long enough","certification":"NASM","idVerified":true,"backgroundCheckCleared":true,"montraCertified":true}' > /dev/null
[ "$(flags_of)" = "false false false" ] && pass "self-set via apply is ignored" || { echo "FAIL: self-set leaked $(flags_of)" >&2; cleanup; exit 1; }

echo "== non-admin cannot call verification route (403) =="
FORBIDDEN=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/admin/trainers/${TRAINER_DOC_ID}/verification" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${TRAINER_TOKEN}" -d '{"idVerified":true}')
[ "$FORBIDDEN" = "403" ] && pass "non-admin rejected (403)" || { echo "FAIL: expected 403, got $FORBIDDEN" >&2; cleanup; exit 1; }

echo "== empty body is rejected (400) =="
EMPTY=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/admin/trainers/${TRAINER_DOC_ID}/verification" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${ADMIN_TOKEN}" -d '{}')
[ "$EMPTY" = "400" ] && pass "empty body rejected (400)" || { echo "FAIL: expected 400, got $EMPTY" >&2; cleanup; exit 1; }

echo "== admin sets idVerified + montraCertified (background stays false) =="
curl -s -X POST "$BASE_URL/api/admin/trainers/${TRAINER_DOC_ID}/verification" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d '{"idVerified":true,"montraCertified":true}' > /dev/null
[ "$(flags_of)" = "true false true" ] && pass "admin set exactly the flags provided" || { echo "FAIL: got $(flags_of)" >&2; cleanup; exit 1; }

echo "== a later profile edit preserves the admin flags =="
curl -s -X POST "$BASE_URL/api/trainers/apply" \
  -H "Content-Type: application/json" -H "Authorization: Bearer ${TRAINER_TOKEN}" \
  -d '{"name":"E2E Verify Trainer","bio":"Updated bio text here","certification":"NASM"}' > /dev/null
[ "$(flags_of)" = "true false true" ] && pass "admin flags survive a profile edit" || { echo "FAIL: flags lost on edit $(flags_of)" >&2; cleanup; exit 1; }

echo "== cleanup =="
cleanup
pass "trust verification E2E test"
