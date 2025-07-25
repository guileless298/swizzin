#!/bin/bash
# navidrome nginx conf
# byte 2021 for Swizzin

#shellcheck source=sources/functions/utils
. /etc/swizzin/sources/functions/utils

user="$(_get_master_username)"
http_port="$(sed -rn 's|Port = "(.*)"|\1|p' "/home/${user}/.config/navidrome/navidrome.toml")" # default port used by navidrome

[[ -f /install/.navidrome.lock ]] && systemctl stop -q navidrome
sed -r 's|Address = (.*)|Address = "127.0.0.1"|g' -i "/home/${user}/.config/navidrome/navidrome.toml"
sed -r 's|BaseUrl = (.*)|BaseUrl = "/navidrome"|g' -i "/home/${user}/.config/navidrome/navidrome.toml"

cat > /etc/nginx/apps/navidrome.conf <<- NGX
	location /navidrome {
	    proxy_pass        http://127.0.0.1:${http_port}/navidrome;
	    proxy_set_header Host \$proxy_host;
	    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	    proxy_set_header X-Forwarded-Proto \$scheme;
	    proxy_redirect off;
	    auth_basic off;
	}
NGX

if [[ -f /install/.subdomain.lock ]]; then
    # shellcheck disable=SC2016
    sed -Ei '
    /^[[:space:]]*auth_basic/d;
    /^[[:space:]]*auth_basic_user_file/d;
    s|^location /navidrome \{|location /navidrome/ {|;
    /^[[:space:]]*proxy_pass/ s|/navidrome;|$request_uri;|
    ' /etc/nginx/apps/navidrome.conf
    sed -r 's|BaseUrl = (.*)|BaseUrl = ""|g' -i "/home/${user}/.config/navidrome/navidrome.toml"
fi

[[ -f /install/.navidrome.lock ]] && systemctl -q start navidrome
