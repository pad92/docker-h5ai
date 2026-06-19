#!/bin/sh

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

# Start PHP-FPM in the background
echo "Starting PHP-FPM..."
/usr/sbin/php-fpm83 --nodaemonize --fpm-config /etc/php83/php-fpm.conf &
FPM_PID=$!

# Start Angie in the background
echo "Starting Angie..."
/usr/sbin/angie -c /etc/angie/angie.conf &
ANGIE_PID=$!

# Trap signals to stop both services gracefully
stop_all() {
    echo "Received termination signal. Stopping services..."
    kill -TERM "$FPM_PID" 2>/dev/null || true
    kill -TERM "$ANGIE_PID" 2>/dev/null || true
    wait "$FPM_PID" 2>/dev/null || true
    wait "$ANGIE_PID" 2>/dev/null || true
    echo "Services stopped."
    exit 0
}

trap stop_all TERM INT

# Monitor processes
while true; do
    if ! kill -0 "$FPM_PID" 2>/dev/null; then
        echo "PHP-FPM process died. Exiting..."
        stop_all
    fi
    if ! kill -0 "$ANGIE_PID" 2>/dev/null; then
        echo "Angie process died. Exiting..."
        stop_all
    fi
    sleep 2
done
