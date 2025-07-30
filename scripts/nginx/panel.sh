#!/bin/bash
# QuickBox dashboard installer for Swizzin
# Author: liara
# Copyright (C) 2017 Swizzin
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.
#

echo "HOST = '127.0.0.1'" >> /opt/swizzin/swizzin.cfg

cat > /etc/nginx/apps/panel.conf << 'EON'
location / {
  #rewrite ^/panel/(.*) /$1 break;
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Host $host;
  proxy_set_header X-Forwarded-Proto $scheme;
  proxy_set_header Origin "";
  proxy_pass http://127.0.0.1:8333;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "Upgrade";
}
EON

if [[ -f /install/.subdomain.lock ]]; then
    # shellcheck disable=SC2016
    sed -Ei '
    s|^location / \{|location /panel/ {\
  include /etc/nginx/snippets/subauth.conf;|;
    /^[[:space:]]*proxy_pass/ s|:8333;|:8333$request_uri;|;
    ' /etc/nginx/apps/panel.conf

    sed -E '/^[[:space:]]*include \/etc\/nginx\/snippets\/subauth\.conf;$/d' /etc/nginx/apps/panel.conf > /etc/nginx/apps/.panel.conf

    sed -E '
    s|^location /panel/ \{|location = /panel/login {|;
    1i\

    ' /etc/nginx/apps/.panel.conf >> /etc/nginx/apps/panel.conf
    sed -E '
    s|^location /panel/ \{|location /panel/static/ {|;
    1i\

    ' /etc/nginx/apps/.panel.conf >> /etc/nginx/apps/panel.conf
    rm /etc/nginx/apps/.panel.conf
fi
