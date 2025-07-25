#!/bin/bash

set -x

server_name=$(grep -m1 "server_name" /etc/nginx/sites-enabled/default)
sed -Ei "
/listen 443/,/^}/ s|server_name .*;|$server_name|g;
/root \/srv\/;/,/include/{//!d;}
" /etc/nginx/sites-enabled/default

rm /install/.subdomain.lock

bash /usr/local/bin/swizzin/upgrade/nginx.sh
