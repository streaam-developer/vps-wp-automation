#!/bin/bash
set -Euo pipefail
# ❌ no set -e (never auto-exit)

####################################
# CONFIG
####################################
DOMAINS_FILE="/home/ubuntu/domains.txt"
BASE_ROOT="/var/www"
REPORT_FILE="/home/ubuntu/install-report.txt"

PLUGIN_DIR="/home/ubuntu/wp-auto-req/plugin"
THEME_DIR="/home/ubuntu/wp-auto-req/theme"
FAVICON_FILE="/home/ubuntu/favicon.ico"

ADMIN_USER="admin"
ADMIN_PASS="rMuD@e5HH5vuvJE"

PUB_USER="publisher"
PUB_PASS="rMuD@e5HH5vuvJE"

APP_PASS_PLAIN="LpKz iSnw 0VfM 2rKn O4VV YLyM"
APP_NAME="publisher-app"

PARALLEL_JOBS=3
CERTBOT_LOCK="/var/run/certbot-global.lock"

# News site titles and taglines
TITLES=(
  "Breaking News Hub"
  "Daily News Update"
  "News Central"
  "Global News Network"
  "Local News Today"
  "News Flash"
  "The News Bulletin"
  "Headline News"
  "News Wire"
  "Current Affairs"
)

TAGLINES=(
  "Stay Informed with the Latest News"
  "Your Source for Breaking Stories"
  "News That Matters"
  "Connecting You to the World"
  "Timely Updates on Current Events"
  "Reliable News Coverage"
  "In-Depth Reporting"
  "Fast, Accurate News"
  "Your Daily News Digest"
  "Empowering Through Information"
)

####################################
# LOGGING
####################################
LOG(){ echo -e "\033[1;32m[$(date '+%F %T')] $1\033[0m"; }
WARN(){ echo -e "\033[1;33m[$(date '+%F %T')] $1\033[0m"; }
ERR(){ echo -e "\033[1;31m[$(date '+%F %T')] $1\033[0m"; }

####################################
# INSTALL STACK
####################################
install_stack(){
  sudo apt update
  sudo apt install -y \
    nginx mariadb-server mariadb-client \
    php php-fpm php-cli php-mysql php-curl php-gd \
    php-xml php-mbstring php-zip unzip curl \
    certbot python3-certbot-nginx
}

####################################
# WP-CLI
####################################
install_wpcli(){
  if ! command -v wp >/dev/null 2>&1; then
    curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    sudo mv wp-cli.phar /usr/local/bin/wp
  fi
}

####################################
# PHP-FPM DETECT
####################################
detect_php_fpm(){
  PHP_FPM_SERVICE=$(systemctl list-unit-files | awk '/php.*fpm.service/{print $1; exit}')
  PHP_FPM_SOCK=$(ls /run/php/php*-fpm.sock 2>/dev/null | head -n1)

  sudo systemctl enable "$PHP_FPM_SERVICE"
  sudo systemctl start "$PHP_FPM_SERVICE"

  export PHP_FPM_SOCK
}

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
# WAIT FOR MYSQL READY (🔥 FIX)
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
# ENSURE NGINX RUNNING
####################################
ensure_nginx(){
  if ! systemctl is-active --quiet nginx; then
    LOG "Starting nginx"
    sudo systemctl start nginx
  fi
}

####################################
# NGINX VHOST
####################################
setup_nginx(){
  domain=$1
  root=$2

  cat > /etc/nginx/sites-available/$domain <<EOF
server {
    listen 80;
    server_name $domain www.$domain;
    root $root;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_FPM_SOCK;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

  ln -sf /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
}

####################################
# SSL (SERIAL SAFE)
####################################
setup_ssl(){
(
  flock -x 200
  ensure_nginx

  certbot --nginx \
    -d "$1" -d "www.$1" \
    --non-interactive --agree-tos \
    -m "admin@$1" --redirect \
    || WARN "SSL skipped for $1"

) 200>"$CERTBOT_LOCK"
}

####################################
# DOMAIN INSTALL (FULLY FIXED)
####################################
install_domain(){
(
  set +e
  DOMAIN="$1"
  ROOT="$BASE_ROOT/$DOMAIN"

  [ -f "$ROOT/.installed" ] && LOG "SKIPPED $DOMAIN" && exit 0
  LOG "START DOMAIN: $DOMAIN"

  DB_SUFFIX=$(openssl rand -hex 4)
  DB_NAME="wp_${DOMAIN//./_}_${DB_SUFFIX}"
  DB_USER="u_${DB_NAME:0:12}"
  DB_PASS=$(openssl rand -base64 16)
  ADMIN_EMAIL="admin@$DOMAIN"

  # Pick random title and tagline
  TITLE_INDEX=$((RANDOM % ${#TITLES[@]}))
  TITLE=${TITLES[$TITLE_INDEX]}
  TAGLINE_INDEX=$((RANDOM % ${#TAGLINES[@]}))
  TAGLINE=${TAGLINES[$TAGLINE_INDEX]}

  mkdir -p "$ROOT"
  cd "$ROOT" || exit 1

  # 🔥 FIX: remove old wp-config to avoid mismatch
  [ -f wp-config.php ] && rm -f wp-config.php

  wp core download --allow-root || true

  mysql -u root -p"$MYSQL_ROOT_PASS" <<EOF
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

  # 🔥 FIX: DB connection test
  mysql -u"$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME;" 2>/dev/null || {
    ERR "DB connection failed for $DOMAIN"
    exit 1
  }

  wp config create \
    --dbname="$DB_NAME" \
    --dbuser="$DB_USER" \
    --dbpass="$DB_PASS" \
    --dbhost=localhost \
    --skip-check \
    --allow-root || exit 1

  export WP_CLI_PHP_ARGS="-d variables_order=EGPCS"

  wp core install \
    --url="https://$DOMAIN" \
    --title="$TITLE" \
    --admin_user="$ADMIN_USER" \
    --admin_password="$ADMIN_PASS" \
    --admin_email="$ADMIN_EMAIL" \
    --skip-email \
    --allow-root || exit 1

  wp option update blogdescription "$TAGLINE" --allow-root

  wp user create "$PUB_USER" "publisher@$DOMAIN" \
    --role=author \
    --user_pass="$PUB_PASS" \
    --allow-root || true

  # APPLICATION PASSWORD
  wp eval --allow-root "
\$u=get_user_by('login','$PUB_USER');
\$apps=get_user_meta(\$u->ID,'_application_passwords',true);
if(!is_array(\$apps))\$apps=[];
\$apps[wp_generate_uuid4()]=[
'name'=>'$APP_NAME',
'password'=>wp_hash_password('$APP_PASS_PLAIN'),
'created'=>time(),
'last_used'=>null,
'last_ip'=>null
];
update_user_meta(\$u->ID,'_application_passwords',\$apps);
"

  for p in "$PLUGIN_DIR"/*.zip; do
    [ -f "$p" ] && wp plugin install "$p" --activate --allow-root
  done

  # Delete default plugins
  wp plugin is-installed akismet && wp plugin delete akismet --allow-root || true
  wp plugin is-installed hello-dolly && wp plugin delete hello-dolly --allow-root || true

  # Pick and install one theme
  THEME_FILE=$(ls "$THEME_DIR"/*.zip 2>/dev/null | head -1)
  if [ -f "$THEME_FILE" ]; then
    THEME_SLUG=$(wp theme install "$THEME_FILE" --porcelain --allow-root)
    wp theme activate "$THEME_SLUG" --allow-root
    # Delete default themes
    wp theme is-installed twentytwentyfour && wp theme delete twentytwentyfour --allow-root || true
    wp theme is-installed twentytwentythree && wp theme delete twentytwentythree --allow-root || true
    wp theme is-installed twentytwentytwo && wp theme delete twentytwentytwo --allow-root || true
    wp theme is-installed twentyseventeen && wp theme delete twentyseventeen --allow-root || true
  fi

  # Delete default posts and pages
  wp post list --post_type=post --allow-root --format=ids | xargs wp post delete --force --allow-root || true
  wp post list --post_type=page --allow-root --format=ids | xargs wp post delete --force --allow-root || true

  # Set permalink structure
  wp rewrite structure '/%postname%/' --allow-root

  # Set timezone
  wp option update timezone_string 'Asia/Kolkata' --allow-root

  # Set favicon
  if [ -f "$FAVICON_FILE" ]; then
    ATTACHMENT_ID=$(wp media import "$FAVICON_FILE" --porcelain --allow-root)
    wp option update site_icon "$ATTACHMENT_ID" --allow-root
  fi

  setup_nginx "$DOMAIN" "$ROOT"
  nginx -t && systemctl reload nginx || WARN "nginx reload skipped"

  setup_ssl "$DOMAIN"

  chown -R www-data:www-data "$ROOT"

  echo "$DOMAIN | $DB_NAME | $DB_USER | $DB_PASS | APP_PASS | $APP_PASS_PLAIN" \
    >> "$REPORT_FILE"

  touch "$ROOT/.installed"
  LOG "DONE DOMAIN: $DOMAIN"
) || ERR "FAILED DOMAIN: $1"
}

####################################
# BOOTSTRAP
####################################
install_stack
install_wpcli
detect_php_fpm
setup_mysql
wait_for_mysql
ensure_nginx

####################################
# PARALLEL LOOP
####################################
> "$REPORT_FILE"
jobs=0

while read -r DOMAIN; do
  [ -z "$DOMAIN" ] && continue
  install_domain "$DOMAIN" &
  ((jobs++))
  (( jobs >= PARALLEL_JOBS )) && wait -n && ((jobs--))
done < "$DOMAINS_FILE"

wait
LOG "🎉 ALL DOMAINS DONE"
LOG "📄 REPORT: $REPORT_FILE"
