# syntax=docker/dockerfile:1.7
#
# Afriva API: production PHP-FPM image (Laravel 13, PHP 8.3).
#
# Build context is backend/ and the PHP config files come from the named context "phpconf":
#   docker build \
#     --build-context phpconf=deploy/docker/php \
#     --build-arg APP_UID="$(id -u)" --build-arg APP_GID="$(id -g)" \
#     -f deploy/docker/php/Dockerfile -t afriva-api:<sha> backend
#
# The same image runs three roles (see deploy/docker-compose.prod.yml):
#   app        php-fpm on port 9000 (host Nginx talks FastCGI to 127.0.0.1:9000)
#   worker     php artisan queue:work redis
#   scheduler  php artisan schedule:work

ARG PHP_VERSION=8.3

############################
# Base: PHP + extensions
############################
FROM php:${PHP_VERSION}-fpm-bookworm AS base

# Image library: app/Support/WebpImage.php uses GD (imagewebp) and exif_read_data, so GD is built
# with WebP, JPEG, PNG and FreeType support and the exif extension is enabled. Imagick is not used.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libfcgi-bin \
        libfreetype6 libjpeg62-turbo libpng16-16 libwebp7 \
        libicu72 libzip4; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get install -y --no-install-recommends \
        $PHPIZE_DEPS \
        libfreetype6-dev libjpeg62-turbo-dev libpng-dev libwebp-dev \
        libicu-dev libzip-dev; \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
    docker-php-ext-install -j"$(nproc)" bcmath exif gd intl opcache pcntl pdo_mysql zip; \
    pecl install redis-6.1.0; \
    docker-php-ext-enable redis; \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark > /dev/null; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/* /tmp/pear ~/.pearrc; \
    php -r 'exit((gd_info()["WebP Support"] ?? false) ? 0 : 1);'; \
    php -m | grep -qi '^redis$'; \
    php -m | grep -qi '^exif$'

# Production php.ini plus Afriva overrides, OPcache and the FPM pool.
RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY --from=phpconf php.ini     /usr/local/etc/php/conf.d/zz-afriva.ini
COPY --from=phpconf opcache.ini /usr/local/etc/php/conf.d/zz-opcache.ini
COPY --from=phpconf www.conf    /usr/local/etc/php-fpm.d/zz-afriva.conf
COPY --from=phpconf --chmod=0755 docker-entrypoint.sh /usr/local/bin/afriva-entrypoint
COPY --from=phpconf --chmod=0755 healthcheck.php     /usr/local/bin/afriva-healthcheck

# Non-root runtime user. Match the host deploy user's uid/gid so bind-mounted storage stays writable.
ARG APP_UID=1000
ARG APP_GID=1000
RUN set -eux; \
    groupadd --gid "${APP_GID}" afriva; \
    useradd --uid "${APP_UID}" --gid "${APP_GID}" --home-dir /var/www --no-create-home --shell /usr/sbin/nologin afriva

WORKDIR /var/www/html

############################
# Vendor: composer install (no dev)
############################
FROM base AS vendor

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN set -eux; apt-get update; apt-get install -y --no-install-recommends unzip; rm -rf /var/lib/apt/lists/*

ENV COMPOSER_ALLOW_SUPERUSER=1 COMPOSER_NO_INTERACTION=1
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-progress

COPY . .
RUN set -eux; \
    composer dump-autoload --no-dev --classmap-authoritative --no-scripts; \
    rm -f bootstrap/cache/*.php

############################
# Runtime
############################
FROM base AS runtime

COPY --from=vendor --chown=afriva:afriva /var/www/html /var/www/html

RUN set -eux; \
    # Package discovery normally runs as a composer script; run it here without dev packages.
    php artisan package:discover --ansi; \
    # storage/ is replaced by a bind mount at runtime; keep a skeleton for one-off runs.
    mkdir -p storage/app/public storage/app/private storage/framework/cache/data \
             storage/framework/sessions storage/framework/views storage/logs bootstrap/cache; \
    ln -sfn ../storage/app/public public/storage; \
    chown -R afriva:afriva storage bootstrap/cache; \
    chmod -R ug+rwX storage bootstrap/cache

ARG GIT_SHA=unknown
ENV AFRIVA_GIT_SHA=${GIT_SHA}
LABEL org.opencontainers.image.title="afriva-api" \
      org.opencontainers.image.revision="${GIT_SHA}"

USER afriva
EXPOSE 9000
ENTRYPOINT ["afriva-entrypoint"]
CMD ["php-fpm", "--nodaemonize"]
