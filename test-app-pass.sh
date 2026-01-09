#!/bin/bash
set -Eeuo pipefail

REPORT_FILE="install-report.txt"
DOMAINS_FILE="domains.txt"
WP_USER="publisher"

# Check required files
if [[ ! -f "$DOMAINS_FILE" ]]; then
  echo "❌ domains.txt not found"
  exit 1
fi

if [[ ! -f "$REPORT_FILE" ]]; then
  echo "❌ install-report.txt not found"
  exit 1
fi

while IFS= read -r DOMAIN || [[ -n "$DOMAIN" ]]; do
  # Skip empty lines
  [[ -z "$DOMAIN" ]] && continue

  echo "🔍 Testing domain: $DOMAIN"

  # Match exact domain line
  LINE=$(grep -i "domain[[:space:]]*:[[:space:]]*$DOMAIN" "$REPORT_FILE" || true)

  if [[ -z "$LINE" ]]; then
    echo "❌ Domain not found in report"
    echo "----------------------------------------"
    continue
  fi

  # Extract application password
  APP_PASS=$(echo "$LINE" | sed -n 's/.*application pass:[[:space:]]*//Ip' | tr -d '\r')

  if [[ -z "$APP_PASS" ]]; then
    echo "❌ Application password missing"
    echo "----------------------------------------"
    continue
  fi

  # Test WordPress REST API
  RESPONSE=$(curl -sS --max-time 10 \
    -u "$WP_USER:$APP_PASS" \
    "https://$DOMAIN/wp-json/wp/v2/users/me" || true)

  if echo "$RESPONSE" | grep -q '"id"'; then
    echo "✅ Application password WORKING"
  else
    echo "❌ Application password NOT working"
    echo "🔎 Response: $RESPONSE"
  fi

  echo "----------------------------------------"

done < "$DOMAINS_FILE"
