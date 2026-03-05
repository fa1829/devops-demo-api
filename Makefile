# Makefile — devops-demo-api
# ─────────────────────────────────────────────────────────────────────────────
# Wraps common commands so you never have to remember long docker/pytest flags.
#
# Usage:
#   make help          → show all available commands
#   make dev           → start local dev stack
#   make test          → run tests
#   make build         → build Docker image
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: help dev build test lint clean logs shell stop

IMAGE_NAME  := devops-demo-api
IMAGE_TAG   := $(shell git rev-parse --short HEAD 2>/dev/null || echo "local")
FULL_IMAGE  := $(IMAGE_NAME):$(IMAGE_TAG)
PYTHON      := python3

# ── Default target ────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  devops-demo-api — Available Commands"
	@echo "  ────────────────────────────────────"
	@echo "  make dev      Start full local stack (api + nginx)"
	@echo "  make dev-api  Start api only (no nginx)"
	@echo "  make stop     Stop all running containers"
	@echo "  make build    Build Docker image"
	@echo "  make test     Run test suite"
	@echo "  make lint     Run code linter"
	@echo "  make logs     Tail container logs"
	@echo "  make shell    Open shell inside api container"
	@echo "  make clean    Remove containers, images, volumes"
	@echo "  make scan     Scan Docker image for vulnerabilities"
	@echo ""

# ── Local Development ─────────────────────────────────────────────────────────
dev:
	@echo "🚀 Starting local stack..."
	APP_VERSION=$(IMAGE_TAG) BUILD_TIME=$(shell date -u +%Y-%m-%dT%H:%M:%SZ) \
	docker compose up --build

dev-api:
	@echo "🚀 Starting API only..."
	docker compose up --build api

stop:
	docker compose down

logs:
	docker compose logs -f

shell:
	docker compose exec api bash

# ── Testing ───────────────────────────────────────────────────────────────────
test:
	@echo "🧪 Running tests..."
	pip install -r app/requirements.txt -q
	pytest tests/ -v --cov=app --cov-report=term-missing

test-watch:
	@echo "👁 Watching for changes..."
	pip install pytest-watch -q
	ptw tests/ -- -v

# ── Code Quality ──────────────────────────────────────────────────────────────
lint:
	@echo "🔍 Linting..."
	pip install flake8 -q
	flake8 app/ --max-line-length=100 --exclude=__pycache__

# ── Docker ────────────────────────────────────────────────────────────────────
build:
	@echo "🐳 Building $(FULL_IMAGE)..."
	docker build \
		--build-arg APP_VERSION=$(IMAGE_TAG) \
		--build-arg BUILD_TIME=$(shell date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ) \
		-t $(FULL_IMAGE) \
		-t $(IMAGE_NAME):latest \
		.
	@echo "✅ Built: $(FULL_IMAGE)"
	@docker images $(IMAGE_NAME) --format "{{.Repository}}:{{.Tag}}\t{{.Size}}"

scan:
	@echo "🔒 Scanning for vulnerabilities..."
	@which trivy > /dev/null 2>&1 || (echo "Install trivy: brew install trivy" && exit 1)
	trivy image --severity HIGH,CRITICAL $(IMAGE_NAME):latest

# ── Cleanup ───────────────────────────────────────────────────────────────────
clean:
	@echo "🧹 Cleaning up..."
	docker compose down -v --remove-orphans
	docker rmi $(IMAGE_NAME):latest $(FULL_IMAGE) 2>/dev/null || true
	docker image prune -f
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.pyc" -delete 2>/dev/null || true
	rm -f coverage.xml .coverage
	@echo "✅ Clean!"

# ── Quick smoke test against running container ────────────────────────────────
smoke:
	@echo "💨 Smoke testing local stack..."
	@curl -sf http://localhost:5000/health | python3 -m json.tool && echo "✅ /health OK"
	@curl -sf http://localhost:5000/ | python3 -m json.tool && echo "✅ / OK"
	@curl -sf http://localhost/health | python3 -m json.tool && echo "✅ nginx proxy OK"
