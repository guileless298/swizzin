#!/bin/bash

#shellcheck source=sources/functions/subdomain
. /etc/swizzin/sources/functions/subdomain

hostname=$(grep -m1 "server_name" /etc/nginx/sites-enabled/default | awk '{print $2}' | sed 's/;//g')
escaped_hostname=${hostname//./\\\\.};

sed -Ei "
/^map \$host \$matched_subdomain/,/}/d;
/^map \$host \$matched_domain/,/}/d;
1i\\
map \$host \$matched_subdomain {\\
    ~^([^.]+)\\\\.$escaped_hostname\$ \$1;\\
    default \"panel\";\\
}\\
\\
map \$host \$matched_domain {\\
    ~^[^.]+\\\\.$escaped_hostname\$ \"$hostname\";\\
    default \$host;\\
}\\
\\
upstream auth {\\
    server 127.0.0.1:8888;\\
}\\

s|server_name .*;|server_name $hostname *.$hostname;|g;
/^[[:space:]]*root[[:space:]]+\/srv\/;/,/^[[:space:]]*include/{//!d;};
/^[[:space:]]*root[[:space:]]+\/srv\/;/a\\
  \\
  location @auth {\\
    internal;\\
    proxy_pass http://auth;\\
    proxy_pass_request_body off;\\
    proxy_set_header X-Auth-Path \$auth_htpasswd;\\
    proxy_set_header Host \$host;\\
    proxy_set_header Content-Length \"\";\\
  }\\
  \\
  error_page 401 = @auth_failure;\\
  location @auth_failure {\\
    return 302 \$scheme://\$matched_domain/login/\$matched_subdomain/\$request_uri;\\
  }\\
  \\
  rewrite ^ \"/\$matched_subdomain\$uri\" break;\\
  location ^~ /panel/login {\\
    proxy_pass http://auth/;\\
    proxy_set_header Host \$host;\\
    proxy_set_header X-Real-IP \$remote_addr;\\
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\\
    proxy_set_header Authorization \$http_authorization;\\
  }\\

" /etc/nginx/sites-enabled/default

install_auth_server
systemctl restart subauth -q
