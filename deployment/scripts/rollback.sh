#!/bin/bash
set -e

# ============================================
# Hanadiz Rollback Script
# ============================================

echo "🔄 Hanadiz Rollback Script"
echo "=========================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
cd $PROJECT_ROOT

if [ -f ".env.deployment" ]; then
    export $(cat .env.deployment | grep -v '^#' | xargs)
fi

# Validate environment
if [ -z "$RENDER_API_KEY" ] || [ -z "$BACKEND_SERVICE_ID" ]; then
    echo -e "${RED}❌ RENDER_API_KEY or BACKEND_SERVICE_ID not set${NC}"
    exit 1
fi

# Get previous deploy ID
echo "Fetching previous deployment..."
PREVIOUS_DEPLOY=$(curl -s -H "Authorization: Bearer $RENDER_API_KEY" \
    "https://api.render.com/v1/services/$BACKEND_SERVICE_ID/deploys?limit=2" \
    | jq -r '.[1].id')

if [ -z "$PREVIOUS_DEPLOY" ] || [ "$PREVIOUS_DEPLOY" = "null" ]; then
    echo -e "${RED}❌ No previous deployment found${NC}"
    exit 1
fi

echo "Rolling back to deployment: $PREVIOUS_DEPLOY"

# Trigger rollback
curl -X POST \
    -H "Authorization: Bearer $RENDER_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"deployId\": \"$PREVIOUS_DEPLOY\"}" \
    "https://api.render.com/v1/services/$BACKEND_SERVICE_ID/rollback"

echo -e "${GREEN}✅ Rollback initiated${NC}"

# Wait for rollback
echo "Waiting for rollback to complete..."
sleep 30

# Check status
STATUS=$(curl -s -H "Authorization: Bearer $RENDER_API_KEY" \
    "https://api.render.com/v1/services/$BACKEND_SERVICE_ID/deploys?limit=1" \
    | jq -r '.[0].status')

if [ "$STATUS" = "live" ]; then
    echo -e "${GREEN}✅ Rollback successful${NC}"
else
    echo -e "${RED}❌ Rollback failed with status: $STATUS${NC}"
    exit 1
fi