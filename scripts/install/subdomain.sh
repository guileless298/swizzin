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
    #shellcheck source=sources/functions/pyenv
    . /etc/swizzin/sources/functions/pyenv
    #shellcheck source=sources/functions/subdomain
    . /etc/swizzin/sources/functions/subdomain

    useradd -r subauth -s /usr/sbin/nologin > /dev/null 2>&1

    systempy3_ver=$(get_candidate_version python3)

    if dpkg --compare-versions ${systempy3_ver} lt 3.8.0; then
        PYENV=True
    fi

    case ${PYENV} in
        True)
            pyenv_install
            pyenv_install_version 3.11.3
            pyenv_create_venv 3.11.3 /opt/.venv/subdomain-auth
            chown -R subauth: /opt/.venv/subdomain-auth
            ;;
        *)
            apt_install python3-pip python3-dev python3-venv
            python3_venv subauth subdomain-auth
            ;;
    esac

    echo_progress_start "Installing auth server"
    mkdir /opt/subdomain-auth

    openssl rand -hex 64 > /opt/subdomain-auth/.secret
    chmod 400 /opt/subdomain-auth/.secret

    install_auth_server
    chown -R subauth: /opt/subdomain-auth
    echo_progress_done

    echo_progress_start "Installing python dependencies"
    /opt/.venv/swizzin/bin/pip install --upgrade pip wheel >> ${log} 2>&1
    /opt/.venv/swizzin/bin/pip install -r /opt/swizzin/requirements.txt >> ${log} 2>&1
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

ExecStart=/opt/.venv/subdomain-auth/bin/python auth.py
WorkingDirectory=/opt/subdomain-auth
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
