FROM php:8.2-fpm-alpine

RUN apk add --no-cache \
    nginx supervisor postgresql-dev \
    libpng-dev libjpeg-turbo-dev freetype-dev \
    zip unzip git curl oniguruma-dev libxml2-dev

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo_pgsql pgsql gd mbstring xml bcmath opcache

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copy composer files first
COPY backend/composer.json /var/www/html/composer.json
COPY backend/composer.lock /var/www/html/composer.lock

# Install dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist --no-progress

# Copy the rest of the backend
COPY backend/ /var/www/html/

# Create .env from .env.example
RUN if [ -f .env.example ]; then cp .env.example .env; else touch .env; fi

# Generate app key
RUN php artisan key:generate --force

# Create storage directories
RUN mkdir -p storage/framework/{cache,testing,sessions,views} storage/logs bootstrap/cache

# Set permissions
RUN chown -R www-data:www-data storage bootstrap/cache

# Copy config files
COPY deploy/nginx.conf /etc/nginx/nginx.conf
COPY deploy/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]