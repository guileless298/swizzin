#!/bin/bash

#shellcheck source=sources/functions/subdomain
. /etc/swizzin/sources/functions/subdomain

hostname=$(grep -m1 "server_name" /etc/nginx/sites-enabled/default | awk '{print $2}' | sed 's/;//g')
escaped_hostname=${hostname//./\\.};

cat > /etc/nginx/conf.d/subdomain.conf << CONF
map \$host \$matched_subdomain {
    ~^([^.]+)\\.$escaped_hostname\$ \$1;
    default "panel";
}

map \$host \$matched_domain {
    ~^[^.]+\\.$escaped_hostname\$ "$hostname";
    default \$host;
}

upstream auth {
    server 127.0.0.1:8888;
}

map \$auth_set_cookie \$auth_bypass {
    ""      0;
    default 1;
}
CONF

cat > /etc/nginx/snippets/subauth.conf << CONF
auth_request auth;
auth_request_set \$auth_set_cookie \$upstream_http_set_cookie;
add_header Set-Cookie \$auth_set_cookie;
error_page 401 403 = @auth_failure;
CONF

cat > /etc/nginx/apps/subdomain.conf << 'CONF'
set $auth_htpasswd "/etc/htpasswd";

location = auth {
    internal;
    if ($auth_bypass = 1) {
        add_header Set-Cookie $auth_set_cookie;
        return 200;
    }
    proxy_pass http://auth;
    proxy_pass_request_body off;
    proxy_set_header X-Auth-Path $auth_htpasswd;
    proxy_set_header Host $host;
    proxy_set_header Content-Length "";
    proxy_set_header Authorization $http_authorization;
}

location @auth_failure {
    rewrite ^ /login break;
    proxy_pass http://127.0.0.1:8333;
    proxy_pass_request_body off;
    proxy_set_header Host $host;
    proxy_set_header Content-Length "";
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    error_page 502 503 504 = @auth_no_panel;
}

location @auth_no_panel {
    add_header WWW-Authenticate 'Basic realm="What's the password?"';
    return 401;
}

location @auth_success {
    rewrite ^ $uri$is_args$args last;
}

location ~ ^/panel/(?<service>[a-z]+)$ {
  return 301 $scheme://$service.$matched_domain/;
}
CONF

sed -Ei "
s|server_name .*;|server_name $hostname *.$hostname;|g;
/^[[:space:]]*root[[:space:]]+\/srv\/;/,/^[[:space:]]*include/{//!d;};
/^[[:space:]]*root[[:space:]]+\/srv\/;/a\\
  \\
  set \$auth_htpasswd \"/etc/htpasswd\";\\
  rewrite ^/ \"/\$matched_subdomain\$uri\" break;

" /etc/nginx/sites-enabled/default

write_auth_server
build_auth_server
/opt/.venv/subdomain-auth/bin/pip install --upgrade pip wheel >> ${log} 2>&1
/opt/.venv/subdomain-auth/bin/pip install -r /opt/subdomain-auth/requirements.txt >> ${log} 2>&1
systemctl restart subauth -q
