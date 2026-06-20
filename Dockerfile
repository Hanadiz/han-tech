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

# Copy Laravel source
COPY backend/ /var/www/html/

# Copy environment file – Render will override values via environment variables
COPY backend/.env.example /var/www/html/.env

# Install PHP dependencies
RUN composer install --no-dev --optimize-autoloader

# Generate app key (can be overridden at runtime)
RUN php artisan key:generate --force

# Set permissions
RUN chown -R www-data:www-data storage bootstrap/cache

# Copy Nginx and Supervisor configuration
COPY deploy/nginx.conf /etc/nginx/nginx.conf
COPY deploy/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]