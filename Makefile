.PHONY: help build run stop restart logs shell exec clean test

# Variables
DOCKER ?= docker
IMAGE_NAME := vsftpd-containerized
CONTAINER_NAME := vsftpd
TAG := latest
PORTS := -p 21:21 -p 40000-40100:40000-40100

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the Docker image
	$(DOCKER) build -t $(IMAGE_NAME):$(TAG) .
	$(DOCKER) image ls --format "ID: {{.ID}}  Size: {{.Size}}  Created: {{.CreatedSince}}  Repo: {{.Repository}}  Tag: {{.Tag}}" $(IMAGE_NAME):$(TAG)

build-release: ## Build with metadata (for releases)
	$(DOCKER) build \
		--build-arg BUILD_DATE=$$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
		--build-arg VCS_REF=$$(git rev-parse --short HEAD 2>/dev/null || echo "unknown") \
		-t $(IMAGE_NAME):$(TAG) .

run: build rm ## Run the container in detached mode
	$(DOCKER) run -d \
		--name $(CONTAINER_NAME) \
		$(PORTS) \
		-e AUTH_MODE=virtual \
		-e PASV_ADDRESS=$$(hostname -I | awk '{print $$1}') \
		-e FTPD_BANNER="Welcome to local FTP service" \
		$(IMAGE_NAME):$(TAG)

run-fg: build rm ## Run the container in foreground (interactive)
	$(DOCKER) run --rm -it \
		--name $(CONTAINER_NAME) \
		$(PORTS) \
		-e AUTH_MODE=virtual \
		-e PASV_ADDRESS=$$(hostname -I | awk '{print $$1}') \
		-e FTPD_BANNER="Welcome to local FTP service" \
		$(IMAGE_NAME):$(TAG)

stop: ## Stop the container
	$(DOCKER) stop $(CONTAINER_NAME) 2>/dev/null || true

rm: stop ## Remove the container
	$(DOCKER) rm $(CONTAINER_NAME) 2>/dev/null || true

restart: stop run ## Restart the container

logs: ## Show container logs
	$(DOCKER) logs -f $(CONTAINER_NAME)

shell: ## Get a shell in the running container
	$(DOCKER) exec -it $(CONTAINER_NAME) /bin/bash

exec: ## Execute a command in the container (use: make exec CMD="your command")
	$(DOCKER) exec -it $(CONTAINER_NAME) $(CMD)

clean: rm ## Remove container and image
	$(DOCKER) rmi $(IMAGE_NAME):$(TAG) || true

rebuild: clean build ## Clean and rebuild the image

dev: rebuild run logs ## Build, run and show logs (for development)

debug: build rm ## Run container in foreground with verbose debugging
	@echo "Starting container in DEBUG mode with verbose logging..."
	@echo "Press Ctrl+C to stop"
	$(DOCKER) run --rm -it \
		--name $(CONTAINER_NAME) \
		$(PORTS) \
		-e AUTH_MODE=virtual \
		-e XFERLOG_ENABLE=YES \
		-e LOG_FTP_PROTOCOL=YES \
		-e DEBUG_SSL=YES \
		-e PASV_ADDRESS=$$(hostname -I | awk '{print $$1}') \
		-e FTPD_BANNER="[DEBUG MODE] Welcome to FTP service" \
		$(IMAGE_NAME):$(TAG)

test: run ## Build and run a quick test
	@echo "Testing running container..."
	@echo "Waiting for initialization (snakeoil cert generation)..."
	@sleep 2
	@echo "Checking if vsftpd is running..."
	@if $(DOCKER) exec $(CONTAINER_NAME) pgrep vsftpd > /dev/null 2>&1; then \
		echo "✓ vsftpd is running"; \
		echo "✓ Test passed!"; \
	else \
		echo "✗ vsftpd is not running"; \
		echo "Container logs:"; \
		$(DOCKER) logs $(CONTAINER_NAME); \
		exit 1; \
	fi

ps: ## Show container status
	$(DOCKER) ps -a | grep $(CONTAINER_NAME) || echo "Container not found"

inspect: ## Inspect the container
	$(DOCKER) inspect $(CONTAINER_NAME)

config: ## Show current configuration
	$(DOCKER) exec $(CONTAINER_NAME) cat /etc/vsftpd.conf
