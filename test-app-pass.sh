#!/bin/bash
set -Euo pipefail

REPORT_FILE="install-report.txt"
DOMAINS_FILE="domains.txt"

if [ ! -f "$DOMAINS_FILE" ]; then
  echo "Domains file $DOMAINS_FILE not found"
  exit 1
fi

while IFS= read -r DOMAIN; do
  # Skip empty lines
  [ -z "$DOMAIN" ] && continue

  echo "Testing domain: $DOMAIN"

  # Find the line for the domain
  LINE=$(grep "^$DOMAIN " "$REPORT_FILE" || true)

  if [ -z "$LINE" ]; then
    echo "Domain $DOMAIN not found in report"
    continue
  fi

  # Parse APP_PASS (last field)
  APP_PASS=$(echo "$LINE" | awk -F'|' '{print $NF}' | xargs)

  if [ -z "$APP_PASS" ]; then
    echo "APP_PASS not found for $DOMAIN"
    continue
  fi

  # Test the app password using REST API
  RESPONSE=$(curl -s -u "publisher:$APP_PASS" "https://$DOMAIN/wp-json/wp/v2/users/me")
  echo "APP_PASS: $APP_PASS"
  if echo "$RESPONSE" | grep -q '"id"'; then
    echo "Application password for $DOMAIN is working"
  else
    echo "Application password for $DOMAIN is not working"
    echo "Response: $RESPONSE"
  fi

  echo "----------------------------------------"

done < "$DOMAINS_FILE"
