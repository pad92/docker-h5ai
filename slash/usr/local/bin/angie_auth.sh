#!/bin/sh

if [ -n "${ENV_U}" ] && [ -n "${ENV_P}" ]; then
    /usr/bin/htpasswd -cb /etc/angie/.htpasswd "${ENV_U}" "${ENV_P}" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        sed -i 's/#auth_/auth_/g' /etc/angie/angie.conf
    fi
fi

exec /usr/sbin/angie -c /etc/angie/angie.conf
