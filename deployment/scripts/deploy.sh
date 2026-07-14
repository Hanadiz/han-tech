#!/bin/bash
set -e

# ============================================
# Hanadiz Deployment Script
# ============================================

echo "🚀 Hanadiz Deployment Script"
echo "============================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================
# 1. Load Configuration
# ============================================
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

cd $PROJECT_ROOT

# Load environment
if [ -f ".env.deployment" ]; then
    export $(cat .env.deployment | grep -v '^#' | xargs)
fi

# ============================================
# 2. Validate Environment
# ============================================
echo -e "${BLUE}🔍 1. Validating deployment environment...${NC}"

REQUIRED_ENV_VARS=(
    "RENDER_API_KEY"
    "BACKEND_SERVICE_ID"
    "WORKER_SERVICE_ID"
    "BEAT_SERVICE_ID"
    "FLOWER_SERVICE_ID"
)

MISSING_VARS=0
for var in "${REQUIRED_ENV_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}❌ $var is not set${NC}"
        MISSING_VARS=1
    fi
done

if [ $MISSING_VARS -eq 1 ]; then
    echo -e "${RED}❌ Please set all required environment variables${NC}"
    echo ""
    echo "Required variables:"
    printf "  - %s\n" "${REQUIRED_ENV_VARS[@]}"
    exit 1
fi

echo -e "${GREEN}✅ Environment validated${NC}"

# ============================================
# 3. Check Git Status
# ============================================
echo -e "${BLUE}📝 2. Checking Git status...${NC}"

if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}⚠️ You have uncommitted changes${NC}"
    echo "Do you want to continue? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Deployment cancelled"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Git status OK${NC}"

# ============================================
# 4. Run Tests
# ============================================
echo -e "${BLUE}🧪 3. Running tests...${NC}"

if [ -d "backend/tests" ]; then
    cd backend
    
    echo "Installing test dependencies..."
    pip install -q pytest pytest-cov httpx
    
    echo "Running tests..."
    pytest tests/ -v --cov=app --cov-report=xml --cov-report=term || {
        echo -e "${RED}❌ Tests failed${NC}"
        echo "Do you want to continue anyway? (y/n)"
        read -r response
        if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo "Deployment cancelled"
            exit 1
        fi
    }
    
    cd $PROJECT_ROOT
    echo -e "${GREEN}✅ Tests passed${NC}"
else
    echo -e "${YELLOW}⚠️ No tests found, skipping${NC}"
fi

# ============================================
# 5. Build Docker Images
# ============================================
echo -e "${BLUE}🐳 4. Building Docker images...${NC}"

# Build backend image
echo "Building backend image..."
docker build -t hanadiz-backend:latest -f backend/Dockerfile backend/

# Build worker image
echo "Building worker image..."
docker build -t hanadiz-worker:latest -f backend/Dockerfile.worker backend/

echo -e "${GREEN}✅ Docker images built${NC}"

# ============================================
# 6. Deploy to Render
# ============================================
echo -e "${BLUE}🚀 5. Deploying to Render...${NC}"

# Check if render CLI is available
if ! command -v render &> /dev/null; then
    echo -e "${YELLOW}⚠️ render CLI not found, installing...${NC}"
    curl -fsSL https://render.com/install.sh | sh
    sudo mv render /usr/local/bin/
fi

# Deploy backend service
echo "Deploying backend service..."
render deploy --service-id $BACKEND_SERVICE_ID

# Deploy worker services
echo "Deploying Celery worker..."
render deploy --service-id $WORKER_SERVICE_ID

echo "Deploying Celery beat..."
render deploy --service-id $BEAT_SERVICE_ID

echo "Deploying Flower..."
render deploy --service-id $FLOWER_SERVICE_ID

echo -e "${GREEN}✅ All services deployed${NC}"

# ============================================
# 7. Wait for Deployment
# ============================================
echo -e "${BLUE}⏳ 6. Waiting for deployments to complete...${NC}"

check_deployment() {
    local SERVICE_ID=$1
    local SERVICE_NAME=$2
    
    echo "Checking $SERVICE_NAME..."
    
    local MAX_RETRIES=60
    local RETRY_COUNT=0
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        STATUS=$(render get-deploy-status --service-id $SERVICE_ID 2>/dev/null || echo "unknown")
        
        case $STATUS in
            "live")
                echo -e "${GREEN}✅ $SERVICE_NAME is live${NC}"
                return 0
                ;;
            "failed")
                echo -e "${RED}❌ $SERVICE_NAME deployment failed${NC}"
                return 1
                ;;
            "building"|"deploying")
                echo -e "${YELLOW}⏳ $SERVICE_NAME is $STATUS...${NC}"
                ;;
            *)
                echo -e "${YELLOW}⏳ Waiting for $SERVICE_NAME...${NC}"
                ;;
        esac
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        sleep 5
    done
    
    echo -e "${RED}❌ $SERVICE_NAME deployment timed out${NC}"
    return 1
}

check_deployment $BACKEND_SERVICE_ID "Backend API"
check_deployment $WORKER_SERVICE_ID "Celery Worker"
check_deployment $BEAT_SERVICE_ID "Celery Beat"
check_deployment $FLOWER_SERVICE_ID "Flower"

# ============================================
# 8. Run Post-Deployment Tasks
# ============================================
echo -e "${BLUE}🔧 7. Running post-deployment tasks...${NC}"

# Health check
echo "Running health check..."
sleep 10
if curl -f https://hanadiz-backend.onrender.com/health &>/dev/null; then
    echo -e "${GREEN}✅ Health check passed${NC}"
else
    echo -e "${YELLOW}⚠️ Health check failed${NC}"
fi

# Run migrations if needed
echo "Running final migrations..."
render run-command --service-id $BACKEND_SERVICE_ID "alembic upgrade head"

# Clear cache
echo "Clearing cache..."
render run-command --service-id $BACKEND_SERVICE_ID "python scripts/clear_cache.py"

echo -e "${GREEN}✅ Post-deployment tasks complete${NC}"

# ============================================
# 9. Deployment Summary
# ============================================
echo ""
echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo "========================================"
echo ""
echo "📊 Deployment Summary:"
echo "  - Backend API: https://hanadiz-backend.onrender.com"
echo "  - Flower Dashboard: https://hanadiz-flower.onrender.com"
echo "  - Health Check: https://hanadiz-backend.onrender.com/health"
echo ""
echo "📝 Next Steps:"
echo "  1. Verify all services are running"
echo "  2. Check monitoring dashboards"
echo "  3. Review logs for any errors"
echo ""
echo "🔍 Useful Commands:"
echo "  - View logs: render logs --service-id $BACKEND_SERVICE_ID"
echo "  - Restart service: render restart --service-id $BACKEND_SERVICE_ID"
echo "  - Rollback: render rollback --service-id $BACKEND_SERVICE_ID"
echo ""