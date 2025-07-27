#!/usr/bin/env bash

cat > /etc/nginx/apps/calibrecs.conf << EOF
location /calibrecs/ {
    proxy_buffering         off;
    proxy_pass              http://127.0.0.1:8089\$request_uri;
    proxy_set_header X-Forwarded-For \$remote_addr;
    auth_basic              "What's the password?";
    auth_basic_user_file    /etc/htpasswd;
}
location /calibrecs {
    # we need a trailing slash for the Application Cache to work
    rewrite                 /calibrecs /calibrecs/ permanent;
}
EOF

sed '/ExecStart=/ s/$/ --listen-on 127.0.0.1 --url-prefix \/calibrecs --enable-local-write/' -i /etc/systemd/system/calibrecs.service

if [[ -f /install/.subdomain.lock ]]; then
    # shellcheck disable=SC2016
    sed -Ei '
    /^location \/calibrecs\/ \{/,/^\}$/d;
    /^[[:space:]]*auth_basic/d;
    /^[[:space:]]*auth_basic_user_file/d;
    /^location \/calibrecs\/ \{/a\
    include /etc/nginx/snippets/subauth.conf;
    ' /etc/nginx/apps/bazarr.conf
    sed -i 's| --url-prefix /calibrecs||' /etc/systemd/system/calibrecs.service
fi

systemctl daemon-reload
systemctl try-restart calibrecs
