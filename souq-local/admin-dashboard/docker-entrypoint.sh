#!/bin/sh
set -eu

API_URL="${MARGEM_API_URL:-http://localhost:8000}"
API_URL="${API_URL%/}"

cat > /usr/share/nginx/html/config.js <<EOF
// Generated at container start — points the admin UI at the Dribex API.
window.MARGEM_API_URL = "${API_URL}";
EOF

ADMIN_CSP="default-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; script-src 'self' https://cdn.jsdelivr.net; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' ${API_URL}; font-src 'self'"

USE_BASIC_AUTH=false
if [ -n "${ADMIN_BASIC_AUTH_USER:-}" ] && [ -n "${ADMIN_BASIC_AUTH_PASSWORD:-}" ]; then
  HASH="$(openssl passwd -apr1 "${ADMIN_BASIC_AUTH_PASSWORD}")"
  printf '%s:%s\n' "${ADMIN_BASIC_AUTH_USER}" "${HASH}" > /etc/nginx/.htpasswd
  chmod 600 /etc/nginx/.htpasswd
  USE_BASIC_AUTH=true
  echo "Admin HTTP Basic Auth enabled for user ${ADMIN_BASIC_AUTH_USER}"
fi

if [ "${ADMIN_ALLOW_PUBLIC:-false}" = "true" ]; then
  cat > /etc/nginx/admin-ip-rules.conf <<'EOF'
# Public access enabled (not recommended on the internet).
EOF
else
  cat > /etc/nginx/admin-ip-rules.conf <<'EOF'
allow 127.0.0.0/8;
allow 10.0.0.0/8;
allow 172.16.0.0/12;
allow 192.168.0.0/16;
EOF
  if [ -n "${ADMIN_EXTRA_ALLOWED_CIDRS:-}" ]; then
    echo "$ADMIN_EXTRA_ALLOWED_CIDRS" | tr ',' '\n' | while IFS= read -r cidr; do
      cidr="$(echo "$cidr" | tr -d ' ')"
      [ -n "$cidr" ] && echo "allow ${cidr};" >> /etc/nginx/admin-ip-rules.conf
    done
  fi
  echo "deny all;" >> /etc/nginx/admin-ip-rules.conf
  echo "Admin IP allowlist: private networks only"
fi

{
  echo 'limit_req_zone $binary_remote_addr zone=admin_ui:10m rate=30r/m;'
  echo ''
  echo 'server {'
  echo '    listen 80;'
  echo '    server_name _;'
  echo '    root /usr/share/nginx/html;'
  echo '    index index.html;'
  echo ''
  echo '    add_header X-Frame-Options "DENY" always;'
  echo '    add_header X-Content-Type-Options "nosniff" always;'
  echo '    add_header Referrer-Policy "no-referrer" always;'
  echo '    add_header Permissions-Policy "geolocation=(), microphone=(), camera=(), payment=(), usb=()" always;'
  echo '    add_header Cross-Origin-Opener-Policy "same-origin" always;'
  echo '    add_header Cross-Origin-Resource-Policy "same-origin" always;'
  echo '    add_header X-Robots-Tag "noindex, nofollow" always;'
  echo "    add_header Content-Security-Policy \"${ADMIN_CSP}\" always;"
  echo ''
  echo '    include /etc/nginx/admin-ip-rules.conf;'
  echo ''
  echo '    location / {'
  echo '        limit_req zone=admin_ui burst=20 nodelay;'
  if [ "$USE_BASIC_AUTH" = true ]; then
    echo '        auth_basic "Dribex Admin";'
    echo '        auth_basic_user_file /etc/nginx/.htpasswd;'
  fi
  echo '        try_files $uri $uri/ /index.html;'
  echo '    }'
  echo ''
  echo '    location ~* \.(js|css|html)$ {'
  echo '        limit_req zone=admin_ui burst=20 nodelay;'
  if [ "$USE_BASIC_AUTH" = true ]; then
    echo '        auth_basic "Dribex Admin";'
    echo '        auth_basic_user_file /etc/nginx/.htpasswd;'
  fi
  echo '        add_header Cache-Control "no-store" always;'
  echo '        try_files $uri =404;'
  echo '    }'
  echo '}'
} > /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'
