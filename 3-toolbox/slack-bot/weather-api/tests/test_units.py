import pytest

from weather_api.units import c_to_f, convert


@pytest.mark.parametrize("c, f", [(0, 32), (100, 212), (-40, -40), (20, 68), (25, 77), (-10, 14)])
def test_c_to_f(c, f):
    assert c_to_f(c) == f


def test_celsius_keeps_one_decimal():
    assert convert(10.04, "celsius") == 10.0


def test_fahrenheit_is_whole_degrees():
    assert isinstance(convert(20.0, "fahrenheit"), int)


def test_forecast_in_fahrenheit(client):
    body = client.get("/forecast", params={"city": "Lisbon", "units": "fahrenheit"}).json()
    assert body["units"] == "fahrenheit"
    assert all(isinstance(d["max_temp"], int) for d in body["days"])


def test_default_units_are_celsius(client):
    assert client.get("/forecast", params={"city": "Oslo"}).json()["units"] == "celsius"


def test_unknown_units_is_422(client):
    assert client.get("/forecast", params={"city": "Oslo", "units": "kelvin"}).status_code == 422
