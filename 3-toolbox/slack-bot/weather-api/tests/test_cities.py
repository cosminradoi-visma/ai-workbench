import pytest

from weather_api import sources

ALL = ["Oslo", "Iasi", "Bergen", "London", "Lisbon", "Cluj"]


def test_cities_returns_six(client):
    assert len(client.get("/cities").json()["cities"]) == 6


@pytest.mark.parametrize("name", ALL)
def test_city_is_listed(client, name):
    assert name in client.get("/cities").json()["cities"]


def test_canonical_is_case_insensitive():
    assert sources.canonical("  bErGeN ") == "Bergen"


def test_unknown_city_raises():
    with pytest.raises(sources.UnknownCity):
        sources.canonical("Atlantis")
