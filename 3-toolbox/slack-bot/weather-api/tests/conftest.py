import pytest
from fastapi.testclient import TestClient


@pytest.fixture(autouse=True)
def _isolated(tmp_path, monkeypatch):
    monkeypatch.setenv("WEATHER_LOG", str(tmp_path / "app.log"))
    monkeypatch.setenv("WEATHER_SOURCE", "fixtures")


@pytest.fixture
def client():
    from weather_api.app import app

    return TestClient(app)
