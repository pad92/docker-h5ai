#!/command/with-contenv sh

# Set permissions for h5ai cache directories
echo "Setting permissions for h5ai cache directories..."
mkdir -p /usr/share/h5ai/_h5ai/public/cache /usr/share/h5ai/_h5ai/private/cache
chown -R angie:www-data /usr/share/h5ai/_h5ai/public/cache /usr/share/h5ai/_h5ai/private/cache
chmod -R 755 /usr/share/h5ai/_h5ai/public/cache /usr/share/h5ai/_h5ai/private/cache

# Handle basic auth
if [ -n "${ENV_U}" ] && [ -n "${ENV_P}" ]; then
    echo "Configuring basic authentication..."
    /usr/bin/htpasswd -cb /etc/angie/.htpasswd "${ENV_U}" "${ENV_P}" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        sed -i 's/#auth_/auth_/g' /etc/angie/angie.conf
    fi
fi
