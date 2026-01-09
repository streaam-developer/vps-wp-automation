#!/bin/bash
# Update the central must-use plugin

SCRIPT_DIR=$(dirname "$(realpath "$0")")
CENTRAL_MU="/var/www/mu-plugins"
PLUGIN_FILE="$SCRIPT_DIR/plugin/central-mu-plugin.php"

if [ ! -f "$PLUGIN_FILE" ]; then
    echo "Plugin file not found: $PLUGIN_FILE"
    exit 1
fi

cp "$PLUGIN_FILE" "$CENTRAL_MU/"
chown www-data:www-data "$CENTRAL_MU/central-mu-plugin.php"

echo "Central MU plugin updated successfully."