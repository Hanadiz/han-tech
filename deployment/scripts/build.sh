#!/bin/bash
set -e

# ============================================
# Hanadiz Backend Build Script
# ============================================

echo "🚀 Starting Hanadiz Backend Build Process"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================
# 1. Environment Setup
# ============================================
echo -e "${BLUE}📋 1. Setting up environment...${NC}"

# Detect environment from RENDER_ENVIRONMENT or default to production
if [ -z "$RENDER_ENVIRONMENT" ]; then
    ENVIRONMENT="production"
else
    ENVIRONMENT="$RENDER_ENVIRONMENT"
fi

echo "Environment: $ENVIRONMENT"

# Load environment specific variables
if [ -f ".env.$ENVIRONMENT" ]; then
    echo "Loading .env.$ENVIRONMENT"
    export $(cat .env.$ENVIRONMENT | grep -v '^#' | xargs)
else
    echo "⚠️ .env.$ENVIRONMENT not found, using defaults"
fi

# ============================================
# 2. System Dependencies
# ============================================
echo -e "${BLUE}📦 2. Installing system dependencies...${NC}"

# Update package list
apt-get update -qq

# Install required packages
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    gcc \
    g++ \
    make \
    libpq-dev \
    libssl-dev \
    libffi-dev \
    curl \
    wget \
    git \
    unzip \
    && rm -rf /var/lib/apt/lists/*

echo -e "${GREEN}✅ System dependencies installed${NC}"

# ============================================
# 3. Python Setup
# ============================================
echo -e "${BLUE}🐍 3. Setting up Python environment...${NC}"

# Upgrade pip
pip install --upgrade pip -q
pip install wheel -q

# Install production dependencies
echo "Installing production dependencies..."
pip install -r requirements/production.txt -q --no-cache-dir

if [ "$ENVIRONMENT" = "development" ] || [ "$ENVIRONMENT" = "staging" ]; then
    echo "Installing development dependencies..."
    pip install -r requirements/dev.txt -q --no-cache-dir
fi

echo -e "${GREEN}✅ Python dependencies installed${NC}"

# ============================================
# 4. Database Migrations
# ============================================
echo -e "${BLUE}🗄️ 4. Running database migrations...${NC}"

# Check if DATABASE_URL is set
if [ -n "$DATABASE_URL" ]; then
    echo "Running migrations..."
    
    # Wait for database to be ready
    echo "Waiting for database to be ready..."
    MAX_RETRIES=30
    RETRY_COUNT=0
    while ! pg_isready -d "$DATABASE_URL" -q; do
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
            echo "❌ Database not ready after $MAX_RETRIES attempts"
            exit 1
        fi
        sleep 2
    done
    
    # Run migrations
    echo "Running Alembic migrations..."
    alembic upgrade head
    
    # Seed data if needed
    if [ "$ENVIRONMENT" = "staging" ] || [ "$ENVIRONMENT" = "development" ]; then
        echo "Seeding database with test data..."
        python scripts/seed_database.py
    fi
    
    echo -e "${GREEN}✅ Database migrations completed${NC}"
else
    echo -e "${YELLOW}⚠️ DATABASE_URL not set, skipping migrations${NC}"
fi

# ============================================
# 5. Static Files
# ============================================
echo -e "${BLUE}📁 5. Preparing static files...${NC}"

# Create required directories
mkdir -p /app/backend/storage/logs
mkdir -p /app/backend/storage/backups
mkdir -p /app/backend/storage/cache
mkdir -p /app/backend/storage/uploads
mkdir -p /app/backend/storage/certificates
mkdir -p /app/backend/storage/invoices
mkdir -p /app/backend/storage/reports

# Set proper permissions
chmod -R 755 /app/backend/storage

echo -e "${GREEN}✅ Static files prepared${NC}"

# ============================================
# 6. Health Check Script
# ============================================
echo -e "${BLUE}🔍 6. Generating health check script...${NC}"

cat > /app/backend/healthcheck.py << 'EOF'
#!/usr/bin/env python3
import sys
import requests
import os

try:
    response = requests.get(
        f"http://localhost:{os.getenv('PORT', 8000)}/health",
        timeout=5
    )
    if response.status_code == 200:
        sys.exit(0)
    else:
        sys.exit(1)
except Exception:
    sys.exit(1)
EOF

chmod +x /app/backend/healthcheck.py

echo -e "${GREEN}✅ Health check script created${NC}"

# ============================================
# 7. Clear Cache
# ============================================
echo -e "${BLUE}🧹 7. Clearing cache...${NC}"

find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete 2>/dev/null || true
rm -rf .pytest_cache .coverage htmlcov 2>/dev/null || true

echo -e "${GREEN}✅ Cache cleared${NC}"

# ============================================
# 8. Security Checks
# ============================================
echo -e "${BLUE}🔒 8. Running security checks...${NC}"

if command -v bandit &> /dev/null; then
    echo "Running bandit security scan..."
    bandit -r app/ -ll -f json -o bandit-report.json || true
    if [ -f bandit-report.json ]; then
        HIGH_COUNT=$(grep -o '"high": [0-9]*' bandit-report.json | awk '{print $2}')
        if [ "$HIGH_COUNT" -gt 0 ]; then
            echo -e "${YELLOW}⚠️ Found $HIGH_COUNT high-severity issues${NC}"
        else
            echo -e "${GREEN}✅ No high-severity issues found${NC}"
        fi
    fi
fi

echo -e "${GREEN}✅ Security checks completed${NC}"

# ============================================
# 9. Build Summary
# ============================================
echo ""
echo -e "${GREEN}🎉 Build completed successfully!${NC}"
echo "========================================"
echo ""
echo "📊 Build Summary:"
echo "  - Environment: $ENVIRONMENT"
echo "  - Python: $(python --version)"
echo "  - Pip: $(pip --version)"
echo "  - Alembic: $(alembic --version 2>/dev/null || echo 'Not installed')"
echo ""
echo "🚀 Ready for deployment!"