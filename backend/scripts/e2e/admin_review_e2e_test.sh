#!/usr/bin/env bash
# E2E test: public trainer application (/api/trainers/provision, no auth) -> admin reviews via
# /api/admin/trainer-applications -> admin approves -> admin rejects. Exercises the
# application-only trainer doc path (no Firebase account attached), which is how real trainer
# applications arrive before they ever get a login.
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_APPLICANT_EMAIL="e2e-admin-review-applicant@example.com"

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== submitting public trainer application =="
PROVISION_RESP=$(curl -s -X POST "$BASE_URL/api/trainers/provision" \
  -H "Content-Type: application/json" \
  -d "{\"firstName\":\"E2E\",\"lastName\":\"Admin Review\",\"email\":\"${TEST_APPLICANT_EMAIL}\",\"phone\":\"5555555555\",\"specialties\":[\"Strength\"],\"certifications\":\"NASM-CPT\",\"coachingStyle\":\"Supportive and structured.\",\"experienceYears\":3}")
echo "$PROVISION_RESP"
APPLICATION_ID=$(echo "$PROVISION_RESP" | jq -r '.applicationId')
if [ "$APPLICATION_ID" = "null" ] || [ -z "$APPLICATION_ID" ]; then
  echo "FAIL: application id (a leftover doc from a previous failed run may be blocking this — run with the same name/id to clean it up first)"
  exit 1
fi
INITIAL_STATUS=$(echo "$PROVISION_RESP" | jq -r '.status')
pass "application submitted (initial status: $INITIAL_STATUS)"

cleanup() {
  cleanup_test_data "$ADMIN_TOKEN" "" "" "$APPLICATION_ID" > /dev/null
}

echo "== admin lists trainer-applications and finds it =="
FOUND_ID=$(curl -s "$BASE_URL/api/admin/trainer-applications" -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  | jq -r --arg email "$TEST_APPLICANT_EMAIL" '.applications[] | select(.trainer.email==$email) | .trainer.id')
require "admin sees application" "$FOUND_ID"
[ "$FOUND_ID" = "$APPLICATION_ID" ] || { echo "FAIL: id mismatch ($FOUND_ID vs $APPLICATION_ID)"; exit 1; }
pass "admin trainer-applications lists the new application"

echo "== admin approves it =="
APPROVE_RESP=$(curl -s -X POST "$BASE_URL/api/admin/trainers/${APPLICATION_ID}/approve" -H "Authorization: Bearer ${ADMIN_TOKEN}")
APPROVE_STATUS=$(echo "$APPROVE_RESP" | jq -r '.trainer.status')
[ "$APPROVE_STATUS" = "approved" ] || { echo "FAIL: expected approved, got $APPROVE_STATUS ($APPROVE_RESP)"; cleanup; exit 1; }
pass "admin approve sets status=approved"

echo "== now publicly visible in the trainer directory =="
PUBLIC_VISIBLE=$(curl -s "$BASE_URL/api/trainers" | jq -r --arg id "$APPLICATION_ID" '.trainers[] | select(.id==$id) | .id')
if [ -z "$PUBLIC_VISIBLE" ]; then echo "FAIL: publicly visible after approval"; cleanup; exit 1; fi
pass "approved trainer appears in public /api/trainers directory"

echo "== admin rejects it =="
REJECT_RESP=$(curl -s -X POST "$BASE_URL/api/admin/trainers/${APPLICATION_ID}/reject" -H "Authorization: Bearer ${ADMIN_TOKEN}")
REJECT_STATUS=$(echo "$REJECT_RESP" | jq -r '.trainer.status')
REJECT_ACTIVE=$(echo "$REJECT_RESP" | jq -r '.trainer.isActive')
[ "$REJECT_STATUS" = "rejected" ] || { echo "FAIL: expected rejected, got $REJECT_STATUS ($REJECT_RESP)"; cleanup; exit 1; }
[ "$REJECT_ACTIVE" = "false" ] || { echo "FAIL: expected isActive=false after reject, got $REJECT_ACTIVE"; cleanup; exit 1; }
pass "admin reject sets status=rejected, isActive=false"

echo "== no longer in public directory =="
STILL_VISIBLE=$(curl -s "$BASE_URL/api/trainers" | jq -r --arg id "$APPLICATION_ID" '.trainers[] | select(.id==$id) | .id')
if [ -n "$STILL_VISIBLE" ]; then echo "FAIL: rejected trainer still publicly visible"; cleanup; exit 1; fi
pass "rejected trainer removed from public directory"

echo "== cleanup (deletes the application doc by id, now that cleanup-test-data supports it) =="
cleanup
pass "admin review E2E test"
