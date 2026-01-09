
#!/bin/bash
set -e

DOMAINS_FILE="domains.txt"
SSL_DIR="/etc/ssl/cloudflare"
NGINX_AVAIL="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

mkdir -p "$SSL_DIR"

if [[ -z "$CF_API_KEY" || -z "$CF_EMAIL" ]]; then
  echo "❌ CF_API_KEY or CF_EMAIL not set in env"
  exit 1
fi

if [[ ! -f "$DOMAINS_FILE" ]]; then
  echo "❌ domains.txt not found"
  exit 1
fi

while read -r DOMAIN; do
  [[ -z "$DOMAIN" ]] && continue

  echo "🔐 Processing: $DOMAIN"

  RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/certificates" \
    -H "X-Auth-Email: $CF_EMAIL" \
    -H "X-Auth-Key: $CF_API_KEY" \
    -H "Content-Type: application/json" \
    --data "{
      \"type\":\"origin-rsa\",
      \"hosts\":[\"$DOMAIN\",\"www.$DOMAIN\"],
      \"requested_validity\":5475
    }")

  SUCCESS=$(echo "$RESPONSE" | jq -r '.success')

  if [[ "$SUCCESS" != "true" ]]; then
    echo "❌ SSL generation failed for $DOMAIN"
    echo "$RESPONSE"
    continue
  fi

  echo "$RESPONSE" | jq -r '.result.certificate' > "$SSL_DIR/$DOMAIN.pem"
  echo "$RESPONSE" | jq -r '.result.private_key' > "$SSL_DIR/$DOMAIN.key"

  chmod 600 "$SSL_DIR/$DOMAIN.key"

  echo "✅ SSL generated for $DOMAIN"

  WEBROOT="/var/www/$DOMAIN"

  mkdir -p "$WEBROOT"

  NGINX_CONF="$NGINX_AVAIL/$DOMAIN.conf"

  cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    ssl_certificate $SSL_DIR/$DOMAIN.pem;
    ssl_certificate_key $SSL_DIR/$DOMAIN.key;

    root $WEBROOT;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

  ln -sf "$NGINX_CONF" "$NGINX_ENABLED/$DOMAIN.conf"

  echo "🌐 Nginx configured for $DOMAIN"

done < "$DOMAINS_FILE"

echo "🔄 Testing Nginx..."
nginx -t && systemctl reload nginx

echo "🎉 All domains processed successfully"
