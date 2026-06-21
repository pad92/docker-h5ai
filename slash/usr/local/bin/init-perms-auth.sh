#!/command/with-contenv sh
set -e

# Set permissions for h5ai cache directories
echo "Setting permissions for h5ai cache directories..."
mkdir -p /usr/share/h5ai/_h5ai/public/cache /usr/share/h5ai/_h5ai/private/cache
find /usr/share/h5ai/_h5ai/public/cache /usr/share/h5ai/_h5ai/private/cache \
    \( ! -user angie -o ! -group angie \) -exec chown angie:angie {} +
find /usr/share/h5ai/_h5ai/public/cache /usr/share/h5ai/_h5ai/private/cache \
    ! -perm 755 -exec chmod 755 {} +

# Handle basic auth
if [ -n "${ENV_U}" ] && [ -n "${ENV_P}" ]; then
    echo "Configuring basic authentication..."
    /usr/bin/htpasswd -cb /etc/angie/.htpasswd "${ENV_U}" "${ENV_P}" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
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
