FROM php:8.2-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    nginx supervisor postgresql-dev \
    libpng-dev libjpeg-turbo-dev freetype-dev \
    zip unzip git curl oniguruma-dev libxml2-dev

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo_pgsql pgsql gd mbstring xml bcmath opcache

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copy entire backend
COPY backend/ /var/www/html/

# Create .env from .env.example
RUN if [ -f /var/www/html/.env.example ]; then \
        cp /var/www/html/.env.example /var/www/html/.env; \
    else \
        touch /var/www/html/.env; \
    fi

# Install Composer dependencies (with lock file present)
RUN composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist

# Generate app key
RUN php artisan key:generate --force

# Ensure storage directories exist
RUN mkdir -p storage/framework/{cache,testing,sessions,views} storage/logs bootstrap/cache

# Set permissions
RUN chown -R www-data:www-data storage bootstrap/cache

# Copy Nginx and Supervisor configuration
COPY deploy/nginx.conf /etc/nginx/nginx.conf
COPY deploy/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]