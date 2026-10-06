import pytest

ALL = ["Oslo", "Iasi", "Bergen", "London", "Lisbon", "Cluj"]


@pytest.mark.parametrize("city", ALL)
def test_seven_days_per_city(client, city):
    r = client.get("/forecast", params={"city": city})
    assert r.status_code == 200
    assert len(r.json()["days"]) == 7


def test_day_has_expected_fields(client):
    day = client.get("/forecast", params={"city": "Lisbon"}).json()["days"][0]
    assert set(day) == {"date", "condition", "advice", "max_temp", "min_temp", "precipitation_mm"}


def test_city_lookup_is_case_insensitive(client):
    assert client.get("/forecast", params={"city": "lisbon"}).json()["city"] == "Lisbon"


def test_unknown_city_is_404(client):
    assert client.get("/forecast", params={"city": "Atlantis"}).status_code == 404


def test_city_is_required(client):
    assert client.get("/forecast").status_code == 422
