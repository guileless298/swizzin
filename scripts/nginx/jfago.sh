#!/usr/bin/env bash
#
# Create our nginx application conf for jfa-go
cat > /etc/nginx/apps/jfago.conf <<- NGINXCONF
location ^~ /jfa-go {
    proxy_pass http://localhost:8056/jfa-go;

    http2_push_preload on;

    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-Protocol \$scheme;
    proxy_set_header X-Forwarded-Host \$http_host;
    proxy_buffering off;
}
NGINXCONF

if [[ -f /install/.subdomain.lock ]]; then
    # shellcheck disable=SC2016
    sed -Ei '
    s|^location \^~ /jfa-go \{|location /jfa-go/ {|;
    /^[[:space:]]*proxy_pass/ s|/jfa-go;|$request_uri;|
    ' /etc/nginx/apps/jfago.conf
fi
