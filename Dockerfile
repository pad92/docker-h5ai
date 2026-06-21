ARG H5AI_VERSION=1.2.0

FROM php:8.4-alpine AS builder

ARG H5AI_VERSION
ENV H5AI_VERSION=${H5AI_VERSION}

ARG S6_OVERLAY_VERSION=3.1.6.2
ARG TARGETARCH

RUN case "${TARGETARCH}" in \
    "amd64") S6_ARCH="x86_64" ;; \
    "arm64") S6_ARCH="aarch64" ;; \
    *) S6_ARCH="x86_64" ;; \
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
RUN apk add --no-cache --virtual .build-deps git autoconf g++ make \
    && git clone https://github.com/cataphract/php-rar.git /tmp/php-rar \
    && cd /tmp/php-rar \
    && phpize \
    && ./configure \
    && make -j$(nproc) \
    && make install \
    && apk del .build-deps \
    && rm -rf /tmp/php-rar

FROM docker.angie.software/angie:1.11.7-minimal

ARG H5AI_VERSION
ENV H5AI_VERSION=${H5AI_VERSION}
ENV S6_KEEP_ENV=1
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0
ENV H5AI_ROOT_PATH=/share

RUN apk upgrade --no-cache && apk add --no-cache \
    apache2-utils \
    curl \
    ffmpeg \
    imagemagick \
    imagemagick-raw \
    libraw \
    php84 \
    php84-exif \
    php84-fileinfo \
    php84-fpm \
    php84-gd \
    php84-intl \
    php84-mbstring \
    php84-opcache \
    php84-openssl \
    php84-pecl-imagick \
    php84-session \
    php84-simplexml \
    php84-sqlite3 \
    php84-pdo_sqlite \
    php84-xml \
    php84-xmlwriter \
    php84-zip \
    tzdata \
    zip

COPY --from=builder /h5ai/build/_h5ai /usr/share/h5ai/_h5ai
COPY --from=builder /s6-overlay/ /
COPY --from=builder /usr/local/lib/php/extensions/no-debug-non-zts-20240924/rar.so /usr/lib/php84/modules/rar.so

COPY slash/     /

RUN ln -sf /dev/stderr /var/log/php84/error.log \
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
HEALTHCHECK CMD curl -I --fail http://localhost/ || exit 1
