#! /bin/bash
# Webmin nginx installer
# flying_sausages for swizzin 2020

MASTER=$(cut -d: -f1 < /root/.master.info)
if [[ ! -f /etc/nginx/apps/webmin.conf ]]; then
    cat > /etc/nginx/apps/webmin.conf << WEBC
location /webmin/ {
    include /etc/nginx/snippets/proxy.conf;

    # Tell nginx that we want to proxy everything here to the local webmin server
    # Last slash is important
    proxy_pass https://127.0.0.1:10000/;
    proxy_redirect https://\$host /webmin;
    proxy_set_header Host \$host:\$server_port;

    auth_basic "What's the password?";
    auth_basic_user_file /etc/htpasswd.d/htpasswd.${MASTER};
}
WEBC
fi

cat >> /etc/webmin/config << EOF
webprefix=/webmin
webprefixnoredir=1
referers=${referers}
EOF

cat >> /etc/webmin/miniserv.conf << EOF
bind=127.0.0.1
sockets=
EOF

if [[ -f /install/.subdomain.lock ]]; then
    # shellcheck disable=SC2016
    sed -Ei '
    /^[[:space:]]*proxy_redirect/d;
    /^[[:space:]]*auth_basic/d;
    /^[[:space:]]*auth_basic_user_file/d;
    /^[[:space:]]*proxy_pass/ s|:10000;|:10000$request_uri;|;
    /^location \/webmin\/ \{/a\
    auth_request /subdomain-auth;
    ' /etc/nginx/apps/webmin.conf
    sed -i 's|/webmin||' /etc/webmin/config
fi

systemctl reload webmin
