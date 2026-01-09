#!/bin/bash
# Update permissions for the central must-use plugin

SCRIPT_DIR=$(dirname "$(realpath "$0")")
CENTRAL_MU="$SCRIPT_DIR/central-mu"

if [ ! -d "$CENTRAL_MU" ]; then
    echo "Central MU directory not found: $CENTRAL_MU"
    exit 1
fi

chown -R www-data:www-data "$CENTRAL_MU"

echo "Central MU plugin permissions updated successfully."