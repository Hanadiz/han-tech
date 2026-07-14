# ============================================
# Hanadiz Deployment Makefile
# ============================================

.PHONY: help build deploy rollback health-check logs restart status

# Variables
SERVICE_ID ?= your-service-id
ENVIRONMENT ?= production

help:
	@echo "Hanadiz Deployment Commands"
	@echo "==========================="
	@echo ""
	@echo "Available commands:"
	@echo "  make build         - Build Docker images"
	@echo "  make deploy        - Deploy to Render"
	@echo "  make rollback      - Rollback to previous deployment"
	@echo "  make health-check  - Run health checks"
	@echo "  make logs          - View logs"
	@echo "  make restart       - Restart services"
	@echo "  make status        - Check service status"
	@echo "  make migrate       - Run database migrations"
	@echo "  make seed          - Seed database"
	@echo "  make backup        - Create backup"
	@echo ""

build:
	@echo "Building Docker images..."
	@bash deployment/scripts/build.sh

deploy:
	@echo "Deploying to Render..."
	@bash deployment/scripts/deploy.sh

rollback:
	@echo "Rolling back deployment..."
	@bash deployment/scripts/rollback.sh

health-check:
	@echo "Running health checks..."
	@bash deployment/scripts/health-check.sh

logs:
	@echo "Fetching logs..."
	@render logs --service-id $(SERVICE_ID) --tail

restart:
	@echo "Restarting services..."
	@render restart --service-id $(SERVICE_ID)

status:
	@echo "Checking service status..."
	@render status --service-id $(SERVICE_ID)

migrate:
	@echo "Running database migrations..."
	@render run-command --service-id $(SERVICE_ID) "alembic upgrade head"

seed:
	@echo "Seeding database..."
	@render run-command --service-id $(SERVICE_ID) "python scripts/seed_database.py"

backup:
	@echo "Creating backup..."
	@render run-command --service-id $(SERVICE_ID) "python scripts/backup.py"

# Combined commands
deploy-full: deploy health-check
	@echo "Full deployment complete!"

rollback-full: rollback health-check
	@echo "Rollback complete!"