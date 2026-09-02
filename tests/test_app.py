# Tests RONIN's Flask endpoints, read-only behaviour, and security headers so core application behaviour is verified before a Docker image is deployed.

from app import create_app


def client():
    return create_app({"TESTING": True}).test_client()


def test_health():
    response = client().get("/health")

    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_read_only_apis():
    for path in (
        "/api/status",
        "/api/resources",
        "/api/findings",
        "/api/costs",
    ):
        assert client().get(path).status_code == 200

    assert client().get("/api/status").get_json()["connected_to_aws"] is False
    assert client().post("/api/resources").status_code == 405


def test_headers():
    response = client().get("/")

    assert response.headers["X-Frame-Options"] == "DENY"