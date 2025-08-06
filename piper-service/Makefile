# Piper TTS Service Makefile
# Provides common development and deployment tasks

.PHONY: build run stop clean test health logs install-systemd remove-systemd

# Default image name and tag
IMAGE_NAME := piper-tts-service
TAG := latest
CONTAINER_NAME := piper-tts-service

# Build the Docker image
build:
	@echo "Building Piper TTS service..."
	./build.sh -t $(TAG)

# Build and run the service
run:
	@echo "Building and running Piper TTS service..."
	./build.sh -t $(TAG) -r

# Build without cache
build-clean:
	@echo "Building Piper TTS service (no cache)..."
	./build.sh -t $(TAG) -f

# Start with Docker Compose
up:
	@echo "Starting service with Docker Compose..."
	docker-compose up -d

# Stop Docker Compose services
down:
	@echo "Stopping Docker Compose services..."
	docker-compose down

# Stop the running container
stop:
	@echo "Stopping Piper TTS service..."
	docker stop $(CONTAINER_NAME) 2>/dev/null || true

# Remove the container
clean: stop
	@echo "Cleaning up containers and images..."
	docker rm $(CONTAINER_NAME) 2>/dev/null || true
	docker rmi $(IMAGE_NAME):$(TAG) 2>/dev/null || true

# Run tests
test:
	@echo "Running service tests..."
	python test_service.py

# Check service health
health:
	@echo "Checking service health..."
	@curl -f http://localhost:9001/health 2>/dev/null || echo "Service not responding"

# View container logs
logs:
	@echo "Showing container logs..."
	docker logs -f $(CONTAINER_NAME)

# View Docker Compose logs
logs-compose:
	@echo "Showing Docker Compose logs..."
	docker-compose logs -f

# Install systemd service (requires sudo)
install-systemd:
	@echo "Installing systemd service..."
	sudo cp piper-tts.service /etc/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable piper-tts.service
	@echo "Service installed. Start with: sudo systemctl start piper-tts.service"

# Remove systemd service (requires sudo)
remove-systemd:
	@echo "Removing systemd service..."
	sudo systemctl stop piper-tts.service 2>/dev/null || true
	sudo systemctl disable piper-tts.service 2>/dev/null || true
	sudo rm -f /etc/systemd/system/piper-tts.service
	sudo systemctl daemon-reload

# Generate speech sample (requires running service)
sample:
	@echo "Generating speech sample..."
	curl -X POST http://localhost:9001/tts \
		-H "Content-Type: application/json" \
		-d '{"text":"Hello, this is Piper TTS speaking! The service is working correctly."}' \
		--output sample-speech.wav
	@echo "Sample saved as sample-speech.wav"

# List available voices (requires running service)
voices:
	@echo "Available voices:"
	@curl -s http://localhost:9001/voices | python -m json.tool

# Show service information
info:
	@echo "=== Piper TTS Service Information ==="
	@echo "Image: $(IMAGE_NAME):$(TAG)"
	@echo "Container: $(CONTAINER_NAME)"
	@echo "Port: 9001"
	@echo "Health Check: http://localhost:9001/health"
	@echo "API Docs: http://localhost:9001/docs"
	@echo ""
	@echo "=== Docker Status ==="
	@docker ps --filter name=$(CONTAINER_NAME) --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "=== Image Size ==="
	@docker images --filter reference=$(IMAGE_NAME) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Development mode with auto-reload
dev:
	@echo "Starting in development mode..."
	docker run -it --rm \
		-p 9001:9001 \
		-v $(PWD):/app \
		-w /app \
		$(IMAGE_NAME):$(TAG) \
		python -m uvicorn service:app --host 0.0.0.0 --port 9001 --reload

# Interactive shell in container
shell:
	@echo "Opening shell in service container..."
	docker run -it --rm \
		-v $(PWD):/app \
		-w /app \
		$(IMAGE_NAME):$(TAG) \
		/bin/bash

# Push image to registry (customize registry URL)
push: build
	@echo "Pushing image to registry..."
	docker tag $(IMAGE_NAME):$(TAG) your-registry.com/$(IMAGE_NAME):$(TAG)
	docker push your-registry.com/$(IMAGE_NAME):$(TAG)

help:
	@echo "Available targets:"
	@echo "  build          - Build Docker image"
	@echo "  run            - Build and run service"
	@echo "  build-clean    - Build without cache"
	@echo "  up             - Start with Docker Compose"
	@echo "  down           - Stop Docker Compose"
	@echo "  stop           - Stop running container"
	@echo "  clean          - Remove container and image"
	@echo "  test           - Run service tests"
	@echo "  health         - Check service health"
	@echo "  logs           - View container logs"
	@echo "  logs-compose   - View Docker Compose logs"
	@echo "  install-systemd - Install systemd service"
	@echo "  remove-systemd - Remove systemd service"
	@echo "  sample         - Generate speech sample"
	@echo "  voices         - List available voices"
	@echo "  info           - Show service information"
	@echo "  dev            - Start in development mode"
	@echo "  shell          - Open interactive shell"
	@echo "  push           - Push image to registry"
	@echo "  help           - Show this help message"