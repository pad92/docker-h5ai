ARG H5AI_VERSION=0.30.0-pad92.3

FROM node:20-alpine AS builder

ARG H5AI_VERSION
ENV H5AI_VERSION=${H5AI_VERSION}

RUN apk add --no-cache git patch \
    && git clone https://github.com/pad92/h5ai.git \
    && cd h5ai \
    && git checkout -b ${H5AI_VERSION} tags/v${H5AI_VERSION} \
    && npm install \
    && npm run build

COPY class-setup.php.patch /class-setup.php.patch
RUN patch -p1 -u -d /h5ai/build/_h5ai/private/php/core/ -i /class-setup.php.patch \
    && rm /class-setup.php.patch

FROM nginx:1.26-alpine-slim

ARG H5AI_VERSION
ENV H5AI_VERSION=${H5AI_VERSION}

RUN apk update && apk upgrade --no-cache && apk add --no-cache \
    apache2-utils \
    curl \
    ffmpeg \
    imagemagick \
    php83 \
    php83-exif \
    php83-fileinfo \
    php83-fpm \
    php83-gd \
    php83-intl \
    php83-mbstring \
    php83-opcache \
    php83-openssl \
    php83-pecl-imagick \
    php83-session \
    php83-simplexml \
    php83-xml \
    php83-xmlwriter \
    php83-zip \
    supervisor \
    tzdata \
    zip

COPY --from=builder /h5ai/build/_h5ai /usr/share/h5ai/_h5ai

COPY slash/     /

RUN ln -sf /dev/stderr /var/log/php83/error.log \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && chmod +x /usr/local/bin/nginx_auth.sh /usr/local/bin/init_perms.sh \
    && chown nginx:www-data /usr/share/h5ai/_h5ai/public/cache/ \
    && chown nginx:www-data /usr/share/h5ai/_h5ai/private/cache/

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

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
HEALTHCHECK CMD curl -I --fail http://localhost/ || exit 1
