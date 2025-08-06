# Blindr Services Makefile
# Provides convenient commands for managing the Docker Compose services

# Default environment file
ENV_FILE := .env
ifeq (,$(wildcard $(ENV_FILE)))
	ENV_FILE := .env.example
endif

# Docker Compose command with proper environment
DOCKER_COMPOSE := docker-compose --env-file $(ENV_FILE)

# Default target
.PHONY: help
help: ## Show this help message
	@echo "Blindr Services - Docker Compose Management"
	@echo "==========================================="
	@echo
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Profiles:"
	@echo "  production  - Includes nginx reverse proxy"
	@echo "  monitoring  - Includes Prometheus monitoring"
	@echo
	@echo "Examples:"
	@echo "  make setup              # Initial setup"
	@echo "  make up                 # Start core services"
	@echo "  make up-prod            # Start with production profile"
	@echo "  make logs service=whisper  # View specific service logs"

# =============================================================================
# SETUP AND INITIALIZATION
# =============================================================================

.PHONY: setup
setup: ## Initial setup - create directories and environment file
	@echo "Setting up Blindr services..."
	@if [ ! -f .env ]; then \
		echo "Creating .env file from template..."; \
		cp .env.example .env; \
		echo "✓ Created .env file - please review and customize it"; \
	else \
		echo "✓ .env file already exists"; \
	fi
	@echo "Creating data directories..."
	@mkdir -p data/whisper/{models,logs}
	@mkdir -p data/piper/{models,logs,cache}
	@mkdir -p monitoring nginx/ssl
	@echo "✓ Created data directories"
	@echo "✓ Setup complete!"

.PHONY: check-env
check-env: ## Validate environment configuration
	@echo "Checking environment configuration..."
	@if [ ! -f .env ]; then \
		echo "❌ .env file not found. Run 'make setup' first."; \
		exit 1; \
	fi
	@echo "✓ Environment file exists"
	@$(DOCKER_COMPOSE) config --quiet && echo "✓ Docker Compose configuration valid" || (echo "❌ Docker Compose configuration invalid" && exit 1)

# =============================================================================
# SERVICE MANAGEMENT
# =============================================================================

.PHONY: build
build: ## Build all service images
	@echo "Building service images..."
	@$(DOCKER_COMPOSE) build

.PHONY: up
up: check-env ## Start core services (whisper + piper)
	@echo "Starting Blindr services..."
	@$(DOCKER_COMPOSE) up -d whisper-service piper-service

.PHONY: up-prod
up-prod: check-env ## Start services with production profile (includes nginx)
	@echo "Starting Blindr services with production profile..."
	@$(DOCKER_COMPOSE) --profile production up -d

.PHONY: up-monitoring
up-monitoring: check-env ## Start services with monitoring profile (includes prometheus)
	@echo "Starting Blindr services with monitoring..."
	@$(DOCKER_COMPOSE) --profile monitoring up -d

.PHONY: up-all
up-all: check-env ## Start all services and profiles
	@echo "Starting all Blindr services..."
	@$(DOCKER_COMPOSE) --profile production --profile monitoring up -d

.PHONY: down
down: ## Stop and remove all services
	@echo "Stopping Blindr services..."
	@$(DOCKER_COMPOSE) --profile production --profile monitoring down

.PHONY: restart
restart: ## Restart all running services
	@echo "Restarting Blindr services..."
	@$(DOCKER_COMPOSE) restart

.PHONY: restart-service
restart-service: ## Restart specific service (usage: make restart-service service=whisper-service)
	@if [ -z "$(service)" ]; then \
		echo "❌ Please specify service: make restart-service service=whisper-service"; \
		exit 1; \
	fi
	@echo "Restarting $(service)..."
	@$(DOCKER_COMPOSE) restart $(service)

# =============================================================================
# MONITORING AND DEBUGGING
# =============================================================================

.PHONY: status
status: ## Show status of all services
	@echo "Blindr Services Status:"
	@echo "======================"
	@$(DOCKER_COMPOSE) ps

.PHONY: logs
logs: ## View logs for all services or specific service (usage: make logs service=whisper-service)
	@if [ -n "$(service)" ]; then \
		echo "Viewing logs for $(service)..."; \
		$(DOCKER_COMPOSE) logs -f $(service); \
	else \
		echo "Viewing logs for all services..."; \
		$(DOCKER_COMPOSE) logs -f; \
	fi

.PHONY: logs-tail
logs-tail: ## Tail logs with timestamp for all services
	@echo "Tailing logs for all services..."
	@$(DOCKER_COMPOSE) logs -f --timestamps --tail=100

.PHONY: health
health: ## Check health of all services
	@echo "Checking service health..."
	@echo "========================="
	@echo "Whisper Service:"
	@curl -s http://localhost:9000/health | python3 -m json.tool || echo "❌ Whisper service not responding"
	@echo
	@echo "Piper Service:"
	@curl -s http://localhost:9001/health | python3 -m json.tool || echo "❌ Piper service not responding"

.PHONY: test
test: ## Run basic connectivity tests
	@echo "Testing service connectivity..."
	@echo "==============================="
	@echo "Testing Whisper service..."
	@curl -s -f http://localhost:9000/health > /dev/null && echo "✓ Whisper service healthy" || echo "❌ Whisper service unhealthy"
	@echo "Testing Piper service..."
	@curl -s -f http://localhost:9001/health > /dev/null && echo "✓ Piper service healthy" || echo "❌ Piper service unhealthy"

# =============================================================================
# DEVELOPMENT AND DEBUGGING
# =============================================================================

.PHONY: shell
shell: ## Open shell in service container (usage: make shell service=whisper-service)
	@if [ -z "$(service)" ]; then \
		echo "❌ Please specify service: make shell service=whisper-service"; \
		exit 1; \
	fi
	@echo "Opening shell in $(service)..."
	@$(DOCKER_COMPOSE) exec $(service) /bin/bash

.PHONY: debug
debug: ## Start services in debug mode with verbose logging
	@echo "Starting services in debug mode..."
	@LOG_LEVEL=debug $(DOCKER_COMPOSE) up --build

.PHONY: rebuild
rebuild: ## Force rebuild of all images without cache
	@echo "Rebuilding all service images..."
	@$(DOCKER_COMPOSE) build --no-cache

# =============================================================================
# MAINTENANCE AND CLEANUP
# =============================================================================

.PHONY: clean
clean: ## Remove stopped containers and unused images
	@echo "Cleaning up Docker resources..."
	@docker container prune -f
	@docker image prune -f
	@echo "✓ Cleanup complete"

.PHONY: clean-all
clean-all: ## Remove all containers, images, and volumes (DESTRUCTIVE!)
	@echo "WARNING: This will remove all data including models and logs!"
	@read -p "Are you sure? (y/N) " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo; \
		echo "Removing all Docker resources..."; \
		$(DOCKER_COMPOSE) down -v --remove-orphans; \
		docker image prune -a -f; \
		docker volume prune -f; \
		rm -rf data/; \
		echo "✓ Complete cleanup finished"; \
	else \
		echo; \
		echo "Cancelled"; \
	fi

.PHONY: backup
backup: ## Backup model data and configuration
	@echo "Creating backup..."
	@backup_name="blindr-services-backup-$(shell date +%Y%m%d-%H%M%S)"; \
	tar -czf "$$backup_name.tar.gz" data/ .env nginx/ monitoring/ 2>/dev/null || true; \
	echo "✓ Backup created: $$backup_name.tar.gz"

.PHONY: update
update: ## Update service images and restart
	@echo "Updating service images..."
	@$(DOCKER_COMPOSE) pull
	@$(DOCKER_COMPOSE) up -d --build
	@echo "✓ Services updated and restarted"

# =============================================================================
# QUICK ACTIONS
# =============================================================================

.PHONY: stop
stop: down ## Alias for 'down'

.PHONY: start
start: up ## Alias for 'up'

.PHONY: ps
ps: status ## Alias for 'status'