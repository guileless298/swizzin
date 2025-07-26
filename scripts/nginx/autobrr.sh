#!/bin/bash
# autobrr nginx conf
# ludviglundgren 2021 for Swizzin

#shellcheck source=sources/functions/utils
. /etc/swizzin/sources/functions/utils
users=($(_get_user_list))

cat > /etc/nginx/apps/autobrr.conf << 'AUTOBRR'
location /autobrr/ {
    proxy_pass              http://$remote_user.autobrr;
    proxy_http_version      1.1;
    proxy_set_header        X-Forwarded-Host        $http_host;

    auth_basic "What's the password?";
    auth_basic_user_file /etc/htpasswd;

    rewrite ^/autobrr/(.*) /$1 break;
}
AUTOBRR

for user in ${users[@]}; do
    port=$(grep 'port =' /home/${user}/.config/autobrr/config.toml | awk '{ print $3 }')
    cat > /etc/nginx/conf.d/${user}.autobrr.conf << AUTOBRRUC
upstream ${user}.autobrr {
  server 127.0.0.1:${port};
}
AUTOBRRUC

    # change listening addr to 127.0.0.1
    sed -i 's|host = "0.0.0.0"|host = "127.0.0.1"|g' "/home/${user}/.config/autobrr/config.toml"

    # Restart autobrr for all user after changing port
    echo_log_only "Restarting autobrr for ${user}"
    systemctl try-restart autobrr@${user}

done

if [[ -f /install/.subdomain.lock ]]; then
    # shellcheck disable=SC2016
    sed -Ei '
    /^[[:space:]]*auth_basic/d;
    /^[[:space:]]*auth_basic_user_file/d;
    /^[[:space:]]*rewrite/d;
    /^[[:space:]]*proxy_pass/ s|$remote_user.autobrr;|$upstream_http_x_remote_user.autobrr$request_uri;|;
    /^location \/autobrr\/ \{/a\
    auth_request @auth;
    ' /etc/nginx/apps/autobrr.conf
fi
