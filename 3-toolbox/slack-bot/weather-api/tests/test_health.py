def test_health_is_200(client):
    assert client.get("/health").status_code == 200


def test_health_says_ok(client):
    assert client.get("/health").json()["status"] == "ok"


def test_health_names_the_source(client):
    assert client.get("/health").json()["source"] == "fixtures"
