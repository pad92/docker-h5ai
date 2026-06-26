#!/command/with-contenv sh
set -e

# Set permissions for h5ai cache directories
echo "Setting permissions for h5ai cache directories..."
mkdir -p /usr/share/h5ai/_h5ai/public/cache /usr/share/h5ai/_h5ai/private/cache
find /usr/share/h5ai/_h5ai/public/cache /usr/share/h5ai/_h5ai/private/cache \
    \( ! -user angie -o ! -group angie \) -exec chown angie:angie {} +
find /usr/share/h5ai/_h5ai/public/cache /usr/share/h5ai/_h5ai/private/cache \
    -type d ! -perm 755 -exec chmod 755 {} +
find /usr/share/h5ai/_h5ai/public/cache /usr/share/h5ai/_h5ai/private/cache \
    -type f ! -perm 644 -exec chmod 644 {} +

# Configure trusted proxies for real client IP (X-Forwarded-For)
REALIP_CONF=/etc/angie/conf.d/real_ip.conf
if [ -n "${REAL_IP_FROM}" ]; then
    echo "Configuring trusted proxies (real_ip): ${REAL_IP_FROM}"
    : > "${REALIP_CONF}"
    # REAL_IP_FROM accepts a comma- or space-separated list of CIDRs/IPs
    echo "${REAL_IP_FROM}" | tr ',' ' ' | xargs -n1 | while read -r cidr; do
        [ -n "${cidr}" ] && echo "set_real_ip_from ${cidr};" >> "${REALIP_CONF}"
    done
    echo "real_ip_header ${REAL_IP_HEADER:-X-Forwarded-For};" >> "${REALIP_CONF}"
    echo "real_ip_recursive on;" >> "${REALIP_CONF}"
else
    rm -f "${REALIP_CONF}"
fi

# Handle basic auth
if [ -n "${ENV_U}" ] && [ -n "${ENV_P}" ]; then
    echo "Configuring basic authentication..."
    if /usr/bin/htpasswd -cb /etc/angie/.htpasswd "${ENV_U}" "${ENV_P}" >/dev/null 2>&1; then
        sed -i 's/#auth_/auth_/g' /etc/angie/angie.conf
    fi
fi

# Handle h5ai admin password
if [ -n "${H5AI_ADMIN_PASSWORD}" ]; then
    echo "Configuring h5ai admin password..."
    H5AI_ADMIN_PASSHASH=$(echo -n "${H5AI_ADMIN_PASSWORD}" | sha512sum | cut -d' ' -f1)
else
    echo "H5AI_ADMIN_PASSWORD not set. Generating a random password..."
    RANDOM_PASS=$(php84 -r 'echo bin2hex(random_bytes(16));')
    echo "--------------------------------------------------------"
    echo "Generated random h5ai administration password: ${RANDOM_PASS}"
    echo "--------------------------------------------------------"
    H5AI_ADMIN_PASSHASH=$(echo -n "${RANDOM_PASS}" | sha512sum | cut -d' ' -f1)
fi

if [ -f /usr/share/h5ai/_h5ai/private/conf/options.json ]; then
    sed -i -E 's/"passhash":[[:space:]]*"[^"]*"/"passhash": "'"${H5AI_ADMIN_PASSHASH}"'"/g' /usr/share/h5ai/_h5ai/private/conf/options.json
fi
