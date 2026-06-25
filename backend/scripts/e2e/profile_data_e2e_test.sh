#!/usr/bin/env bash
# E2E test for the coach-profile data endpoints:
#   GET /api/trainers/:id/insights  (MONTRA Insights + client-proof signals)
#   GET /api/trainers/:id/packages  (session packages, commitments, à-la-carte)
# Asserts response shape/invariants, that real-vs-derived fields behave correctly,
# and — critically — that a reserved/invalid Firestore doc id returns 404 WITHOUT
# crashing the process (regression guard for the unhandled-rejection outage).
# Run against production; requires ALLOW_DEV_ENDPOINTS=true on Railway + admin account.
set -euo pipefail
cd "$(dirname "$0")"
source ./e2e_common.sh

TEST_TRAINER_EMAIL="e2e-profile-trainer@example.com"
TEST_TRAINER_PASSWORD="TempTest123!"

echo "== signing in admin =="
ADMIN_TOKEN=$(admin_token)
require "admin sign-in" "$ADMIN_TOKEN"

echo "== creating test trainer (approved) =="
TRAINER_UID=$(create_test_trainer "$TEST_TRAINER_EMAIL" "$TEST_TRAINER_PASSWORD" "E2E Profile Trainer")
require "trainer creation" "$TRAINER_UID"
TRAINER_DOC_ID=$(trainer_doc_id_by_email "$TEST_TRAINER_EMAIL")
require "trainer doc id" "$TRAINER_DOC_ID"

cleanup() { cleanup_test_data "$ADMIN_TOKEN" "$TRAINER_UID" "" "$TRAINER_DOC_ID" > /dev/null 2>&1 || true; }
fail() { echo "FAIL: $1" >&2; cleanup; exit 1; }

# ───────────────────────── INSIGHTS ─────────────────────────
echo "== GET /insights shape =="
INS=$(curl -s "$BASE_URL/api/trainers/${TRAINER_DOC_ID}/insights")

[ "$(echo "$INS" | jq -r 'if .insights then "y" else "n" end')" = "y" ] || fail "insights missing .insights ($INS)"
[ "$(echo "$INS" | jq '.insights | length')" -ge 5 ] && pass "insights has >=5 signals" || fail "insights count"

# every insight item has key/label/on/derived
BAD_ITEMS=$(echo "$INS" | jq '[.insights[] | select((has("key") and has("label") and has("on") and has("derived")) | not)] | length')
[ "$BAD_ITEMS" = "0" ] && pass "every insight has key/label/on/derived" || fail "insight item shape ($BAD_ITEMS malformed)"

# a fresh approved trainer is "accepting" (real), not yet "background verified" (real flags off)
ACCEPTING=$(echo "$INS" | jq -r '.insights[] | select(.key=="accepting") | .on')
[ "$ACCEPTING" = "true" ] && pass "accepting=true for approved trainer" || fail "accepting should be true ($ACCEPTING)"
VERIFIED=$(echo "$INS" | jq -r '.insights[] | select(.key=="verified") | .on')
[ "$VERIFIED" = "false" ] && pass "background-verified=false (no admin flags yet)" || fail "verified should be false ($VERIFIED)"

# responsiveness in derived band, demand real (0 for fresh trainer), no fabricated review
RPCT=$(echo "$INS" | jq -r '.responsiveness.pct')
[ "$RPCT" -ge 92 ] && [ "$RPCT" -le 98 ] && pass "responsiveness.pct in 92–98 ($RPCT)" || fail "responsiveness.pct out of band ($RPCT)"
DEMAND=$(echo "$INS" | jq -r '.demand.highDemand')
[ "$DEMAND" = "false" ] && pass "highDemand=false for fresh trainer" || fail "highDemand should be false ($DEMAND)"
FEATURED=$(echo "$INS" | jq -r '.proof.featuredReview')
[ "$FEATURED" = "null" ] && pass "no fabricated featured review (null)" || fail "featuredReview should be null ($FEATURED)"
[ "$(echo "$INS" | jq '.proof.topResults | length')" = "4" ] && pass "topResults has 4 derived stats" || fail "topResults count"

# ───────────────────────── PACKAGES ─────────────────────────
echo "== GET /packages shape =="
PKG=$(curl -s "$BASE_URL/api/trainers/${TRAINER_DOC_ID}/packages")

SESSIONS=$(echo "$PKG" | jq -c '[.packages[].sessions]')
[ "$SESSIONS" = "[5,10,20,40]" ] && pass "session tiers are 5/10/20/40" || fail "session tiers ($SESSIONS)"

# the 20-session tier is recommended + BEST VALUE
REC=$(echo "$PKG" | jq -r '.packages[] | select(.sessions==20) | "\(.recommended)|\(.badge)"')
[ "$REC" = "true|BEST VALUE" ] && pass "20-pack is recommended + BEST VALUE" || fail "20-pack flags ($REC)"

# total == perSession * sessions for every tier
BAD_MATH=$(echo "$PKG" | jq '[.packages[] | select(.total != (.perSession * .sessions))] | length')
[ "$BAD_MATH" = "0" ] && pass "total == perSession × sessions for all tiers" || fail "package pricing math ($BAD_MATH bad)"

# bigger packages have a lower per-session price (volume discount)
DESC=$(echo "$PKG" | jq -r '([.packages[].perSession]) as $p | ($p == ($p | sort | reverse))')
[ "$DESC" = "true" ] && pass "per-session price decreases with size" || fail "volume discount not monotonic"

# commitments: 3/6/12 months, 6-month recommended
MONTHS=$(echo "$PKG" | jq -c '[.commitments[].months]')
[ "$MONTHS" = "[3,6,12]" ] && pass "commitments are 3/6/12 months" || fail "commitment months ($MONTHS)"
REC6=$(echo "$PKG" | jq -r '.commitments[] | select(.months==6) | .recommended')
[ "$REC6" = "true" ] && pass "6-month commitment is recommended" || fail "6-month recommended ($REC6)"

# frequencies + add-ons present; derived flag true (no real coach rate yet)
[ "$(echo "$PKG" | jq '.frequencies | length')" = "5" ] && pass "5 frequency options" || fail "frequency count"
[ "$(echo "$PKG" | jq '.addOns | length')" = "5" ] && pass "5 à-la-carte add-ons" || fail "addOns count"
[ "$(echo "$PKG" | jq -r '.derived')" = "true" ] && pass "pricing flagged derived (no real rate)" || fail "derived flag"

# ───────────────────────── SEO SLUG ─────────────────────────
echo "== GET /by-slug resolves to the same trainer =="
SLUG=$(curl -s "$BASE_URL/api/trainers/${TRAINER_DOC_ID}" | jq -r '.trainer.slug')
require "trainer slug" "$SLUG"
BYSLUG_ID=$(curl -s "$BASE_URL/api/trainers/by-slug/${SLUG}" | jq -r '.trainer.id')
[ "$BYSLUG_ID" = "$TRAINER_DOC_ID" ] && pass "by-slug resolves to the trainer ($SLUG)" || fail "by-slug id mismatch ($BYSLUG_ID vs $TRAINER_DOC_ID)"
UNKSLUG=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/trainers/by-slug/no-such-coach-nowhere")
[ "$UNKSLUG" = "404" ] && pass "unknown slug -> 404" || fail "unknown slug expected 404, got $UNKSLUG"

# ───────────────────────── MATCH SCORE ─────────────────────────
echo "== POST /match returns overall + 5 factors =="
MATCH=$(curl -s -X POST "$BASE_URL/api/trainers/${TRAINER_DOC_ID}/match" \
  -H "Content-Type: application/json" \
  -d '{"prefs":{"goal":"Build Muscle","location":"Boston","schedule":["Morning","Evening"],"gender":"No preference"}}')
MOVERALL=$(echo "$MATCH" | jq -r '.overall')
[ "$MOVERALL" -ge 1 ] && [ "$MOVERALL" -le 100 ] && pass "match overall in 1–100 ($MOVERALL%)" || fail "match overall out of range ($MATCH)"
[ "$(echo "$MATCH" | jq '.factors | length')" = "5" ] && pass "match has 5 factors" || fail "match factor count"
MKEYS=$(echo "$MATCH" | jq -c '[.factors[].key]')
[ "$MKEYS" = '["goal","schedule","budget","location","style"]' ] && pass "match factor keys correct" || fail "match keys ($MKEYS)"
[ "$(echo "$MATCH" | jq -r '.personalized')" = "true" ] && pass "match flagged personalized (prefs sent)" || fail "personalized flag"
[ -n "$(echo "$MATCH" | jq -r '.quality')" ] && pass "match quality label present ($(echo "$MATCH" | jq -r '.quality'))" || fail "quality missing"

echo "== POST /match/batch scores multiple coaches in one call =="
BATCH=$(curl -s -X POST "$BASE_URL/api/match/batch" \
  -H "Content-Type: application/json" \
  -d "{\"ids\":[\"${TRAINER_DOC_ID}\",\"no-such-coach\"],\"prefs\":{\"goal\":\"Build Muscle\",\"location\":\"Boston\"}}")
[ "$(echo "$BATCH" | jq '.results | length')" = "1" ] && pass "batch skips unknown ids (1 result)" || fail "batch result count ($BATCH)"
BID=$(echo "$BATCH" | jq -r '.results[0].id')
[ "$BID" = "$TRAINER_DOC_ID" ] && pass "batch result id matches" || fail "batch id ($BID)"
BOVR=$(echo "$BATCH" | jq -r '.results[0].overall')
[ "$BOVR" -ge 1 ] && [ "$BOVR" -le 100 ] && pass "batch overall in range ($BOVR%)" || fail "batch overall ($BOVR)"

# ───────────────── RESERVED-ID SAFETY (regression) ─────────────────
echo "== reserved/invalid id returns 404 without crashing =="
for path in "insights" "packages"; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/trainers/__x__/${path}")
  [ "$CODE" = "404" ] && pass "reserved id __x__ /${path} -> 404" || fail "reserved id /${path} got $CODE"
done
BADCODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/trainers/no-such-coach/packages")
[ "$BADCODE" = "404" ] && pass "unknown id -> 404" || fail "unknown id got $BADCODE"

echo "== API still healthy after bad requests =="
for i in 1 2 3; do
  H=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/trainers")
  [ "$H" = "200" ] || fail "API unhealthy after reserved-id requests ($H)"
  sleep 1
done
pass "API stayed up (200) after reserved/invalid id requests"

echo "== cleanup =="
cleanup
pass "profile data E2E test"
