# ─────────────────────────────────────────────────────────────────────────────
# Dockerfile — devops-demo-api
# Multi-stage build: keeps the final image small and secure
#
# WHY MULTI-STAGE?
# Stage 1 (builder): install ALL deps including dev tools
# Stage 2 (runtime): copy only what's needed to RUN the app
# Result: final image is ~3x smaller, no build tools exposed in production
#
# Build:  docker build -t devops-demo-api .
# Run:    docker run -p 5000:5000 devops-demo-api
# ─────────────────────────────────────────────────────────────────────────────

# ── Stage 1: Builder ──────────────────────────────────────────────────────────
FROM python:3.12-slim AS builder

# Don't write .pyc files, don't buffer stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /build

# Copy requirements first — Docker caches this layer.
# If requirements.txt doesn't change, this RUN is skipped on rebuild.
# Always copy requirements before source code for faster rebuilds.
COPY app/requirements.txt .

RUN pip install --upgrade pip && \
    pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    ENVIRONMENT=production \
    PORT=5000

# Create a non-root user — NEVER run apps as root in containers
# This limits blast radius if the container is compromised
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid appgroup --shell /bin/bash --create-home appuser

WORKDIR /app

# Copy installed packages from builder stage
COPY --from=builder /install /usr/local

# Copy application source code
COPY app/main.py .

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose the port the app listens on
EXPOSE 5000

# Health check — Docker itself will ping this every 30s
# If it fails 3 times, the container is marked "unhealthy"
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

# Use gunicorn (production WSGI server), not Flask's dev server
# -w 2: 2 worker processes (adjust based on CPU cores: 2 * cores + 1)
# -b: bind to all interfaces on PORT
# --access-logfile -: log to stdout (captured by container runtime)
CMD ["sh", "-c", "gunicorn -w 2 -b 0.0.0.0:${PORT} main:app --access-logfile - --error-logfile -"]
