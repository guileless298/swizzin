#!/bin/bash

# shellcheck disable=SC2016
sed -Ei '
/listen 443/,/^}/ s|server_name .*;|server_name ~^(?:(?<matched_subdomain>[^.]*)\.)?(?<matched_domain>.+)$;|g;
/map $matched_subdomain $matched_domain {/,/}/d
/root \/srv\/;/,/include/{//!d;};
/root \/srv\/;/a\
  \
  location ~ ^/(?<service>[a-z]+)$ {\
    return 301 $scheme://$service.$matched_domain$request_uri;\
  }\
  \
  rewrite ^ "/$subdomain$uri" break;
' /etc/nginx/sites-enabled/default

cat >> /etc/nginx/sites-enabled/default << 'EOF'

map $matched_subdomain $subdomain {
    default $matched_subdomain;
    ""      panel;
}
EOF
