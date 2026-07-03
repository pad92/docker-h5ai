#!/command/with-contenv sh
set -e

# Remap the runtime account "angie" to the host-provided PUID/PGID so the
# services can read bind-mounted shares owned by that uid/gid. Both php-fpm
# (directory indexing) and Angie workers (direct file downloads) run as
# "angie", so remapping the account covers the whole request path.
# -o allows non-unique ids (e.g. PGID=100 already used by the "users" group).
if [ -n "${PGID}" ] && [ "${PGID}" != "$(id -g angie)" ]; then
    echo "Remapping group 'angie' -> GID ${PGID}"
    groupmod -o -g "${PGID}" angie
fi
if [ -n "${PUID}" ] && [ "${PUID}" != "$(id -u angie)" ]; then
    echo "Remapping user 'angie' -> UID ${PUID}"
    usermod -o -u "${PUID}" angie
fi

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

# Handle basic auth. If the operator asked for auth (ENV_U/ENV_P set), a
# failure to generate the htpasswd file must abort startup: continuing would
# silently serve the share without the requested protection (fail closed).
if [ -n "${ENV_U}" ] && [ -n "${ENV_P}" ]; then
    echo "Configuring basic authentication..."
    if ! HTPASSWD_OUT=$(/usr/bin/htpasswd -cb /etc/angie/.htpasswd "${ENV_U}" "${ENV_P}" 2>&1); then
        echo "ERROR: htpasswd failed, refusing to start without the requested basic auth: ${HTPASSWD_OUT}" >&2
        exit 1
    fi
    sed -i 's/#auth_/auth_/g' /etc/angie/angie.conf
fi

# Handle h5ai admin password
OPTIONS_JSON=/usr/share/h5ai/_h5ai/private/conf/options.json
H5AI_ADMIN_PASSHASH=""

# [ -w ] is unreliable here: as root it reports read-only mounts as writable
# (EROFS is ignored). Probe by opening the file for append, which does not
# modify it but fails on a read-only mount.
options_json_writable() {
    ( : >> "${OPTIONS_JSON}" ) 2>/dev/null
}

if [ -n "${H5AI_ADMIN_PASSWORD}" ]; then
    echo "Configuring h5ai admin password..."
    H5AI_ADMIN_PASSHASH=$(echo -n "${H5AI_ADMIN_PASSWORD}" | sha512sum | cut -d' ' -f1)
elif [ -f "${OPTIONS_JSON}" ] && ! options_json_writable; then
    # Read-only custom mount: the operator manages the passhash themselves.
    echo "H5AI_ADMIN_PASSWORD not set and ${OPTIONS_JSON} is read-only: keeping the existing passhash"
else
    echo "H5AI_ADMIN_PASSWORD not set. Generating a random password..."
    RANDOM_PASS=$(php84 -r 'echo bin2hex(random_bytes(16));')
    echo "--------------------------------------------------------"
    echo "Generated random h5ai administration password: ${RANDOM_PASS}"
    echo "--------------------------------------------------------"
    H5AI_ADMIN_PASSHASH=$(echo -n "${RANDOM_PASS}" | sha512sum | cut -d' ' -f1)
fi

if [ -n "${H5AI_ADMIN_PASSHASH}" ] && [ -f "${OPTIONS_JSON}" ]; then
    if ! options_json_writable; then
        echo "ERROR: H5AI_ADMIN_PASSWORD is set but ${OPTIONS_JSON} is not writable (read-only mount?)" >&2
        exit 1
    fi
    # Rewrite through a temp file + cat instead of sed -i: sed -i renames a
    # temp file over the target, which fails with EBUSY when options.json is
    # a single-file bind mount.
    TMP_OPTIONS=$(mktemp)
    sed -E 's/"passhash":[[:space:]]*"[^"]*"/"passhash": "'"${H5AI_ADMIN_PASSHASH}"'"/g' "${OPTIONS_JSON}" > "${TMP_OPTIONS}"
    cat "${TMP_OPTIONS}" > "${OPTIONS_JSON}"
    rm -f "${TMP_OPTIONS}"
fi
