#!/bin/bash
# nginx configuration for flood
# Author: flying_sausages

cat > /etc/nginx/apps/flood.conf << EOF
location /flood/api {
  proxy_pass http://\$remote_user.flood;
  proxy_buffering off;
  proxy_cache off;
  auth_basic "What's the password?";
  auth_basic_user_file /etc/htpasswd;
}

location /flood {
    return 302 \$scheme://\$host/flood/;
}

location /flood/ {
  alias /usr/lib/node_modules/flood/dist/assets/;
  try_files \$uri /flood/index.html;
  gzip on;
  gzip_vary on;
  gzip_proxied any;
  gzip_comp_level 6;
  gzip_types text/plain text/css text/xml application/json application/javascript image/x-icon;
}
EOF

readarray -t users < <(_get_user_list)
for user in "${users[@]}"; do
    if [[ ! -f /etc/nginx/conf.d/${user}.flood.conf ]]; then
        . /home/${user}/.config/flood/env || { echo_warn "Could not determine flood port for ${user}"; }
        echo_progress_start "Creating flood nginx upstream for $user"
        cat > /etc/nginx/conf.d/${user}.flood.conf << FLUPS
upstream $user.flood {
  server 127.0.0.1:${FLOOD_PORT};
}
FLUPS
    fi
done

sed -i '/ExecStart=/ s/$/ --baseuri=\/flood/' /etc/systemd/system/flood@.service

if [[ -f /install/.subdomain.lock ]]; then
    # shellcheck disable=SC2016
    sed -Ei '
    /^location \/flood \{/,/^\}$/d;
    /^[[:space:]]*auth_basic/d;
    /^[[:space:]]*auth_basic_user_file/d;
    /^[[:space:]]*proxy_pass/ s|\$remote_user\.flood;|$auth_remote_user.flood$request_uri;|;
    /^[[:space:]]*alias/ s|alias[[:space:]]+([^;]+)/;|root $1;|;
    s|^location /flood/api \{|location /flood/api/ {\
    include /etc/nginx/snippets/subauth.conf;\
    auth_request_set $auth_remote_user $upstream_http_x_remote_user;|
    ' /etc/nginx/apps/flood.conf
    sed -Ei '/ExecStart=/ s| ?--baseuri=/flood||g' /etc/systemd/system/flood@.service
fi

systemctl daemon-reload
systemctl try-restart flood@${user}
