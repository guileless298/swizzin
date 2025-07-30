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

cat > /etc/nginx/snippets/subauth.conf << 'CONF'
auth_request auth;
auth_request_set $auth_remote_user $upstream_http_x_remote_user;
auth_request_set $auth_authorization $upstream_http_x_auth;
auth_request_set $auth_key_cookie $upstream_http_x_key_cookie;
auth_request_set $auth_cookie $upstream_http_x_auth_cookie;
auth_request_set $auth_s_cookie $upstream_http_x_sauth_cookie;
auth_request_set $auth_status $upstream_status;
add_header Set-Cookie $auth_key_cookie always;
add_header Set-Cookie $auth_cookie always;
add_header Set-Cookie $auth_s_cookie always;
proxy_set_header Authorization $auth_authorization;
error_page 400 = @auth_failure_400;
error_page 401 = @auth_failure_401;
error_page 403 = @auth_failure_403;
CONF

cat > /etc/nginx/snippets/subauth-failure.sh << 'CONF'
rewrite ^ /login break;
proxy_pass http://127.0.0.1:8333;
proxy_pass_request_body off;
proxy_set_header Host $host;
proxy_set_header Content-Length "";
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

add_header Set-Cookie $auth_key_cookie always;

sub_filter "\"/static/js/httpauth.js" "\"//auth.$matched_domain/login.js";
sub_filter "\"/static/" "\"//$matched_domain/static/";
sub_filter_once off;
CONF

cat > /etc/nginx/apps/subdomain.conf << 'CONF'
set $auth_htpasswd "/etc/htpasswd";

location = auth {
    internal;
    proxy_pass http://auth;
    proxy_pass_request_body off;
    proxy_set_header X-Service $matched_subdomain;
    proxy_set_header X-Service-Auth-Path $auth_htpasswd;
    proxy_set_header X-Primary-Auth-Path "/etc/htpasswd";
    proxy_set_header Host $host;
    proxy_set_header Content-Length "";
    proxy_set_header Cookie $http_cookie;
    proxy_set_header Authorization $http_authorization;
}

location @auth_failure_400 {
    include /etc/nginx/snippets/subauth-failure.sh;
    error_page 502 503 504 = @auth_no_panel_400;
    return 400;
}

location @auth_failure_401 {
    include /etc/nginx/snippets/subauth-failure.sh;
    error_page 502 503 504 = @auth_no_panel_401;
    return 401;
}

location @auth_failure_403 {
    include /etc/nginx/snippets/subauth-failure.sh;
    error_page 502 503 504 = @auth_no_panel_403;
    return 403;
}

location @auth_no_panel_400 {
    add_header WWW-Authenticate 'Basic realm="What\'s the password?"';
    add_header Set-Cookie \$auth_key_cookie always;
    return 400;
}

location @auth_no_panel_401 {
    add_header WWW-Authenticate 'Basic realm="What\'s the password?"';
    add_header Set-Cookie \$auth_key_cookie always;
    return 401;
}

location @auth_no_panel_403 {
    add_header WWW-Authenticate 'Basic realm="What\'s the password?"';
    add_header Set-Cookie \$auth_key_cookie always;
    return 403;
}

location ~ ^/panel/(?<service>[a-z\-]+)$ {
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

mkdir /srv/auth
cat > /srv/auth/login.js << LOGIN
function login() {
var username = document.getElementById("basic-username").value;
var password = document.getElementById("basic-password").value;
fetch('/', {
  method: 'GET',
  credentials: 'include',
  headers: {
    'Authorization': 'Basic ' + btoa(username + ':' + password),
    'Content-Type': 'application/json'
  }
}).then(res => {
  if (res.status == 400) {
    window.alert("Bad Request");
  } else if (res.status == 401) {
    window.alert("Incorrect username or password");
  } else if (res.status == 403) {
    window.alert("Credentials invalid for this service");
  } else if (res.status == 200) {
    window.location.reload();
  } else {
    window.alert("Unknown error");
  }
});
}
document.onkeypress = enter;
function enter(e) {
if (e.which == 13) { login(); }
}
LOGIN

write_auth_server
build_auth_server

systemctl restart subauth -q
