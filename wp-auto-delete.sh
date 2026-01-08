#!/bin/bash
set -Euo pipefail

####################################
# CONFIG
####################################
SCRIPT_DIR=$(dirname "$(realpath "$0")")
DOMAINS_FILE="$SCRIPT_DIR/domains.txt"
BASE_ROOT="/var/www"
REPORT_FILE="$SCRIPT_DIR/install-report.txt"

####################################
# LOGGING
####################################
LOG(){ echo -e "\033[1;32m[$(date '+%F %T')] $1\033[0m"; }
WARN(){ echo -e "\033[1;33m[$(date '+%F %T')] $1\033[0m"; }
ERR(){ echo -e "\033[1;31m[$(date '+%F %T')] $1\033[0m"; }

####################################
# MYSQL SETUP
####################################
setup_mysql(){
  sudo systemctl enable mariadb
  sudo systemctl start mariadb

  MYSQL_ROOT_PASS="rMuD@e5HH5vuvJE"

  if mysql -u root -p"$MYSQL_ROOT_PASS" -e "SELECT 1;" >/dev/null 2>&1; then
    LOG "MySQL root password is already set correctly"
  else
    if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
      LOG "Setting MySQL root password"
      mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';
FLUSH PRIVILEGES;
EOF
    else
      ERR "MySQL root has a password set that is not the expected one. Please reset MariaDB or run delete --all first."
      exit 1
    fi
  fi

  echo "$MYSQL_ROOT_PASS" | sudo tee /root/.mysql_root_pass >/dev/null
  export MYSQL_ROOT_PASS
}

####################################
# WAIT FOR MYSQL READY
####################################
wait_for_mysql(){
  LOG "Waiting for MySQL to be ready..."
  for i in {1..30}; do
    if mysqladmin ping -u root -p"$MYSQL_ROOT_PASS" --silent; then
      LOG "MySQL is ready"
      return
    fi
    sleep 1
  done
  ERR "MySQL not ready after 30 seconds"
}

####################################
# DELETE DOMAIN
####################################
delete_domain(){
  DOMAIN="$1"
  ROOT="$BASE_ROOT/$DOMAIN"
  DB_NAME=""
  DB_USER=""

  LOG "START DELETE: $DOMAIN"

  # Get DB info from report file first
  REPORT_LINE=$(grep "^$DOMAIN |" "$REPORT_FILE" || true)
  if [ -n "$REPORT_LINE" ]; then
    DB_NAME=$(echo "$REPORT_LINE" | awk -F' | ' '{print $2}')
    DB_USER=$(echo "$REPORT_LINE" | awk -F' | ' '{print $3}')
  else
    # Fallback to WordPress config if site exists
    if [ -d "$ROOT" ] && [ -f "$ROOT/wp-config.php" ]; then
      DB_NAME=$(grep "define('DB_NAME'" "$ROOT/wp-config.php" | sed "s/.*'//;s/'.*//")
      DB_USER=$(grep "define('DB_USER'" "$ROOT/wp-config.php" | sed "s/.*'//;s/'.*//")
    fi
  fi

  if [ -n "$DB_NAME" ] && [ -n "$DB_USER" ]; then
    # Drop database and user
    mysql -u root -p"$MYSQL_ROOT_PASS" <<EOF
DROP DATABASE IF EXISTS \`$DB_NAME\`;
DROP USER IF EXISTS '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
    LOG "Dropped DB $DB_NAME and user $DB_USER for $DOMAIN"
  else
    WARN "Could not retrieve DB info for $DOMAIN"
  fi

  # Remove nginx config
  rm -f /etc/nginx/sites-available/$DOMAIN
  rm -f /etc/nginx/sites-enabled/$DOMAIN
  nginx -t && systemctl reload nginx || WARN "nginx reload failed"

  # Remove site files
  rm -rf "$ROOT"

  # Remove from report
  sed -i "/^$DOMAIN |/d" "$REPORT_FILE"

  LOG "DONE DELETE: $DOMAIN"
}

####################################
# DELETE ALL
####################################
delete_all(){
  LOG "START DELETE ALL"

  # Stop MariaDB
  sudo systemctl stop mariadb || true

  # Purge MariaDB and MySQL packages
  sudo apt-get purge -y mariadb-server mariadb-client mariadb-common mysql-server mysql-client mysql-common || true

  # Remove MySQL/MariaDB data and config directories
  sudo rm -rf /var/lib/mysql
  sudo rm -rf /etc/mysql
  sudo rm -rf /var/log/mysql

  # Remove MySQL root password file
  sudo rm -f /root/.mysql_root_pass

  # Autoremove and autoclean
  sudo apt-get autoremove -y
  sudo apt-get autoclean

  # Remove all site files
  rm -rf "$BASE_ROOT"/*

  # Remove nginx configs
  rm -f /etc/nginx/sites-available/*
  rm -f /etc/nginx/sites-enabled/*
  nginx -t && systemctl reload nginx || WARN "nginx reload failed"

  # Remove SSL certs
  if [ -f "$DOMAINS_FILE" ]; then
    while read -r DOMAIN; do
      [ -z "$DOMAIN" ] && continue
      sudo certbot delete --cert-name $DOMAIN --non-interactive || WARN "SSL delete failed for $DOMAIN"
    done < "$DOMAINS_FILE"
  fi

  # Clear report file
  > "$REPORT_FILE"

  LOG "DONE DELETE ALL"
}

####################################
# BOOTSTRAP
####################################
if [ "${1:-}" = "--all" ]; then
  delete_all
else
  setup_mysql
  wait_for_mysql

  ####################################
  # DELETE LOOP
  ####################################
  while read -r DOMAIN; do
    [ -z "$DOMAIN" ] && continue
    delete_domain "$DOMAIN"
  done < "$DOMAINS_FILE"

  # Delete SSL one by one if multiple domains
  num_domains=$(grep -c '[^[:space:]]' "$DOMAINS_FILE")
  if [ "$num_domains" -gt 1 ]; then
    LOG "Deleting SSL certificates one by one for multiple domains"
    while read -r DOMAIN; do
      [ -z "$DOMAIN" ] && continue
      sudo certbot delete --cert-name $DOMAIN --non-interactive || WARN "SSL delete failed for $DOMAIN"
    done < "$DOMAINS_FILE"
  fi
fi

LOG "🎉 ALL DELETES DONE"
