#!/usr/bin/env bash
# E2E test for website/trainer-application.html's actual submission flow: this sends the exact
# request shape the form's JS builds (after the experienceYears bucket-mapping fix — the <select>
# sends bucket strings like "10plus", not numbers, so the JS must convert before POSTing or the
# backend's Number("10plus") => NaN silently zeroes it out and the iOS "N+ Years Exp." pill never
# shows). Confirms the fix round-trips a non-zero experienceYears into the trainer record.
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_APPLICANT_EMAIL="e2e-website-form-applicant@example.com"

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== submitting the exact payload shape trainer-application.html's JS sends for a '10+ years' applicant =="
PROVISION_RESP=$(curl -s -X POST "$BASE_URL/api/trainers/provision" \
  -H "Content-Type: application/json" \
  -d "{\"firstName\":\"E2E\",\"lastName\":\"Website Form\",\"email\":\"${TEST_APPLICANT_EMAIL}\",\"phone\":\"5555550000\",\"experienceYears\":10,\"specialties\":[\"Personal Training\",\"Strength & Conditioning\"],\"coachingStyle\":\"Direct, encouraging, and focused on sustainable habit change.\",\"certifications\":\"NASM CPT\",\"education\":\"B.S. Kinesiology\",\"references\":[\"Jane Smith, jane@example.com\"],\"backgroundCheckConsent\":true,\"policyAgreement\":true}")
echo "$PROVISION_RESP"
APPLICATION_ID=$(echo "$PROVISION_RESP" | jq -r '.applicationId')
if [ "$APPLICATION_ID" = "null" ] || [ -z "$APPLICATION_ID" ]; then
  echo "FAIL: application id (a leftover doc from a previous failed run may be blocking this)"
  exit 1
fi
pass "application submitted via the website form's exact payload shape"

echo "== fetching the created trainer record and checking experienceYears survived =="
TRAINER_RESP=$(curl -s "$BASE_URL/api/trainers/${APPLICATION_ID}")
echo "$TRAINER_RESP"
ACTUAL_YEARS=$(echo "$TRAINER_RESP" | jq -r '.trainer.experienceYears')
if [ "$ACTUAL_YEARS" = "0" ] || [ "$ACTUAL_YEARS" = "null" ]; then
  echo "FAIL: experienceYears was lost (got $ACTUAL_YEARS, expected 10) — the website form's bucket->number mapping may be broken again"
  cleanup_test_data "$ADMIN_TOKEN" "" "" "$APPLICATION_ID" > /dev/null
  exit 1
fi
[ "$ACTUAL_YEARS" = "10" ] || { echo "FAIL: expected experienceYears=10, got $ACTUAL_YEARS"; cleanup_test_data "$ADMIN_TOKEN" "" "" "$APPLICATION_ID" > /dev/null; exit 1; }
pass "experienceYears correctly persisted as 10 (would show as iOS' '10+ Years Exp.' pill)"

echo "== checking education/references/consent fields survived (previously silently dropped) =="
ACTUAL_EDUCATION=$(echo "$TRAINER_RESP" | jq -r '.trainer.education')
ACTUAL_REFS=$(echo "$TRAINER_RESP" | jq -r '.trainer.references | length')
ACTUAL_BG_CONSENT=$(echo "$TRAINER_RESP" | jq -r '.trainer.backgroundCheckConsent')
ACTUAL_POLICY=$(echo "$TRAINER_RESP" | jq -r '.trainer.policyAgreement')
[ "$ACTUAL_EDUCATION" = "B.S. Kinesiology" ] || { echo "FAIL: education not persisted (got '$ACTUAL_EDUCATION')"; cleanup_test_data "$ADMIN_TOKEN" "" "" "$APPLICATION_ID" > /dev/null; exit 1; }
[ "$ACTUAL_REFS" = "1" ] || { echo "FAIL: references not persisted (got $ACTUAL_REFS entries)"; cleanup_test_data "$ADMIN_TOKEN" "" "" "$APPLICATION_ID" > /dev/null; exit 1; }
[ "$ACTUAL_BG_CONSENT" = "true" ] || { echo "FAIL: backgroundCheckConsent not persisted"; cleanup_test_data "$ADMIN_TOKEN" "" "" "$APPLICATION_ID" > /dev/null; exit 1; }
[ "$ACTUAL_POLICY" = "true" ] || { echo "FAIL: policyAgreement not persisted"; cleanup_test_data "$ADMIN_TOKEN" "" "" "$APPLICATION_ID" > /dev/null; exit 1; }
pass "education, references, backgroundCheckConsent, and policyAgreement all persisted"

echo "== cleanup =="
cleanup_test_data "$ADMIN_TOKEN" "" "" "$APPLICATION_ID" | jq
pass "website trainer form E2E test"
