#!/bin/bash

hostname=$(grep -m1 "server_name" /etc/nginx/sites-enabled/default | awk '{print $2}' | sed 's/;//g' | sed 's/\./\\./g')

sed -Ei "
/map \$host \$matched_subdomain/,/}/d;
/map \$host \$matched_domain/,/}/d;
1i\\
map \$host \$matched_subdomain {\\
    ~^[0-9]\\\\..+\$ \"panel\";\\
    ~^([^.]+)\\\\..+\$ \$1;\\
    default \"panel\";\\
}\\
\\
map \$host \$matched_domain {\\
    ~^[0-9]\\\\..+\$ \$host;\\
    ~^[^.]+\\\\.(.+)\$ \$1;\\
    default \$host;\\
}\\

s|server_name .*;|server_name $hostname *.$hostname;|g;
/root \/srv\/;/,/include/{//!d;};
/root \/srv\/;/a\\
  \\
  location ~ ^/(?<service>[a-z]+)$ {\\
    return 301 \$scheme://\$service.\$matched_domain/;\\
  }\\
  \\
  location = /subdomain-auth {\\
    internal;\\
    proxy_pass http://127.0.0.1:8888/validate;\\
    proxy_set_header Host \$host;\\
    proxy_pass_request_body off;\\
    proxy_set_header Content-Length \"\";\\
  }\\
  \\
  rewrite ^ \"/\$matched_subdomain\$uri\" break;
" /etc/nginx/sites-enabled/default
