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
CONF

cat > /etc/nginx/apps/subdomain.conf << 'CONF'
set $auth_htpasswd \"/etc/htpasswd\";
  location = auth {
    internal;
    proxy_pass http://auth;
    proxy_pass_request_body off;
    proxy_set_header X-Auth-Path $auth_htpasswd;
    proxy_set_header Host $host;
    proxy_set_header Content-Length \"\";
  }

  error_page 401 = @auth_failure;
  location @auth_failure {
    return 301 $scheme://$matched_domain/login/$matched_subdomain$request_uri;
  }

  location ~ ^/panel/login(?<path>.*)$ {
    proxy_pass http://auth$path;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Authorization $http_authorization;
  }

  location = /panel/logout {
    proxy_pass http://auth/logou
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }
CONF

sed -Ei "
s|server_name .*;|server_name $hostname *.$hostname;|g;
/^[[:space:]]*root[[:space:]]+\/srv\/;/,/^[[:space:]]*include/{//!d;};
/^[[:space:]]*root[[:space:]]+\/srv\/;/a\\
  \\
  set \$auth_htpasswd \"/etc/htpasswd\";
  rewrite ^/ \"/\$matched_subdomain\$uri\" break;

" /etc/nginx/sites-enabled/default

install_auth_server
/opt/.venv/subdomain-auth/bin/pip install --upgrade pip wheel >> ${log} 2>&1
/opt/.venv/subdomain-auth/bin/pip install -r /opt/subdomain-auth/requirements.txt >> ${log} 2>&1
systemctl restart subauth -q
