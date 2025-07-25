#!/bin/bash
# Mylar installer for Swizzin
# Author: Brett
# Copyright (C) 2021 Swizzin

mylar_owner="$(swizdb get mylar/owner)"
port="$(sed -rn 's|http_port = (.*)|\1|p' "/home/${mylar_owner}/.config/mylar/config.ini")"

[[ -f /install/.mylar.lock ]] && systemctl stop -q mylar
sed -r 's|http_host = (.*)|http_host = 127.0.0.1|g' -i "/home/${mylar_owner}/.config/mylar/config.ini"
sed -r 's|http_root = (.*)|http_root = /mylar|g' -i "/home/${mylar_owner}/.config/mylar/config.ini"

cat > /etc/nginx/apps/mylar.conf << EON
location ^~ /mylar {
    include snippets/proxy.conf;
    proxy_pass http://127.0.0.1:${port};

    auth_basic "What's the password?";
    auth_basic_user_file /etc/htpasswd.d/htpasswd.${mylar_owner};
}
EON

if [[ -f /install/.subdomain.lock ]]; then
    # shellcheck disable=SC2016
    sed -Ei "
    /auth_basic/d;
    /auth_basic_user_file/d;
    s| {|/ {|;
    s|:${port};|:${port}\$request_uri;|
    " /etc/nginx/apps/mylar.conf
    sed -r 's|http_root = (.*)|http_root =|g' -i "/home/${mylar_owner}/.config/mylar/config.ini"
fi

[[ -f /install/.mylar.lock ]] && systemctl -q start mylar
