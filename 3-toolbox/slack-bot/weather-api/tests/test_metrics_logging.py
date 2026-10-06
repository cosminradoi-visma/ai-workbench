import json
import os
from pathlib import Path


def test_metrics_count_requests(client):
    before = client.get("/metrics").json()["requests_total"]
    client.get("/health")
    assert client.get("/metrics").json()["requests_total"] >= before + 2


def test_metrics_count_errors(client):
    before = client.get("/metrics").json()["errors_total"]
    client.get("/forecast", params={"city": "Atlantis"})
    assert client.get("/metrics").json()["errors_total"] == before + 1


def test_request_is_logged_as_json(client):
    client.get("/forecast", params={"city": "Cluj"})
    lines = Path(os.environ["WEATHER_LOG"]).read_text().splitlines()
    last = json.loads(lines[-1])
    assert last["path"] == "/forecast"
    assert last["city"] == "Cluj"
    assert last["status"] == 200
    assert set(last) == {"ts", "path", "city", "status", "ms"}
