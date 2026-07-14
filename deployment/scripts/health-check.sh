#!/bin/bash
set -e

# ============================================
# Hanadiz Health Check Script
# ============================================

echo "🔍 Hanadiz Health Check"
echo "======================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
API_URL="${API_URL:-https://hanadiz-backend.onrender.com}"
MAX_RETRIES="${MAX_RETRIES:-30}"
RETRY_INTERVAL="${RETRY_INTERVAL:-5}"
TIMEOUT="${TIMEOUT:-10}"

# ============================================
# 1. Service Health Check
# ============================================
check_endpoint() {
    local ENDPOINT=$1
    local NAME=$2
    local URL="${API_URL}${ENDPOINT}"
    
    echo -e "${BLUE}Checking $NAME ($URL)...${NC}"
    
    local START_TIME=$(date +%s)
    local RETRY_COUNT=0
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        RESPONSE=$(curl -s -w "|%{http_code}" -o /dev/null -m $TIMEOUT "$URL" 2>/dev/null || echo "error|500")
        HTTP_CODE=$(echo "$RESPONSE" | cut -d'|' -f2)
        
        if [ "$HTTP_CODE" = "200" ]; then
            END_TIME=$(date +%s)
            DURATION=$((END_TIME - START_TIME))
            echo -e "${GREEN}✅ $NAME is healthy (${DURATION}s)${NC}"
            return 0
        elif [ "$HTTP_CODE" = "error" ]; then
            echo -e "${YELLOW}⚠️ $NAME connection error (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)${NC}"
        else
            echo -e "${YELLOW}⚠️ $NAME returned HTTP $HTTP_CODE (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)${NC}"
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        sleep $RETRY_INTERVAL
    done
    
    echo -e "${RED}❌ $NAME health check failed${NC}"
    return 1
}

# ============================================
# 2. Run Checks
# ============================================

# Check main endpoints
check_endpoint "/health" "Health Check" || exit 1
check_endpoint "/" "Root Endpoint" || exit 1

# Detailed health information
echo ""
echo -e "${BLUE}📊 Detailed health information:${NC}"
curl -s "$API_URL/health" | jq '.' 2>/dev/null || echo "Could not parse JSON"

# ============================================
# 3. Database Check
# ============================================
echo ""
echo -e "${BLUE}🗄️ Database health check:${NC}"

DB_HEALTH=$(curl -s "$API_URL/health/database" 2>/dev/null || echo '{"status":"unknown"}')
DB_STATUS=$(echo "$DB_HEALTH" | jq -r '.status' 2>/dev/null || echo "unknown")

if [ "$DB_STATUS" = "healthy" ]; then
    echo -e "${GREEN}✅ Database is healthy${NC}"
else
    echo -e "${RED}❌ Database is not healthy${NC}"
    exit 1
fi

# ============================================
# 4. Redis Check
# ============================================
echo ""
echo -e "${BLUE}🔄 Redis health check:${NC}"

REDIS_HEALTH=$(curl -s "$API_URL/health/redis" 2>/dev/null || echo '{"status":"unknown"}')
REDIS_STATUS=$(echo "$REDIS_HEALTH" | jq -r '.status' 2>/dev/null || echo "unknown")

if [ "$REDIS_STATUS" = "healthy" ]; then
    echo -e "${GREEN}✅ Redis is healthy${NC}"
else
    echo -e "${YELLOW}⚠️ Redis is not healthy${NC}"
fi

# ============================================
# 5. Summary
# ============================================
echo ""
echo -e "${GREEN}🎉 All health checks passed!${NC}"