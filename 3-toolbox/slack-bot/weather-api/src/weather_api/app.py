"""HTTP layer for weather-api."""
import time
from pathlib import Path

from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.responses import HTMLResponse

from . import conditions, sources, units
from .logging import log_request
from .units import Units

app = FastAPI(title="weather-api", version="0.7.0")
PAGE = Path(__file__).parent / "static" / "index.html"
METRICS: dict = {"requests_total": 0, "errors_total": 0, "by_status": {}}


@app.middleware("http")
async def access_log(request: Request, call_next):
    start = time.perf_counter()
    status = 500
    try:
        response = await call_next(request)
        status = response.status_code
        return response
    finally:
        ms = round((time.perf_counter() - start) * 1000, 1)
        METRICS["requests_total"] += 1
        METRICS["by_status"][str(status)] = METRICS["by_status"].get(str(status), 0) + 1
        if status >= 400:
            METRICS["errors_total"] += 1
        log_request(request.url.path, request.query_params.get("city"), status, ms)


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "source": sources.source_name()}


@app.get("/metrics")
def metrics() -> dict:
    """Request and error counters since start."""
    return METRICS


@app.get("/cities")
def cities() -> dict:
    """All cities we have forecasts for."""
    return {"cities": sources.list_cities()}


@app.get("/forecast")
def forecast(city: str, units_: Units = Query("celsius", alias="units")) -> dict:
    """Seven-day forecast for one city, in celsius (default) or fahrenheit."""
    try:
        raw = sources.get_forecast(city)
    except sources.UnknownCity:
        raise HTTPException(status_code=404, detail=f"unknown city: {city}")
    days = []
    for d in raw["days"]:
        condition = conditions.condition_for(d["code"])
        days.append({
            "date": d["date"],
            "condition": condition,
            "advice": conditions.advice_for(condition),
            "max_temp": units.convert(d["max_c"], units_),
            "min_temp": units.convert(d["min_c"], units_),
            "precipitation_mm": d["precip_mm"],
        })
    return {
        "city": raw["city"],
        "country": raw["country"],
        "units": units_,
        "source": raw["source"],
        "days": days,
    }


@app.get("/", response_class=HTMLResponse)
def page() -> str:
    """A small forecast page (plain HTML + fetch), for UI testing in a browser."""
    return PAGE.read_text()
