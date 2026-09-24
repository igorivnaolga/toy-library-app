from fastapi.testclient import TestClient

from app.main import app


def test_health_ok_without_auth() -> None:
    response = TestClient(app).get("/api/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_ready_is_503_without_database(monkeypatch) -> None:
    from app.api.v1.endpoints import health

    monkeypatch.setattr(health, "get_session_factory", lambda: None)
    assert TestClient(app).get("/api/v1/health/ready").status_code == 503
