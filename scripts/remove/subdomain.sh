#!/bin/bash

hostname=$(grep -m1 "server_name" /etc/nginx/sites-enabled/default | awk '{print $2}' | sed 's/;//g')

systemctl disable --now -q subauth
rm -rf /opt/subauth
rm /etc/nginx/conf.d/subdomain.conf
rm /etc/nginx/snippets/subauth.conf
rm /etc/nginx/apps/subdomain.conf

sed -Ei "
s|server_name .*;|server_name $hostname;|g;
/root \/srv\/;/,/include/{//!d;};
" /etc/nginx/sites-enabled/default

echo_progress_start "Relocating fancyindex"
mv /srv/panel/* /srv
rm -rf /srv/panel
echo_progress_done

rm /install/.subdomain.lock

bash /usr/local/bin/swizzin/upgrade/nginx.sh
