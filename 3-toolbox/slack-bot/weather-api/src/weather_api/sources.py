"""Where forecasts come from: offline fixtures (default) or live Open-Meteo.

WEATHER_SOURCE=fixtures (default) reads data/fixtures/<city>.json.
WEATHER_SOURCE=open-meteo calls the public Open-Meteo API (needs network).

Every parser returns the same normalized shape, so the HTTP layer never
cares about the source:

    {"city", "country", "source", "days": [{"date", "code", "max_c", "min_c", "precip_mm"}]}
"""
import json
import os
from pathlib import Path

import httpx

FIXTURES = Path(__file__).resolve().parents[2] / "data" / "fixtures"
CITIES = ["Oslo", "Iasi", "Bergen", "London", "Lisbon", "Cluj"]
GEOCODE_URL = "https://geocoding-api.open-meteo.com/v1/search"
FORECAST_URL = "https://api.open-meteo.com/v1/forecast"


class UnknownCity(KeyError):
    """The city is not one we serve."""


def list_cities() -> list[str]:
    """All supported cities, sorted alphabetically."""
    return list(CITIES)


def canonical(city: str) -> str:
    for name in CITIES:
        if name.lower() == city.strip().lower():
            return name
    raise UnknownCity(city)


def source_name() -> str:
    return os.environ.get("WEATHER_SOURCE", "fixtures")


def get_forecast(city: str) -> dict:
    name = canonical(city)
    if source_name() == "open-meteo":
        return fetch_open_meteo(name)
    return load_fixture(name)


def load_fixture(name: str) -> dict:
    payload = json.loads((FIXTURES / f"{name.lower()}.json").read_text())
    return PARSERS[payload["source"]](payload)


def parse_open_meteo(payload: dict) -> dict:
    d = payload["daily"]
    days = [
        {"date": t, "code": code, "max_c": hi, "min_c": lo, "precip_mm": p}
        for t, code, hi, lo, p in zip(
            d["time"], d["weather_code"], d["temperature_2m_max"], d["temperature_2m_min"], d["precipitation_sum"]
        )
    ]
    return {"city": payload["city"], "country": payload["country"], "source": "open-meteo", "days": days}


def parse_metno(payload: dict) -> dict:
    """met.no daily summaries.

    Short-range days (the first three) carry explicit max and min.
    Long-range days only carry a temperature range.
    """
    days = []
    for d in payload["properties"]["days"]:
        if "air_temperature_range" in d:
            max_c, min_c = d["air_temperature_range"]
        else:
            max_c, min_c = d["air_temperature_max"], d["air_temperature_min"]
        days.append(
            {"date": d["date"], "code": d["wmo_code"], "max_c": max_c, "min_c": min_c, "precip_mm": d["precipitation_amount"]}
        )
    return {"city": payload["city"], "country": payload["country"], "source": "metno", "days": days}


def fetch_open_meteo(name: str, client: httpx.Client | None = None) -> dict:
    """Live forecast. Not used on the workshop day unless Wi-Fi is good."""
    client = client or httpx.Client(timeout=10)
    place = client.get(GEOCODE_URL, params={"name": name, "count": 1}).json()["results"][0]
    data = client.get(
        FORECAST_URL,
        params={
            "latitude": place["latitude"],
            "longitude": place["longitude"],
            "daily": "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum",
            "timezone": "auto",
            "forecast_days": 7,
        },
    ).json()
    return parse_open_meteo({"city": name, "country": place.get("country_code", ""), "daily": data["daily"]})


PARSERS = {"open-meteo": parse_open_meteo, "metno": parse_metno}
