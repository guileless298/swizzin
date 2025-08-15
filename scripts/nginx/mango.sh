#!/bin/bash
# Nginx configuration for Mango

cat > /etc/nginx/apps/mango.conf << EOF
location /mango/ {
  proxy_pass http://localhost:9003/;
  proxy_http_version 1.1;
  proxy_set_header Upgrade \$http_upgrade;
  proxy_set_header Connection "upgrade";
}
EOF

if [[ -f /install/.subdomain.lock ]]; then
    # shellcheck disable=SC2016
    sed -i '/^[[:space:]]*proxy_pass/ s|:9003/;|:9003$request_uri;|' /etc/nginx/apps/mango.conf
fi

systemctl restart mango
