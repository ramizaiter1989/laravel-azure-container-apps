# syntax=docker/dockerfile:1

# ---- 1. PHP dependencies (no dev packages) ----
FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction
COPY . .
RUN composer dump-autoload --optimize --classmap-authoritative --no-dev

# ---- 2. Runtime: FrankenPHP (Caddy + PHP in one binary) ----
FROM dunglas/frankenphp:1-php8.4-alpine AS runtime
WORKDIR /app

RUN install-php-extensions opcache pcntl \
 && cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY --from=vendor --chown=www-data:www-data /app /app

# Stateless container: logs to stdout, no database needed for this API.
ENV SERVER_NAME=":8080" \
    CADDY_GLOBAL_OPTIONS="auto_https off" \
    APP_NAME="Vehicle Quote API" \
    APP_ENV=production \
    APP_DEBUG=false \
    LOG_CHANNEL=stderr \
    SESSION_DRIVER=cookie \
    CACHE_STORE=file \
    DB_CONNECTION=sqlite

RUN rm -f .env && mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views bootstrap/cache \
 && chown -R www-data:www-data storage bootstrap/cache /data/caddy /config/caddy

USER www-data
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s CMD php -r "exit(@file_get_contents('http://127.0.0.1:8080/up') ? 0 : 1);"

# Cache config/routes at start, so env vars from Azure are picked up.
CMD ["sh", "-c", "php artisan config:cache && php artisan route:cache && php artisan view:cache && exec frankenphp run --config /etc/caddy/Caddyfile"]
