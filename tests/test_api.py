"""
Test suite for devops-demo-api

These tests run automatically in the CI/CD pipeline on every push.
If ANY test fails, the pipeline stops — no bad code gets deployed.

This is the core value of CI: catching bugs before they reach users.

Run locally:
    cd devops-project-1
    pip install -r app/requirements.txt
    pytest tests/ -v --cov=app
"""

import json
import sys
import os

# Make sure the app module is importable from tests/
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "app"))

import pytest
from main import app, TASKS


@pytest.fixture
def client():
    """
    pytest fixture: creates a fresh test client for each test.
    Flask's test client lets us make HTTP requests without a real server.
    """
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


# ── Health Endpoint Tests ──────────────────────────────────────────────────────

class TestHealthEndpoints:

    def test_health_returns_200(self, client):
        """Health check must always return 200 — this is what K8s checks."""
        response = client.get("/health")
        assert response.status_code == 200

    def test_health_returns_healthy_status(self, client):
        data = json.loads(client.get("/health").data)
        assert data["status"] == "healthy"

    def test_health_includes_timestamp(self, client):
        data = json.loads(client.get("/health").data)
        assert "timestamp" in data

    def test_health_includes_uptime(self, client):
        data = json.loads(client.get("/health").data)
        assert "uptime_seconds" in data
        assert data["uptime_seconds"] >= 0

    def test_readiness_returns_200(self, client):
        response = client.get("/ready")
        assert response.status_code == 200

    def test_readiness_is_ready(self, client):
        data = json.loads(client.get("/ready").data)
        assert data["ready"] is True


# ── Root & Info Endpoint Tests ─────────────────────────────────────────────────

class TestInfoEndpoints:

    def test_root_returns_200(self, client):
        response = client.get("/")
        assert response.status_code == 200

    def test_root_returns_service_name(self, client):
        data = json.loads(client.get("/").data)
        assert data["service"] == "devops-demo-api"

    def test_root_includes_version(self, client):
        data = json.loads(client.get("/").data)
        assert "version" in data

    def test_root_includes_endpoints_map(self, client):
        data = json.loads(client.get("/").data)
        assert "endpoints" in data
        assert "/health" in data["endpoints"].values() or "health" in str(data["endpoints"])

    def test_info_returns_200(self, client):
        response = client.get("/info")
        assert response.status_code == 200

    def test_info_includes_python_version(self, client):
        data = json.loads(client.get("/info").data)
        assert "python_version" in data

    def test_info_includes_environment(self, client):
        data = json.loads(client.get("/info").data)
        assert "environment" in data


# ── Task API Tests ─────────────────────────────────────────────────────────────

class TestTasksAPI:

    def test_get_all_tasks_returns_200(self, client):
        response = client.get("/api/tasks")
        assert response.status_code == 200

    def test_get_all_tasks_returns_list(self, client):
        data = json.loads(client.get("/api/tasks").data)
        assert "tasks" in data
        assert isinstance(data["tasks"], list)

    def test_get_all_tasks_includes_count(self, client):
        data = json.loads(client.get("/api/tasks").data)
        assert "count" in data
        assert data["count"] == len(data["tasks"])

    def test_get_task_by_id(self, client):
        response = client.get("/api/tasks/1")
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data["id"] == 1

    def test_get_nonexistent_task_returns_404(self, client):
        response = client.get("/api/tasks/99999")
        assert response.status_code == 404

    def test_filter_tasks_by_done_true(self, client):
        response = client.get("/api/tasks?done=true")
        assert response.status_code == 200
        data = json.loads(response.data)
        for task in data["tasks"]:
            assert task["done"] is True

    def test_filter_tasks_by_done_false(self, client):
        response = client.get("/api/tasks?done=false")
        assert response.status_code == 200
        data = json.loads(response.data)
        for task in data["tasks"]:
            assert task["done"] is False

    def test_create_task_returns_201(self, client):
        response = client.post(
            "/api/tasks",
            data=json.dumps({"title": "Test task from CI"}),
            content_type="application/json",
        )
        assert response.status_code == 201

    def test_create_task_returns_task_object(self, client):
        response = client.post(
            "/api/tasks",
            data=json.dumps({"title": "Another test task"}),
            content_type="application/json",
        )
        data = json.loads(response.data)
        assert "id" in data
        assert data["title"] == "Another test task"
        assert data["done"] is False

    def test_create_task_without_title_returns_400(self, client):
        response = client.post(
            "/api/tasks",
            data=json.dumps({}),
            content_type="application/json",
        )
        assert response.status_code == 400

    def test_update_task_done_status(self, client):
        # Create a task first
        create_resp = client.post(
            "/api/tasks",
            data=json.dumps({"title": "Task to complete"}),
            content_type="application/json",
        )
        task_id = json.loads(create_resp.data)["id"]

        # Now mark it done
        update_resp = client.patch(
            f"/api/tasks/{task_id}",
            data=json.dumps({"done": True}),
            content_type="application/json",
        )
        assert update_resp.status_code == 200
        data = json.loads(update_resp.data)
        assert data["done"] is True

    def test_delete_task(self, client):
        # Create a task
        create_resp = client.post(
            "/api/tasks",
            data=json.dumps({"title": "Task to delete"}),
            content_type="application/json",
        )
        task_id = json.loads(create_resp.data)["id"]

        # Delete it
        delete_resp = client.delete(f"/api/tasks/{task_id}")
        assert delete_resp.status_code == 200

        # Verify it's gone
        get_resp = client.get(f"/api/tasks/{task_id}")
        assert get_resp.status_code == 404

    def test_delete_nonexistent_task_returns_404(self, client):
        response = client.delete("/api/tasks/99999")
        assert response.status_code == 404


# ── Error Handler Tests ────────────────────────────────────────────────────────

class TestErrorHandlers:

    def test_unknown_route_returns_404(self, client):
        response = client.get("/this/does/not/exist")
        assert response.status_code == 404

    def test_404_response_is_json(self, client):
        response = client.get("/nonexistent")
        data = json.loads(response.data)
        assert "error" in data

    def test_wrong_method_returns_405(self, client):
        # GET /api/tasks/:id with DELETE body - actually test a truly wrong method
        response = client.put("/health")
        assert response.status_code == 405
