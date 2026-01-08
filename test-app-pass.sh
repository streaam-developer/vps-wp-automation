#!/bin/bash
set -Euo pipefail

REPORT_FILE="/home/ubuntu/install-report.txt"
DOMAIN="healthyhumansource.com"

# Find the line for the domain
LINE=$(grep "^$DOMAIN " "$REPORT_FILE" || true)

if [ -z "$LINE" ]; then
  echo "Domain $DOMAIN not found in report"
  exit 1
fi

# Parse APP_PASS (last field)
APP_PASS=$(echo "$LINE" | awk -F'|' '{print $NF}' | xargs)

if [ -z "$APP_PASS" ]; then
  echo "APP_PASS not found for $DOMAIN"
  exit 1
fi

# Test the app password
if wp --http="https://$DOMAIN" --user=publisher --password="$APP_PASS" user get publisher --field=ID >/dev/null 2>&1; then
  echo "Application password for $DOMAIN is working"
else
  echo "Application password for $DOMAIN is not working"
fi