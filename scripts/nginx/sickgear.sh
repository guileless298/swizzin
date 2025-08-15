#!/bin/bash
# Nginx configuration for sickgear
# Author: liara
# Copyright (C) 2017 Swizzin
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.
user=$(cut -d: -f1 < /root/.master.info)
isactive=$(systemctl is-active sickgear)
if [[ $isactive == "active" ]]; then
    systemctl stop sickgear
fi

if [[ ! -f /etc/nginx/apps/sickgear.conf ]]; then
    cat > /etc/nginx/apps/sickgear.conf << SGC
location /sickgear {
    include /etc/nginx/snippets/proxy.conf;
    proxy_pass        http://127.0.0.1:8081/sickgear;
    auth_basic "What's the password?";
    auth_basic_user_file /etc/htpasswd.d/htpasswd.${user};
}
SGC
fi
sed -i "s/web_root.*/web_root = \/sickgear/g" /opt/sickgear/config.ini
sed -i "s/web_host.*/web_host = 127.0.0.1/g" /opt/sickgear/config.ini

if [[ -f /install/.subdomain.lock ]]; then
    # shellcheck disable=SC2016
    sed -Ei "
    /^[[:space:]]*auth_basic/d;
    /^[[:space:]]*auth_basic_user_file/d;
    /^[[:space:]]*proxy_pass/ s|/sickgear;|\$request_uri;|;
    s|^location /sickgear \{|location /sickgear/ {\\
    set \$auth_htpasswd \"/etc/htpasswd.d/htpasswd.${user}\";\\
    include /etc/nginx/snippets/subauth.conf;|
    " /etc/nginx/apps/sickgear.conf
    sed -i "s/web_root.*/web_root =/g" /opt/sickgear/config.ini
fi

if [[ $isactive == "active" ]]; then
    systemctl start sickgear
fi
