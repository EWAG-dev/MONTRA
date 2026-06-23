#!/usr/bin/env bash
# E2E test: public trainer application (/api/trainers/provision, no auth) -> admin reviews via
# /api/admin/trainer-applications -> admin approves -> admin rejects. Exercises the
# application-only trainer doc path (no Firebase account attached), which is how real trainer
# applications arrive before they ever get a login.
#
# NOTE ON CLEANUP: /api/dev/cleanup-test-data only deletes trainer docs that have an accountUid
# (matched via a Firebase Auth uid). A provision()-created application has no accountUid, so it
# can't be deleted through that endpoint. This script's "cleanup" instead rejects the test
# application (status=rejected, isActive=false), which removes it from the public /api/trainers
# directory — but the Firestore doc itself is left behind. If you want it gone entirely before
# reverting the temp dev endpoints, delete it manually from the Firestore console (trainers
# collection, filter by the email below).
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
require "application id" "$APPLICATION_ID"
INITIAL_STATUS=$(echo "$PROVISION_RESP" | jq -r '.status')
pass "application submitted (initial status: $INITIAL_STATUS)"

echo "== admin lists trainer-applications and finds it =="
FOUND_ID=$(curl -s "$BASE_URL/api/admin/trainer-applications" -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  | jq -r --arg email "$TEST_APPLICANT_EMAIL" '.applications[] | select(.trainer.email==$email) | .trainer.id')
require "admin sees application" "$FOUND_ID"
[ "$FOUND_ID" = "$APPLICATION_ID" ] || { echo "FAIL: id mismatch ($FOUND_ID vs $APPLICATION_ID)"; exit 1; }
pass "admin trainer-applications lists the new application"

echo "== admin approves it =="
APPROVE_RESP=$(curl -s -X POST "$BASE_URL/api/admin/trainers/${APPLICATION_ID}/approve" -H "Authorization: Bearer ${ADMIN_TOKEN}")
APPROVE_STATUS=$(echo "$APPROVE_RESP" | jq -r '.trainer.status')
[ "$APPROVE_STATUS" = "approved" ] || { echo "FAIL: expected approved, got $APPROVE_STATUS ($APPROVE_RESP)"; exit 1; }
pass "admin approve sets status=approved"

echo "== now publicly visible in the trainer directory =="
PUBLIC_VISIBLE=$(curl -s "$BASE_URL/api/trainers" | jq -r --arg id "$APPLICATION_ID" '.trainers[] | select(.id==$id) | .id')
require "publicly visible after approval" "$PUBLIC_VISIBLE"
pass "approved trainer appears in public /api/trainers directory"

echo "== admin rejects it (soft cleanup — see NOTE at top of file) =="
REJECT_RESP=$(curl -s -X POST "$BASE_URL/api/admin/trainers/${APPLICATION_ID}/reject" -H "Authorization: Bearer ${ADMIN_TOKEN}")
REJECT_STATUS=$(echo "$REJECT_RESP" | jq -r '.trainer.status')
REJECT_ACTIVE=$(echo "$REJECT_RESP" | jq -r '.trainer.isActive')
[ "$REJECT_STATUS" = "rejected" ] || { echo "FAIL: expected rejected, got $REJECT_STATUS ($REJECT_RESP)"; exit 1; }
[ "$REJECT_ACTIVE" = "false" ] || { echo "FAIL: expected isActive=false after reject, got $REJECT_ACTIVE"; exit 1; }
pass "admin reject sets status=rejected, isActive=false"

echo "== no longer in public directory =="
STILL_VISIBLE=$(curl -s "$BASE_URL/api/trainers" | jq -r --arg id "$APPLICATION_ID" '.trainers[] | select(.id==$id) | .id')
[ -z "$STILL_VISIBLE" ] || { echo "FAIL: rejected trainer still publicly visible"; exit 1; }
pass "rejected trainer removed from public directory"

pass "admin review E2E test (Firestore doc left behind — see NOTE; not in public directory)"
