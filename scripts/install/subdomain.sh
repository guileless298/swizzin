#!/bin/bash

if [[ ! -f /install/.nginx.lock ]]; then
    echo_warn "This package requires nginx to be installed!"
    if ask "Install nginx?" Y; then
        bash /usr/local/bin/swizzin/install/nginx.sh
    else
        exit 1
    fi
fi

_install() {
    #shellcheck source=sources/functions/rustup
    . /etc/swizzin/sources/functions/rustup
    #shellcheck source=sources/functions/subdomain
    . /etc/swizzin/sources/functions/subdomain

    rustup_install

    echo_progress_start "Installing auth server"
    mkdir -p /opt/subauth/src

    openssl rand -hex 64 > /opt/subauth/.secret
    chmod 400 /opt/subauth/.secret

    useradd -r subauth -s /usr/sbin/nologin > /dev/null 2>&1
    write_auth_server
    build_auth_server
    echo_progress_done

    touch /install/.subdomain.lock
}

_nginx() {
    bash /usr/local/bin/swizzin/upgrade/nginx.sh
}

_systemd() {
    echo_progress_start "Creating and starting service"
    cat > /etc/systemd/system/subauth.service << BAZ
[Unit]
Description=JWT auth service
After=nginx.service

[Service]
Type=simple
User=subauth

ExecStart=/opt/subauth/target/release/subauth
WorkingDirectory=/opt/subauth
Restart=on-failure
TimeoutStopSec=300

[Install]
WantedBy=multi-user.target
BAZ

    systemctl enable -q --now subauth 2>&1 | tee -a $log
    echo_progress_done "Service started"
}

_install
_nginx
_systemd
