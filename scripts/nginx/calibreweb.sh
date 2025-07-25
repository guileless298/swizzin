#!/bin/bash
cat > /etc/nginx/apps/calibreweb.conf << EOF
location /calibreweb {
        proxy_pass              http://127.0.0.1:8083;
        proxy_set_header        Host            \$http_host;
        proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Scheme        \$scheme;
        proxy_set_header        X-Script-Name   /calibreweb;  # IMPORTANT: path has NO trailing slash
}
EOF

sed '/ExecStart=/ s/$/ -i 127.0.0.1/' -i /etc/systemd/system/calibreweb.service

if [[ -f /install/.subdomain.lock ]]; then
    # shellcheck disable=SC2016
    sed -Ei '
    /X-Script-Name/d;
    s| {|/ {|;
    s|:8083;|:8083$request_uri;|
    ' /etc/nginx/apps/bazarr.conf
fi

systemctl daemon-reload
systemctl try-restart calibreweb
