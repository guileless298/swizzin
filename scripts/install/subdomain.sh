#!/bin/bash

if [[ ! -f /install/.nginx.lock ]]; then
    echo_warn "This package requires nginx to be installed!"
    if ask "Install nginx?" Y; then
        bash /usr/local/bin/swizzin/install/nginx.sh
    else
        exit 1
    fi
fi

touch /install/.subdomain.lock

bash /usr/local/bin/swizzin/upgrade/nginx.sh
