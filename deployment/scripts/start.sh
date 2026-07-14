#!/bin/bash
set -e

# ============================================
# Hanadiz Backend Start Script
# ============================================

echo "🚀 Starting Hanadiz Backend Service"
echo "=================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================
# 1. Validate Environment
# ============================================
echo -e "${BLUE}🔍 1. Validating environment...${NC}"

REQUIRED_VARS=(
    "DATABASE_URL"
    "REDIS_URL"
    "SECRET_KEY"
    "JWT_SECRET_KEY"
)

MISSING_VARS=0
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}❌ $var is not set${NC}"
        MISSING_VARS=1
    fi
done

if [ $MISSING_VARS -eq 1 ]; then
    echo -e "${RED}❌ Missing required environment variables${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Environment validated${NC}"

# ============================================
# 2. Check Database Connection
# ============================================
echo -e "${BLUE}🗄️ 2. Checking database connection...${NC}"

MAX_RETRIES=30
RETRY_COUNT=0
while ! pg_isready -d "$DATABASE_URL" -q 2>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo -e "${RED}❌ Database not ready after $MAX_RETRIES attempts${NC}"
        exit 1
    fi
    echo "Waiting for database (attempt $RETRY_COUNT/$MAX_RETRIES)..."
    sleep 2
done

echo -e "${GREEN}✅ Database is ready${NC}"

# ============================================
# 3. Check Redis Connection
# ============================================
echo -e "${BLUE}🔄 3. Checking Redis connection...${NC}"

if [ -n "$REDIS_URL" ]; then
    if command -v redis-cli &> /dev/null; then
        REDIS_HOST=$(echo $REDIS_URL | sed -E 's|redis://([^:]+):([0-9]+)/?|\1|')
        REDIS_PORT=$(echo $REDIS_URL | sed -E 's|redis://([^:]+):([0-9]+)/?|\2|')
        
        if redis-cli -h $REDIS_HOST -p $REDIS_PORT ping &>/dev/null; then
            echo -e "${GREEN}✅ Redis is ready${NC}"
        else
            echo -e "${YELLOW}⚠️ Redis ping failed, continuing anyway${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ redis-cli not available, skipping Redis check${NC}"
    fi
fi

# ============================================
# 4. Run Pending Migrations
# ============================================
echo -e "${BLUE}🔄 4. Checking for pending migrations...${NC}"

if command -v alembic &> /dev/null; then
    CURRENT_REVISION=$(alembic current 2>/dev/null | grep -o '^[a-f0-9]*' || echo "")
    HEAD_REVISION=$(alembic heads 2>/dev/null | grep -o '^[a-f0-9]*' | head -1)
    
    if [ "$CURRENT_REVISION" != "$HEAD_REVISION" ] && [ -n "$HEAD_REVISION" ]; then
        echo "Running pending migrations..."
        alembic upgrade head
        echo -e "${GREEN}✅ Migrations applied${NC}"
    else
        echo -e "${GREEN}✅ No pending migrations${NC}"
    fi
fi

# ============================================
# 5. Clear Cache
# ============================================
echo -e "${BLUE}🧹 5. Clearing cache...${NC}"

python -c "
import redis
import os
try:
    r = redis.from_url(os.getenv('REDIS_URL'))
    r.flushdb()
    print('Cache cleared')
except Exception as e:
    print(f'Cache clear skipped: {e}')
"

echo -e "${GREEN}✅ Cache cleared${NC}"

# ============================================
# 6. Setup Monitoring
# ============================================
echo -e "${BLUE}📊 6. Setting up monitoring...${NC}"

if [ "$PROMETHEUS_ENABLED" = "true" ]; then
    echo "Prometheus enabled"
    export PROMETHEUS_MULTIPROC_DIR=/app/backend/storage/cache/prometheus
    mkdir -p $PROMETHEUS_MULTIPROC_DIR
fi

echo -e "${GREEN}✅ Monitoring setup complete${NC}"

# ============================================
# 7. Start Application
# ============================================
echo -e "${BLUE}🚀 7. Starting application...${NC}"
echo "========================================"
echo ""

# Set the PORT if not set
export PORT=${PORT:-8000}
export WORKERS=${WORKERS:-4}

# Determine number of workers
if [ "$WORKERS" = "auto" ]; then
    # Auto-detect number of CPU cores
    if [ -f /proc/cpuinfo ]; then
        WORKERS=$(grep -c processor /proc/cpuinfo)
    else
        WORKERS=4
    fi
fi

echo "Starting $WORKERS workers on port $PORT"

# Start with gunicorn
exec gunicorn -w $WORKERS \
    -k uvicorn.workers.UvicornWorker \
    app.main:app \
    --bind 0.0.0.0:$PORT \
    --timeout 60 \
    --graceful-timeout 30 \
    --worker-tmp-dir /dev/shm \
    --access-logfile - \
    --error-logfile - \
    --log-level ${LOG_LEVEL:-info}