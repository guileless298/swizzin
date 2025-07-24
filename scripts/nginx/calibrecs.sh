#!/usr/bin/env bash

cat > /etc/nginx/apps/calibrecs.conf << EOF
location /calibrecs/ {
    proxy_buffering         off;
    proxy_pass              http://127.0.0.1:8089\$request_uri;
    proxy_set_header X-Forwarded-For \$remote_addr;
#    auth_basic              "What's the password?";
#    auth_basic_user_file    /etc/htpasswd;
}
EOF

sed '/ExecStart=/ s/$/ --listen-on 127.0.0.1 --enable-local-write/' -i /etc/systemd/system/calibrecs.service

systemctl daemon-reload
systemctl try-restart calibrecs
