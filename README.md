# devops-demo-api

> A production-grade CI/CD pipeline that automatically tests, containerizes, and deploys a Flask REST API on every Git push.

![CI/CD Pipeline](https://img.shields.io/github/actions/workflow/status/fa1829/devops-demo-api/ci-cd.yml?label=CI%2FCD&style=flat-square)
![Docker](https://img.shields.io/badge/Docker-multi--stage-2496ED?style=flat-square&logo=docker)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

---

## Overview

Every `git push` to `main` triggers a fully automated pipeline:

- Runs 29 unit tests with 91% coverage — bad code never reaches production
- Lints with flake8 for syntax errors
- Builds a production Docker image (multi-stage, non-root user)
- Pushes versioned image to Docker Hub

---

## Architecture
```
git push origin main
        │
        ▼
┌─────────────────────────────────────────┐
│  GitHub Actions                         │
│  test ──▶ build                         │
│  pytest   docker push to Docker Hub     │
│  flake8                                 │
└─────────────────────────────────────────┘
                │
                ▼
         Docker Hub
                │
                ▼
        Production Server
        ┌──────────────┐
        │ Nginx :80    │
        │ Flask :6000  │
        └──────────────┘
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Application | Python 3.12 / Flask |
| WSGI Server | Gunicorn |
| Containerization | Docker (multi-stage build) |
| Reverse Proxy | Nginx |
| CI/CD | GitHub Actions |
| Image Registry | Docker Hub |
| Orchestration | Docker Compose |

---

## Quick Start

**Requirements:** Docker Desktop
```bash
git clone https://github.com/fa1829/devops-demo-api.git
cd devops-demo-api
docker compose up --build
curl http://localhost:8080/health
```

---

## Project Structure
```
devops-demo-api/
├── .github/workflows/ci-cd.yml   ← pipeline
├── app/main.py                   ← Flask API
├── tests/test_api.py             ← 29 tests, 91% coverage
├── nginx/nginx.conf              ← reverse proxy
├── Dockerfile                    ← multi-stage build
└── docker-compose.yml            ← local dev stack
```

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Liveness check |
| GET | `/ready` | Readiness check |
| GET | `/info` | Version and build info |
| GET | `/api/tasks` | List tasks |
| POST | `/api/tasks` | Create task |
| PATCH | `/api/tasks/:id` | Update task |
| DELETE | `/api/tasks/:id` | Delete task |

---

## Running Tests
```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r app/requirements.txt
pytest tests/ -v --cov=app
```

---

## Security

- Non-root container user
- Multi-stage Docker build — no build tools in production image
- Nginx rate limiting and security headers
- All credentials in GitHub Secrets, never in source code

---

## Using This Pipeline for a New Project

This pipeline is designed to be reusable. Any new containerized project
can adopt it in under an hour.

### What You Need
- GitHub repo
- Docker Hub account
- Two secrets in GitHub: `DOCKERHUB_USERNAME` + `DOCKERHUB_TOKEN`

### Step 1 — Copy These 4 Files Into Your New Project
```
.github/workflows/ci-cd.yml   ← the pipeline
Dockerfile                     ← container build
docker-compose.yml             ← local dev stack
nginx/nginx.conf               ← reverse proxy
```

### Step 2 — Change 2 Things in `ci-cd.yml`
```yaml
# Change the test command to match your language
# Python:
pip install -r requirements.txt
pytest tests/

# Node.js:
npm install
npm test

# Java:
mvn test
```
```yaml
# Change the image name
repository: YOUR_DOCKERHUB_USERNAME/YOUR_PROJECT_NAME
```

### Step 3 — Change 1 Thing in `Dockerfile`
```dockerfile
FROM python:3.12-slim   # Python
FROM node:20-slim       # Node.js
FROM eclipse-temurin:21 # Java
```

### Step 4 — Push to Main
```bash
git push origin main
```

Pipeline runs automatically:
```
push → test → build → image on Docker Hub
```

### What You Never Touch Again
```
nginx/nginx.conf    ← universal, works for any web app
secrets pattern     ← same two secrets every time
job structure       ← test → build → summary, always
health check design ← /health endpoint, same pattern
```

One pipeline template. Any language. Any project.

---

## License

MIT
