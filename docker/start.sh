#!/bin/bash
# ============================================
# HAN-TECH LTD - STARTUP SCRIPT
# ============================================

set -e

cd /var/www/html

echo "========================================="
echo " Han-Tech Ltd - Starting Application"
echo "========================================="

# Check if .env exists, copy from example if not
if [ ! -f .env ]; then
    echo "[INFO] Creating .env from .env.example..."
    cp .env.example .env
fi

# Generate application key if not set
if [ -z "$APP_KEY" ]; then
    echo "[INFO] Generating application key..."
    php artisan key:generate --force --no-interaction
fi

# Create storage link if not exists
if [ ! -L public/storage ]; then
    echo "[INFO] Creating storage symlink..."
    php artisan storage:link --force --no-interaction
fi

# Run database migrations (optional)
if [ "${RUN_MIGRATIONS}" = "true" ]; then
    echo "[INFO] Running database migrations..."
    php artisan migrate --force --no-interaction
fi

# Optimize Laravel
echo "[INFO] Optimizing application..."
php artisan config:cache --no-interaction
php artisan route:cache --no-interaction
php artisan view:cache --no-interaction
php artisan event:cache --no-interaction

# Clear old caches
php artisan optimize:clear --no-interaction 2>/dev/null || true

echo "[INFO] Starting services..."
echo "========================================="

# Start supervisor (manages nginx + php-fpm + queue + scheduler)
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf