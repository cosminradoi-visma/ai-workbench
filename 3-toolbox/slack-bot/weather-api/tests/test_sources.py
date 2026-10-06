import json

import httpx

from weather_api import sources


def test_every_city_has_a_fixture():
    for name in sources.list_cities():
        assert (sources.FIXTURES / f"{name.lower()}.json").exists()


def test_open_meteo_parser_normalizes():
    payload = {
        "city": "Testville",
        "country": "XX",
        "daily": {
            "time": ["2026-01-01"],
            "weather_code": [3],
            "temperature_2m_max": [4.5],
            "temperature_2m_min": [-1.0],
            "precipitation_sum": [0.0],
        },
    }
    out = sources.parse_open_meteo(payload)
    assert out["days"] == [{"date": "2026-01-01", "code": 3, "max_c": 4.5, "min_c": -1.0, "precip_mm": 0.0}]


def test_bergen_comes_from_metno():
    assert sources.get_forecast("Bergen")["source"] == "metno"


def test_metno_short_range_day():
    payload = json.loads((sources.FIXTURES / "bergen.json").read_text())
    first = sources.parse_metno(payload)["days"][0]
    assert (first["max_c"], first["min_c"]) == (11.2, 7.4)


def test_live_source_is_parsed_without_network():
    def handler(request: httpx.Request) -> httpx.Response:
        if "geocoding" in request.url.host:
            return httpx.Response(200, json={"results": [{"latitude": 1.0, "longitude": 2.0, "country_code": "NO"}]})
        return httpx.Response(
            200,
            json={
                "daily": {
                    "time": ["2026-01-01"],
                    "weather_code": [0],
                    "temperature_2m_max": [1.0],
                    "temperature_2m_min": [-2.0],
                    "precipitation_sum": [0.0],
                }
            },
        )

    out = sources.fetch_open_meteo("Oslo", client=httpx.Client(transport=httpx.MockTransport(handler)))
    assert out["country"] == "NO"
    assert out["days"][0]["max_c"] == 1.0
