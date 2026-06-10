#!/bin/sh

if [ -n "${ENV_U}" ] && [ -n "${ENV_P}" ]; then
    /usr/bin/htpasswd -cb /etc/nginx/.htpasswd "${ENV_U}" "${ENV_P}" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        sed -i 's/#auth_/auth_/g' /etc/nginx/nginx.conf
    fi
fi

exec /usr/sbin/nginx -c /etc/nginx/nginx.conf
