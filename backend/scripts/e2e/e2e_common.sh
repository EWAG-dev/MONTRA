# Shared config + helpers for booking E2E test scripts. Source this, don't run directly.
BASE_URL="https://montra-production.up.railway.app"

# Required env vars (export these in your shell before running any *_e2e_test.sh — not
# stored in this file so we don't leave a second plaintext copy of the admin password on disk):
#   export FIREBASE_WEB_API_KEY="..."
#   export ADMIN_EMAIL="..."
#   export ADMIN_PASSWORD="..."
for _v in FIREBASE_WEB_API_KEY ADMIN_EMAIL ADMIN_PASSWORD; do
  if [ -z "${!_v:-}" ]; then
    echo "Missing required env var: $_v (export it before running this script)" >&2
    exit 1
  fi
done

sign_in() {
  local email="$1" password="$2"
  curl -s "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_WEB_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${email}\",\"password\":\"${password}\",\"returnSecureToken\":true}" \
    | jq -r '.idToken'
}

admin_token() {
  sign_in "$ADMIN_EMAIL" "$ADMIN_PASSWORD"
}

# create_test_trainer <email> <password> <name>  -> prints uid
create_test_trainer() {
  curl -s -X POST "$BASE_URL/api/dev/create-test-trainer" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"$2\",\"name\":\"$3\"}" | jq -r '.uid'
}

# create_test_client <token> <email> <password> <name> -> prints uid
create_test_client() {
  curl -s -X POST "$BASE_URL/api/dev/create-test-client" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $1" \
    -d "{\"email\":\"$2\",\"password\":\"$3\",\"name\":\"$4\"}" | jq -r '.uid'
}

# trainer_doc_id_by_email <email> -> prints firestore doc id
trainer_doc_id_by_email() {
  curl -s "$BASE_URL/api/trainers" | jq -r --arg email "$1" '.trainers[] | select(.email==$email) | .id'
}

# cleanup_test_data <admin_token> <trainer_uid> <client_uid>
cleanup_test_data() {
  curl -s -X POST "$BASE_URL/api/dev/cleanup-test-data" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $1" \
    -d "{\"trainerUid\":\"$2\",\"clientUid\":\"$3\"}"
}

iso_in_days() {
  date -u -v+"${1}"d +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -d "+${1} day" +"%Y-%m-%dT%H:%M:%S.000Z"
}

require() {
  local label="$1" value="$2"
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    echo "FAIL: $label" >&2
    exit 1
  fi
}

pass() { echo "PASS: $1"; }
