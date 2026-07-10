# devops-demo-api

A containerized **Flask REST API** with a complete **CI/CD pipeline** built on
GitHub Actions. Every push runs an automated test suite (29 tests, 91% coverage)
and linting; on success, a multi-stage Docker image is built and published. The
project demonstrates the core DevOps practices — automated testing as a quality
gate, secure containerization, and health endpoints for orchestration — as a small
but complete and reusable template.

---

## Table of contents

1. [Background: what CI/CD is and why it matters](#1-background)
2. [Core concepts](#2-core-concepts)
3. [Architecture](#3-architecture)
4. [Repository structure](#4-repository-structure)
5. [API endpoints](#5-api-endpoints)
6. [Quick start (local)](#6-quick-start-local)
7. [The CI/CD pipeline](#7-the-cicd-pipeline)
8. [Security practices](#8-security-practices)
9. [Reusing the pipeline for another project](#9-reusing-the-pipeline-for-another-project)
10. [Design notes and limitations](#10-design-notes-and-limitations)
11. [Requirements](#11-requirements)
12. [Further reading](#12-further-reading)

---

## 1. Background

### What CI/CD is

**CI/CD** stands for Continuous Integration and Continuous Deployment (or
Delivery), the practices and tooling that automate building, testing, and releasing
software.

- **Continuous Integration (CI)** means every code change is automatically built and
  tested, so integration problems are caught early rather than accumulating.
- **Continuous Deployment/Delivery (CD)** means every change that passes CI is
  automatically (Deployment) or on approval (Delivery) turned into a publishable
  release artifact.

### Why it matters

Automating the build-test-release path removes manual, error-prone steps, catches
defects at the cheapest possible point (before they ship), and makes releases
repeatable. This project implements that path end to end for a small API, so each
practice is visible rather than hidden inside a large system.

---

## 2. Core concepts

These concepts explain the pipeline and container design in later sections.

### CI versus CD, mapped onto this pipeline

In this project's GitHub Actions workflow, the **test** job (pytest plus a linter)
is the CI step — every push is verified before anything else happens. The **build**
job, which produces and publishes a Docker image after tests pass, is the CD step.
The distinction is concrete here: one job verifies, the next releases.

### The pipeline as a sequence of quality gates

The jobs are ordered deliberately — `test` then `build` — so the build never runs
if the tests fail. A broken image therefore cannot even be produced, let alone
published. This "fail fast" ordering is the general reason pipelines are staged into
steps rather than doing everything at once: each stage catches a specific class of
problem as early and cheaply as possible.

### Multi-stage Docker builds

A multi-stage build uses one stage containing full build tooling (compilers, dev
dependencies) to build the application, then copies only the finished artifacts into
a clean, minimal final image. The result is a smaller production image with a
reduced attack surface, because build tools that could assist an attacker after a
compromise are simply not present in what ships.

### Non-root container users

The container runs its process as a non-root user. If an attacker achieves code
execution inside the container, they do not automatically hold root privileges
within it — the principle of least privilege applied at the container layer. It is
an easy control to omit and a meaningful one to include.

### Health and readiness endpoints

The API exposes `/health` (liveness) and `/ready` (readiness) endpoints so that an
external system — an orchestrator such as Kubernetes, or a load balancer — can ask
"should traffic be routed here, or should this instance be restarted?" without human
involvement. These endpoints are the integration point between an application and
the platform that runs it.

### Secrets via CI secrets

Registry credentials used by the pipeline are injected as encrypted CI secrets
rather than hardcoded. This is the CI/CD form of the environment-variable pattern
for handling secrets: credentials never live in source code or version control.

---

## 3. Architecture

```
developer push
      │
      ▼
GitHub Actions
  ├── test  (pytest + lint)  ── fails ─►  pipeline stops, no image built
  │        │ passes
  │        ▼
  └── build (multi-stage Docker image)  ──►  publish to registry
                                                    │
                                                    ▼
                                     deployable image (used by k8s-deployment-demo)

Local development:
  docker-compose  ──►  Flask API (non-root)  +  nginx reverse proxy
```

The published image is consumed by a separate Kubernetes deployment project, which
relies on the health/readiness endpoints defined here — the two form a connected
build-then-deploy pair.

---

## 4. Repository structure

```
devops-demo-api/
├── app/                      # Flask application code
├── tests/                    # Test suite (29 tests, 91% coverage)
├── nginx/
│   └── nginx.conf            # Reverse-proxy configuration
├── .github/
│   └── workflows/            # GitHub Actions CI/CD pipeline
├── Dockerfile                # Multi-stage build, non-root user
├── docker-compose.yml        # Local development stack (API + nginx)
├── Makefile                  # Common tasks (build, test, run)
├── server-setup.sh           # Host provisioning helper
├── .dockerignore
├── .gitignore
└── README.md
```

---

## 5. API endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Liveness check — is the process running? |
| GET | `/ready` | Readiness check — is the process ready to serve traffic? |
| GET | `/` and application routes | Application functionality |

The `/health` and `/ready` split matters for orchestration: liveness governs whether
an instance should be restarted, readiness governs whether it should receive traffic.

---

## 6. Quick start (local)

With Docker and Docker Compose installed:

```bash
cd devops-demo-api
docker-compose up --build
```

This builds the image and starts the API behind the nginx reverse proxy. Verify it
is running:

```bash
curl http://localhost:8080/health
```

A `Makefile` provides shortcuts for common tasks (building, testing, running); see
its targets with `make help` or by reading the file.

---

## 7. The CI/CD pipeline

The GitHub Actions workflow runs on every push:

1. **Test job** — installs dependencies, runs the test suite (pytest) and the linter.
   The suite covers the application with 29 tests at 91% statement coverage. If any
   test or lint check fails, the pipeline stops here.
2. **Build job** — runs only if the test job passed. It performs the multi-stage
   Docker build and publishes the resulting image to the container registry using
   credentials supplied as encrypted CI secrets.

This ordering enforces the quality gate described in section 2: only tested code is
ever built into a publishable image.

---

## 8. Security practices

- **Multi-stage build** — the shipped image contains only runtime artifacts, not
  build tooling, reducing its attack surface.
- **Non-root container user** — least privilege applied at the container layer.
- **Secrets as CI secrets** — registry credentials are injected as encrypted secrets,
  never committed to the repository.
- **`.dockerignore`** — build context excludes files that should not enter the image.
- **Reverse proxy** — nginx sits in front of the application, the standard pattern
  for terminating connections and shielding the app server.

---

## 9. Reusing the pipeline for another project

The pipeline is written to serve as a template rather than a one-off. Adapting it to
a different application involves copying the pipeline definition, `Dockerfile`,
`docker-compose.yml`, and nginx configuration, then changing two things in the
workflow: the test command (to match the target language or framework) and the image
name. This "paved path" approach — a standardized, reusable pipeline other projects
can adopt — is a common goal of platform and DevOps teams.

---

## 10. Design notes and limitations

This is a demonstration project: a small API with a complete but single-service
pipeline. It does not include multi-environment promotion (dev/staging/prod),
integration or end-to-end test stages beyond the unit suite, infrastructure
provisioning (handled separately in an Infrastructure-as-Code project), or
deployment automation to a live cluster (handled separately in a Kubernetes
deployment project). Each of these would be a natural addition in a production
setting. The value here is a clear, correct, reusable CI/CD and containerization
baseline.

---

## 11. Requirements

- Docker and Docker Compose (for local build and run).
- Python 3.10+ (to run the application and tests outside a container).
- A GitHub repository with Actions enabled and registry credentials configured as
  secrets (to run the pipeline).

---

## 12. Further reading

- **Book:** *Continuous Delivery* (Humble & Farley) — the standard reference on
  pipeline design principles.
- **Site:** `12factor.net` — the twelve-factor app methodology, which explains the
  health-check and config-via-environment patterns used here.
- **Docs:** `docs.docker.com/build/building/multi-stage/` — Docker's multi-stage
  build documentation.
- **Docs:** `docs.github.com/en/actions` — GitHub Actions documentation, in
  particular the jobs-and-steps concepts relevant to this project's `test → build`
  structure.

---

## License

Released under the MIT License. See [LICENSE](LICENSE) for details.
