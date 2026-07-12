ARG H5AI_VERSION=1.2.6

FROM php:8.4-alpine AS builder

ARG H5AI_VERSION
ENV H5AI_VERSION=${H5AI_VERSION}

ARG S6_OVERLAY_VERSION=3.2.3.0
ARG TARGETARCH

RUN case "${TARGETARCH}" in \
    "amd64") S6_ARCH="x86_64" ;; \
    "arm64") S6_ARCH="aarch64" ;; \
    *) echo "Unsupported TARGETARCH: '${TARGETARCH}'" >&2; exit 1 ;; \
    esac \
    && apk add --no-cache curl patch unzip xz \
    && curl -L -o /tmp/h5ai.zip "https://gitlab.com/api/v4/projects/83496424/packages/generic/h5ai/${H5AI_VERSION}/h5ai-${H5AI_VERSION}.zip" \
    && mkdir -p /h5ai/build/_h5ai \
    && unzip /tmp/h5ai.zip -d /h5ai/build/_h5ai \
    && rm /tmp/h5ai.zip \
    && curl -L -o /tmp/s6-overlay-noarch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
    && curl -L -o /tmp/s6-overlay-arch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" \
    && mkdir -p /s6-overlay \
    && tar -C /s6-overlay -Jxpf /tmp/s6-overlay-noarch.tar.xz \
    && tar -C /s6-overlay -Jxpf /tmp/s6-overlay-arch.tar.xz \
    && rm -f /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-arch.tar.xz

COPY class-setup.php.patch /class-setup.php.patch
RUN patch -p1 -u -d /h5ai/build/_h5ai/private/php/core/ -i /class-setup.php.patch \
    && rm /class-setup.php.patch

# Build php-rar extension from git source because PECL 4.2.0 is incompatible with PHP 8.4 zend_resolve_path API
ARG PHP_RAR_COMMIT=9c8fcd9ebc9feaf36f945d6d7407fdcd57b7136f
RUN apk add --no-cache --virtual .build-deps git autoconf g++ make \
    && git clone https://github.com/cataphract/php-rar.git /tmp/php-rar \
    && cd /tmp/php-rar \
    && git checkout ${PHP_RAR_COMMIT} \
    && phpize \
    && ./configure \
    && make -j$(nproc) \
    && make install \
    && cp $(php-config --extension-dir)/rar.so /tmp/rar.so \
    && apk del .build-deps \
    && rm -rf /tmp/php-rar

FROM docker.angie.software/angie:1.11.8-minimal

ARG H5AI_VERSION
ENV H5AI_VERSION=${H5AI_VERSION}
ENV S6_KEEP_ENV=1
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=30000
ENV H5AI_ROOT_PATH=/share

# Only extensions actually used by the h5ai PHP code are installed:
# exif/gd/imagick (thumbnails), fileinfo (download mimetypes), mbstring,
# session, sqlite3 (CacheDB uses the SQLite3 class, not PDO), zip
# (ZipArchive) plus the tar/zip CLIs for packaged downloads.
# angie-console-light ships with the base image but nothing serves it.
RUN apk upgrade --no-cache && apk add --no-cache \
    apache2-utils \
    ffmpeg \
    imagemagick \
    imagemagick-raw \
    libraw \
    php84 \
    php84-exif \
    php84-fileinfo \
    php84-fpm \
    php84-gd \
    php84-mbstring \
    php84-opcache \
    php84-openssl \
    php84-pecl-imagick \
    php84-session \
    php84-sqlite3 \
    php84-zip \
    shadow \
    tzdata \
    zip \
    && apk del angie-console-light

COPY --from=builder /h5ai/build/_h5ai /usr/share/h5ai/_h5ai
COPY --from=builder /s6-overlay/ /
COPY --from=builder /tmp/rar.so /usr/lib/php84/modules/rar.so

COPY slash/     /

RUN ln -sf "$(command -v php84)" /usr/bin/php \
    && mkdir -p /etc/angie/conf.d \
    && ln -sf /dev/stderr /var/log/php84/error.log \
    && ln -sf /dev/stdout /var/log/angie/access.log \
    && ln -sf /dev/stderr /var/log/angie/error.log \
    && chmod +x /etc/s6-overlay/s6-rc.d/init-perms-auth/up \
    && chmod +x /etc/s6-overlay/s6-rc.d/php-fpm84/run \
    && chmod +x /etc/s6-overlay/s6-rc.d/angie/run \
    && chmod +x /usr/local/bin/init-perms-auth.sh \
    && echo "extension=rar.so" > /etc/php84/conf.d/50_rar.ini

ARG BUILD_DATE
ARG BUILD_VCSREF

LABEL maintainer="pad92" \
    org.label-schema.url="https://github.com/pad92/docker-h5ai/blob/main/README.md" \
    org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.version=$H5AI_VERSION \
    org.label-schema.vcs-url="https://github.com/pad92/docker-h5ai.git" \
    org.label-schema.vcs-ref=$BUILD_VCSREF \
    org.label-schema.docker.dockerfile="/Dockerfile" \
    org.label-schema.description="h5ai on alpine docker image" \
    org.label-schema.schema-version="1.0"

EXPOSE 80

ENTRYPOINT ["/init"]
# Accept 200 (open) and 401 (basic auth enabled) as healthy; fail only if
# Angie is unreachable. Uses busybox wget so the image does not need curl.
# 127.0.0.1 instead of localhost: busybox wget prefers ::1 while Angie
# listens on IPv4 only.
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD wget -S -T 5 -O /dev/null http://127.0.0.1/ 2>&1 \
    | grep -qE 'HTTP/1\.[01] (200|401)' || exit 1
