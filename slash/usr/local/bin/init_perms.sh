#!/bin/sh
echo "Setting permissions for h5ai cache directories..."
chown -R nginx:www-data /usr/share/h5ai/_h5ai/public/cache /usr/share/h5ai/_h5ai/private/cache
chmod -R 755 /usr/share/h5ai/_h5ai/public/cache /usr/share/h5ai/_h5ai/private/cache
