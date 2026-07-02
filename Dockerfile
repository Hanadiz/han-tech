FROM php:8.2-fpm-alpine

RUN apk add --no-cache \
    nginx supervisor postgresql-dev \
    libpng-dev libjpeg-turbo-dev freetype-dev \
    zip unzip git curl oniguruma-dev libxml2-dev

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo_pgsql pgsql gd mbstring xml bcmath opcache

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copy composer files first for layer caching
COPY backend/composer.json /var/www/html/composer.json
COPY backend/composer.lock /var/www/html/composer.lock

# Install from lock file (NEVER updates)
RUN composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist --no-progress

# Copy the remaining backend code
COPY backend/ /var/www/html/

# Create .env file
RUN if [ -f /var/www/html/.env.example ]; then \
        cp /var/www/html/.env.example /var/www/html/.env; \
    else \
        touch /var/www/html/.env; \
    fi

RUN php artisan key:generate --force
RUN mkdir -p storage/framework/{cache,testing,sessions,views} storage/logs bootstrap/cache
RUN chown -R www-data:www-data storage bootstrap/cache

COPY deploy/nginx.conf /etc/nginx/nginx.conf
COPY deploy/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]