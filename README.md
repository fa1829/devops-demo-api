# devops-demo-api · CI/CD Pipeline Portfolio Project

> **A production-grade CI/CD pipeline that automatically tests, containerizes, and deploys a Flask REST API on every Git push — reducing deployment time from 20+ minutes of manual work to under 3 minutes, fully automated.**

![CI/CD Pipeline](https://img.shields.io/github/actions/workflow/status/YOUR_USERNAME/devops-demo-api/ci-cd.yml?label=CI%2FCD%20Pipeline&style=flat-square)
![Docker](https://img.shields.io/badge/Docker-multi--stage-2496ED?style=flat-square&logo=docker)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

---

## 🎯 The Problem This Solves

Before CI/CD, deploying a new feature meant:
1. Developer finishes code on their laptop
2. Manually SSH into the server
3. `git pull` the code
4. Remember to install new dependencies
5. Restart the app process
6. Manually check if it started correctly
7. Hope nothing broke in production

This takes 20+ minutes, is error-prone, can't be rolled back easily, and nobody can do it while the one person with server access is on vacation.

**This project automates all of that.** Every `git push` to `main` triggers a pipeline that:
- Runs the full test suite (if tests fail → nothing deploys)
- Lints the code for errors
- Builds a production Docker image
- Scans it for security vulnerabilities
- Pushes it to Docker Hub with a versioned tag
- SSHs into the server and deploys the new container
- Runs a post-deployment health check to verify success

---

## 🏗️ Architecture

```
Developer Laptop
      │
      │  git push origin main
      ▼
┌─────────────────────────────────────────────────────────┐
│  GitHub Actions (CI/CD Runner)                          │
│                                                         │
│  Job 1: TEST           Job 2: BUILD        Job 3: DEPLOY│
│  ┌─────────────┐      ┌─────────────┐     ┌──────────┐ │
│  │ pytest      │ ───▶ │ docker build│ ──▶ │ SSH +    │ │
│  │ flake8 lint │      │ trivy scan  │     │ docker   │ │
│  │ cov report  │      │ push to hub │     │ compose  │ │
│  └─────────────┘      └─────────────┘     └──────────┘ │
└─────────────────────────────────────────────────────────┘
                               │                    │
                               ▼                    ▼
                        Docker Hub           Production Server
                        (image registry)     ┌──────────────┐
                                             │ Nginx :80    │
                                             │      │       │
                                             │ Flask :5000  │
                                             │ (container)  │
                                             └──────────────┘
```

---

## 🛠️ Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Application | Python / Flask | Simple, readable, real-world REST API |
| WSGI Server | Gunicorn | Production-grade (not Flask dev server) |
| Containerization | Docker (multi-stage) | Portable, reproducible builds |
| Reverse Proxy | Nginx | SSL, rate limiting, security headers |
| CI/CD | GitHub Actions | Native to GitHub, free for public repos |
| Image Registry | Docker Hub | Industry standard, free tier available |
| Security Scanning | Trivy (Aqua Security) | Scans for CVEs in Docker images |
| Orchestration | Docker Compose | Local dev + single-server production |

---

## 🚀 Quick Start (Run Locally in 3 Commands)

**Prerequisites:** Docker Desktop installed and running. That's it.

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/devops-demo-api.git
cd devops-demo-api

# 2. Start the full stack (Flask API + Nginx reverse proxy)
docker compose up --build

# 3. Test it's working
curl http://localhost/health
```

**Expected output:**
```json
{
  "status": "healthy",
  "timestamp": "2025-01-24T10:30:00.000Z",
  "uptime_seconds": 2.14
}
```

**Access points:**
- `http://localhost` → via Nginx (production-like)
- `http://localhost:5000` → direct Flask/Gunicorn
- `http://localhost/api/tasks` → task CRUD API

---

## 📁 Project Structure

```
devops-demo-api/
├── .github/
│   └── workflows/
│       └── ci-cd.yml          ← THE PIPELINE (read this first)
├── app/
│   ├── main.py                ← Flask application
│   └── requirements.txt       ← Python dependencies
├── tests/
│   └── test_api.py            ← Test suite (25+ tests)
├── nginx/
│   └── nginx.conf             ← Nginx reverse proxy config
├── Dockerfile                 ← Multi-stage container build
├── docker-compose.yml         ← Local dev stack
├── Makefile                   ← Developer convenience commands
└── README.md                  ← You are here
```

---

## 🔄 The CI/CD Pipeline Explained

The pipeline lives in `.github/workflows/ci-cd.yml`. It has 4 jobs:

### Job 1: Test (runs on every push, every branch)
```
push to any branch
        │
        ▼
  ┌───────────────────────────┐
  │  1. Checkout code         │
  │  2. Set up Python 3.12    │
  │  3. pip install deps      │
  │  4. flake8 lint           │  ← Catch syntax errors before tests
  │  5. pytest (25+ tests)    │  ← If ANY test fails → stop here
  │  6. Coverage report       │  ← Fails if coverage < 70%
  └───────────────────────────┘
```

### Job 2: Build (runs only on push to `main`, after tests pass)
```
tests pass + main branch
        │
        ▼
  ┌───────────────────────────┐
  │  1. Docker login (Hub)    │
  │  2. docker build          │  ← Multi-stage, cached layers
  │  3. Tag: latest + sha     │  ← Versioned tags for rollbacks
  │  4. docker push           │
  │  5. Trivy CVE scan        │  ← Security scanning
  │  6. Report image size     │
  └───────────────────────────┘
```

### Job 3: Deploy (runs after image is built)
```
image pushed to registry
        │
        ▼
  ┌───────────────────────────┐
  │  1. SSH into server       │
  │  2. docker pull :latest   │
  │  3. docker compose up -d  │
  │  4. Wait for health check │
  │  5. Verify /health → 200  │
  │  6. Prune old images      │
  └───────────────────────────┘
```

---

## 🧪 Running Tests

```bash
# Install dependencies locally
pip install -r app/requirements.txt

# Run all tests with verbose output + coverage
pytest tests/ -v --cov=app --cov-report=term-missing

# Run a specific test class
pytest tests/test_api.py::TestHealthEndpoints -v

# Run with coverage HTML report
pytest tests/ --cov=app --cov-report=html
open htmlcov/index.html
```

**Test coverage includes:**
- ✅ Health & readiness endpoints
- ✅ Root and info endpoints  
- ✅ Full CRUD for task API
- ✅ Error handlers (404, 405)
- ✅ Query parameter filtering
- ✅ Input validation

---

## 🔒 Security Decisions (Talk About These in Interviews)

| Decision | Why |
|----------|-----|
| Non-root container user | Limits blast radius if container is compromised |
| Multi-stage Docker build | Build tools never make it into the production image |
| Trivy CVE scanning | Catches known vulnerabilities before deployment |
| Secrets via GitHub Secrets | Credentials never appear in source code |
| Nginx security headers | X-Frame-Options, X-XSS-Protection, no server tokens |
| Nginx rate limiting | 10 req/s per IP prevents basic DDoS |
| No `latest` tag in production | SHA-tagged images enable precise rollbacks |

---

## 🌐 API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Service info, version, available endpoints |
| GET | `/health` | Liveness check (for load balancers / K8s) |
| GET | `/ready` | Readiness check (for K8s readiness probes) |
| GET | `/info` | Detailed system and build info |
| GET | `/api/tasks` | List all tasks (`?done=true/false` filter) |
| GET | `/api/tasks/:id` | Get single task |
| POST | `/api/tasks` | Create task `{"title": "..."}` |
| PATCH | `/api/tasks/:id` | Update task `{"done": true}` |
| DELETE | `/api/tasks/:id` | Delete task |

---

## ⚙️ Setting Up the Pipeline (Your Own Deployment)

### Step 1: Fork & clone this repo

### Step 2: Create a Docker Hub account + access token
1. Go to hub.docker.com → Account Settings → Security → New Access Token
2. Save the token (you only see it once)

### Step 3: Add GitHub Secrets
In your GitHub repo → Settings → Secrets and variables → Actions → New repository secret:

| Secret Name | Value |
|-------------|-------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Your Docker Hub access token |
| `DEPLOY_HOST` | Your server's IP address |
| `DEPLOY_USER` | SSH username (e.g., `ubuntu`) |
| `DEPLOY_SSH_KEY` | Your private SSH key content |
| `DEPLOY_PORT` | SSH port (usually `22`) |

### Step 4: Prepare your server
```bash
# On your server (Ubuntu/Debian):
sudo apt update && sudo apt install -y docker.io docker-compose-v2
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# Create the app directory
mkdir ~/devops-demo
cd ~/devops-demo

# Copy docker-compose.yml to the server
# (or git clone the repo here)
```

### Step 5: Push to main
```bash
git push origin main
```
Watch the pipeline run at: `github.com/YOUR_USERNAME/devops-demo-api/actions`

---

## 🐛 Troubleshooting

**Container won't start:**
```bash
docker compose logs api          # Check app logs
docker compose ps                # Check container status
```

**Pipeline fails at SSH step:**
- Check that `DEPLOY_SSH_KEY` has no trailing newline
- Verify the server IP in `DEPLOY_HOST`
- Test SSH manually: `ssh -i your-key user@host`

**Port 80 already in use:**
```bash
sudo lsof -i :80                 # See what's using it
# Change ports in docker-compose.yml if needed
```

---

## 💬 Interview Talking Points

**"What problem does this project solve?"**
> "Manual deployments are slow, error-prone, and create single points of failure — only one person knows how to deploy. This pipeline completely automates the process: tests run automatically, bad code never reaches production, and any team member triggering a merge to main kicks off the full deployment without SSH access or manual steps."

**"What was the hardest part?"**
> "Structuring the jobs so failures cascade correctly — tests fail → build never runs, build fails → deploy never runs. Also handling the health check loop in the deploy script to confirm the new container is actually serving before reporting success."

**"Why Nginx in front of Flask?"**
> "Flask's built-in server isn't production-safe — it's single-threaded and has no rate limiting or security headers. Nginx handles connection queuing, rate limiting (10 req/s/IP), security headers, and acts as the SSL termination point in a real deployment. Gunicorn handles multiple worker processes for the Flask app."

**"How would you scale this?"**
> "Current setup is a single server — works for small traffic. Next step would be moving to Kubernetes (EKS/GKE) so the deployment step becomes updating a K8s Deployment manifest instead of SSHing into a single machine. The CI portion stays identical."

---

## 📚 Related Projects in This Portfolio

- **Project 2:** [terraform-aws-infra](../devops-project-2) — Infrastructure as Code with Terraform
- **Project 3:** [k8s-monitoring-stack](../devops-project-3) — Kubernetes + Prometheus + Grafana
- **Project 4:** [devsecops-pipeline](../devops-project-4) — Security-first CI/CD
- **Project 5:** [gitops-argocd](../devops-project-5) — GitOps with ArgoCD

---

## 📄 License

MIT — use this freely for your own portfolio.

---

*Built as Portfolio Project #1 of 5 in the DevOps Career Compass series.*  
*Inspired by the DevOps Career Compass webinar by Anusha Vendra (Veeva Systems).*
