#!/bin/bash
set -Euo pipefail

####################################
# CONFIG
####################################
DOMAINS_FILE="/home/ubuntu/domains.txt"
BASE_ROOT="/var/www"
REPORT_FILE="/home/ubuntu/install-report.txt"

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

  if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
    MYSQL_ROOT_PASS=$(openssl rand -base64 20)
    mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';
FLUSH PRIVILEGES;
EOF
    echo "$MYSQL_ROOT_PASS" | sudo tee /root/.mysql_root_pass >/dev/null
  else
    MYSQL_ROOT_PASS=$(sudo cat /root/.mysql_root_pass)
  fi

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

  LOG "START DELETE: $DOMAIN"

  # Get DB info from report
  DB_INFO=$(grep "^$DOMAIN |" "$REPORT_FILE" || true)
  if [ -n "$DB_INFO" ]; then
    DB_NAME=$(echo "$DB_INFO" | awk -F' | ' '{print $2}')
    DB_USER=$(echo "$DB_INFO" | awk -F' | ' '{print $3}')

    # Drop database and user
    mysql -u root -p"$MYSQL_ROOT_PASS" <<EOF
DROP DATABASE IF EXISTS \`$DB_NAME\`;
DROP USER IF EXISTS '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
    LOG "Dropped DB $DB_NAME and user $DB_USER for $DOMAIN"
  else
    WARN "No DB info found for $DOMAIN in report"
  fi

  # Remove nginx config
  rm -f /etc/nginx/sites-available/$DOMAIN
  rm -f /etc/nginx/sites-enabled/$DOMAIN
  nginx -t && systemctl reload nginx || WARN "nginx reload failed"

  # Remove SSL cert
  certbot delete --cert-name $DOMAIN --non-interactive || WARN "SSL delete failed for $DOMAIN"

  # Remove site files
  rm -rf "$ROOT"

  # Remove from report
  sed -i "/^$DOMAIN |/d" "$REPORT_FILE"

  LOG "DONE DELETE: $DOMAIN"
}

####################################
# BOOTSTRAP
####################################
setup_mysql
wait_for_mysql

####################################
# DELETE LOOP
####################################
while read -r DOMAIN; do
  [ -z "$DOMAIN" ] && continue
  delete_domain "$DOMAIN"
done < "$DOMAINS_FILE"

LOG "🎉 ALL DELETES DONE"