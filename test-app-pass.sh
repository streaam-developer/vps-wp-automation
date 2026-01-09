#!/bin/bash
set -Eeuo pipefail

REPORT_FILE="install-report.txt"
DOMAINS_FILE="domains.txt"
WP_USER="publisher"
PARALLEL_WORKERS=5   # 🔥 change as needed

WORKING_FILE="$(mktemp)"
FAILED_FILE="$(mktemp)"

cleanup() {
  rm -f "$WORKING_FILE" "$FAILED_FILE"
}
trap cleanup EXIT

# -------- checks ----------
[[ ! -f "$DOMAINS_FILE" ]] && { echo "❌ domains.txt not found"; exit 1; }
[[ ! -f "$REPORT_FILE" ]] && { echo "❌ install-report.txt not found"; exit 1; }

# -------- function ----------
check_domain() {
  DOMAIN="$1"

  echo "🔍 Testing domain: $DOMAIN"

  LINE=$(grep -i "domain[[:space:]]*:[[:space:]]*$DOMAIN" "$REPORT_FILE" || true)
  if [[ -z "$LINE" ]]; then
    echo "❌ Domain not found in report"
    echo "$DOMAIN | NOT FOUND IN REPORT" >> "$FAILED_FILE"
    echo "----------------------------------------"
    return
  fi

  APP_PASS=$(echo "$LINE" | sed -n 's/.*application pass:[[:space:]]*//Ip' | tr -d '\r')
  if [[ -z "$APP_PASS" ]]; then
    echo "❌ Application password missing"
    echo "$DOMAIN | NO APP PASSWORD" >> "$FAILED_FILE"
    echo "----------------------------------------"
    return
  fi

  # Mask password (safe display)
  if (( ${#APP_PASS} > 10 )); then
    MASKED_PASS="${APP_PASS:0:4}****${APP_PASS: -6}"
  else
    MASKED_PASS="****"
  fi
  echo "🔐 Testing APP_PASS: $MASKED_PASS"

  RESPONSE=$(curl -sS --max-time 10 \
    -u "$WP_USER:$APP_PASS" \
    "https://$DOMAIN/wp-json/wp/v2/users/me" || true)

  if echo "$RESPONSE" | grep -q '"id"'; then
    echo "✅ RESULT: WORKING"
    echo "$DOMAIN" >> "$WORKING_FILE"
  else
    echo "❌ RESULT: NOT WORKING"
    echo "🔎 Response: $RESPONSE"
    echo "$DOMAIN" >> "$FAILED_FILE"
  fi

  echo "----------------------------------------"
}

export -f check_domain
export REPORT_FILE WP_USER WORKING_FILE FAILED_FILE

# -------- parallel run ----------
grep -v '^[[:space:]]*$' "$DOMAINS_FILE" | \
  xargs -n 1 -P "$PARALLEL_WORKERS" -I {} bash -c 'check_domain "$@"' _ {}

# -------- final summary ----------
echo
echo "================ FINAL SUMMARY ================"

echo
echo "✅ WORKING DOMAINS:"
if [[ -s "$WORKING_FILE" ]]; then
  sort -u "$WORKING_FILE"
else
  echo "None"
fi

echo
echo "❌ NOT WORKING DOMAINS:"
if [[ -s "$FAILED_FILE" ]]; then
  sort -u "$FAILED_FILE"
else
  echo "None"
fi

echo "=============================================="
