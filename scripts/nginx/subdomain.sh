#!/bin/bash

hostname=$(grep -m1 "server_name" /etc/nginx/sites-enabled/default | awk '{print $2}' | sed 's/;//g' | sed 's/\./\\./g')

sed -Ei "
/map \$host \$matched_subdomain/,/}/d;
/map \$host \$matched_domain/,/}/d;
1i\\
map \$host \$matched_subdomain {\\
    ~^[0-9]\..+$ \"panel\";\\
    ~^(?<matched_subdomain>[^.]+)\..+$ \$matched_subdomain;\\
    default \"panel\";\\
}\\
\\
map \$host \$matched_domain {\\
    ~^[0-9]\..+$ \$host;\\
    ~^[^.]+\.(?<matched_domain>.+)$ \$matched_domain;\\
    default \$host;\\
}
s|server_name .*;|server_name $hostname *.$hostname;|g;
/root \/srv\/;/,/include/{//!d;};
/root \/srv\/;/a\\
  \\
  location ~ ^/(?<service>[a-z]+)$ {\\
    return 301 \$scheme://\$service.\$matched_domain\$request_uri;\\
  }\\
  \\
  rewrite ^ \"/\$matched_subdomain\$uri\" break;
" /etc/nginx/sites-enabled/default
