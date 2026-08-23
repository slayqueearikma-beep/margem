#!/bin/sh
set -eu

API_URL="${MARGEM_API_URL:-http://localhost:8000}"
API_URL="${API_URL%/}"

cat > /usr/share/nginx/html/config.js <<EOF
// Generated at container start — points the admin UI at the MarGem API.
window.MARGEM_API_URL = "${API_URL}";
EOF

exec nginx -g 'daemon off;'
