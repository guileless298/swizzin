#!/bin/bash

server_name=$(grep -A 2 'listen 80' /etc/nginx/sites-enabled/default | grep -m1 'server_name')
sed -Ei "
/listen 443/,/^}/ s|server_name .*;|$server_name|g;
/root \/srv\/;/,/include/{//!d;};
" /etc/nginx/sites-enabled/default

rm /install/.subdomain.lock

bash /usr/local/bin/swizzin/upgrade/nginx.sh
