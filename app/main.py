"""
DevOps Portfolio Project #1
Auto-Deploy Web App with CI/CD Pipeline

A simple but real Flask API that demonstrates:
- Health check endpoints (what every real service needs)
- Versioned API responses
- Structured JSON responses
- Error handling

This app is the SUBJECT of our CI/CD pipeline — not the point itself.
The pipeline (GitHub Actions + Docker + deployment) is the portfolio piece.
"""

import os
import time
import platform
from datetime import datetime, timezone

from flask import Flask, jsonify, request
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Read version from environment variable (set at build time by CI/CD)
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
BUILD_TIME = os.getenv("BUILD_TIME", "local")
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")

START_TIME = time.time()


# ── Health & Status Endpoints ──────────────────────────────────────────────────

@app.route("/health", methods=["GET"])
def health():
    """
    Health check endpoint.
    
    This is what load balancers and container orchestrators ping
    to know if your app is alive. Kubernetes readiness/liveness probes
    hit this endpoint. Always return 200 if the app is healthy.
    """
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "uptime_seconds": round(time.time() - START_TIME, 2),
    }), 200


@app.route("/ready", methods=["GET"])
def readiness():
    """
    Readiness check — is the app ready to serve traffic?
    
    In a real app, you'd check: database connectivity, cache availability,
    external service dependencies. Here we keep it simple.
    Kubernetes separates liveness (/health) from readiness (/ready).
    """
    # Simulate a readiness check (e.g., DB ping)
    checks = {
        "app": "ok",
        "environment": ENVIRONMENT,
    }
    return jsonify({"ready": True, "checks": checks}), 200


@app.route("/", methods=["GET"])
def index():
    """Root endpoint — basic info about this service."""
    return jsonify({
        "service": "devops-demo-api",
        "version": APP_VERSION,
        "environment": ENVIRONMENT,
        "build_time": BUILD_TIME,
        "message": "CI/CD pipeline deployed this automatically ✓",
        "endpoints": {
            "health": "/health",
            "readiness": "/ready",
            "info": "/info",
            "tasks": "/api/tasks",
        },
    }), 200


@app.route("/info", methods=["GET"])
def info():
    """System info endpoint — useful for debugging deployments."""
    return jsonify({
        "version": APP_VERSION,
        "environment": ENVIRONMENT,
        "build_time": BUILD_TIME,
        "python_version": platform.python_version(),
        "platform": platform.system(),
        "uptime_seconds": round(time.time() - START_TIME, 2),
        "server_time": datetime.now(timezone.utc).isoformat(),
    }), 200


# ── Business Logic (Task API) ──────────────────────────────────────────────────
# A simple in-memory task list — enough to demonstrate CRUD API patterns
# In a real app this would be a database.

TASKS = [
    {"id": 1, "title": "Learn Docker", "done": True},
    {"id": 2, "title": "Set up GitHub Actions CI/CD", "done": True},
    {"id": 3, "title": "Deploy to cloud", "done": False},
    {"id": 4, "title": "Add monitoring", "done": False},
]
_next_id = 5


@app.route("/api/tasks", methods=["GET"])
def get_tasks():
    """List all tasks. Supports ?done=true/false filter."""
    done_filter = request.args.get("done")
    if done_filter is not None:
        filtered = [t for t in TASKS if str(t["done"]).lower() == done_filter.lower()]
        return jsonify({"tasks": filtered, "count": len(filtered)}), 200
    return jsonify({"tasks": TASKS, "count": len(TASKS)}), 200


@app.route("/api/tasks/<int:task_id>", methods=["GET"])
def get_task(task_id):
    """Get a single task by ID."""
    task = next((t for t in TASKS if t["id"] == task_id), None)
    if not task:
        return jsonify({"error": f"Task {task_id} not found"}), 404
    return jsonify(task), 200


@app.route("/api/tasks", methods=["POST"])
def create_task():
    """Create a new task."""
    global _next_id
    data = request.get_json()
    if not data or "title" not in data:
        return jsonify({"error": "Request body must include 'title'"}), 400

    task = {"id": _next_id, "title": data["title"], "done": False}
    TASKS.append(task)
    _next_id += 1
    return jsonify(task), 201


@app.route("/api/tasks/<int:task_id>", methods=["PATCH"])
def update_task(task_id):
    """Mark a task done or update its title."""
    task = next((t for t in TASKS if t["id"] == task_id), None)
    if not task:
        return jsonify({"error": f"Task {task_id} not found"}), 404

    data = request.get_json() or {}
    if "done" in data:
        task["done"] = bool(data["done"])
    if "title" in data:
        task["title"] = data["title"]
    return jsonify(task), 200


@app.route("/api/tasks/<int:task_id>", methods=["DELETE"])
def delete_task(task_id):
    """Delete a task."""
    global TASKS
    task = next((t for t in TASKS if t["id"] == task_id), None)
    if not task:
        return jsonify({"error": f"Task {task_id} not found"}), 404
    TASKS = [t for t in TASKS if t["id"] != task_id]
    return jsonify({"deleted": task_id}), 200


# ── Error Handlers ─────────────────────────────────────────────────────────────

@app.errorhandler(404)
def not_found(e):
    return jsonify({"error": "Not found", "path": request.path}), 404


@app.errorhandler(405)
def method_not_allowed(e):
    return jsonify({"error": "Method not allowed"}), 405


@app.errorhandler(500)
def server_error(e):
    return jsonify({"error": "Internal server error"}), 500


# ── Entry Point ────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    debug = ENVIRONMENT == "development"
    print(f"Starting devops-demo-api v{APP_VERSION} on port {port} [{ENVIRONMENT}]")
    app.run(host="0.0.0.0", port=port, debug=debug)
