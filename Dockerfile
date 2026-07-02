FROM php:8.2-fpm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    nginx \
    supervisor \
    libpq-dev \
    postgresql-client

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd \
    && docker-php-ext-install pdo_pgsql

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy application
COPY . /var/www/html

# Copy deploy configurations
COPY deploy/nginx.conf /etc/nginx/sites-available/default
COPY deploy/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy environment file
RUN if [ ! -f .env ]; then cp .env.ci .env; fi

# Install dependencies
RUN composer install --no-interaction --optimize-autoloader --no-dev

# Generate application key
RUN php artisan key:generate --force || true

# Set permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage \
    && chmod -R 755 /var/www/html/bootstrap/cache

# Create startup script
RUN echo '#!/bin/bash\n\
set -e\n\
echo "========================================="\n\
echo "Starting Han-Tech Application"\n\
echo "========================================="\n\
echo "⏳ Waiting for PostgreSQL to be ready..."\n\
max_retries=30\n\
counter=0\n\
until PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USERNAME -d $DB_DATABASE -c "SELECT 1" > /dev/null 2>&1 || [ $counter -eq $max_retries ]; do\n\
    counter=$((counter+1))\n\
    echo "Database not ready - attempt $counter/$max_retries"\n\
    sleep 3\n\
done\n\
if [ $counter -eq $max_retries ]; then\n\
    echo "⚠️  Database connection timed out, continuing anyway..."\n\
else\n\
    echo "✅ Database is ready!"\n\
fi\n\
echo "🔄 Running migrations..."\n\
php artisan migrate --force || echo "⚠️  Migrations failed but continuing..."\n\
echo "🔄 Caching config..."\n\
php artisan config:cache || true\n\
php artisan route:cache || true\n\
php artisan view:cache || true\n\
echo "========================================="\n\
echo "🚀 Starting Supervisord..."\n\
echo "========================================="\n\
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf\n\
' > /startup.sh && chmod +x /startup.sh

# Expose port 80
EXPOSE 80

# Start with startup script
CMD ["/startup.sh"]