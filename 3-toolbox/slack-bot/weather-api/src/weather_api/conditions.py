"""WMO weather interpretation codes -> a condition word, plus umbrella advice.

Code table: https://open-meteo.com/en/docs (WMO Weather interpretation codes).
"""

# (first code, last code, condition), checked top to bottom.
WMO_TABLE = (
    (0, 0, "sunny"),
    (1, 2, "partly cloudy"),
    (3, 3, "cloudy"),
    (45, 48, "fog"),
    (51, 57, "drizzle"),
    (61, 65, "sunny"),
    (66, 67, "rain"),
    (71, 77, "snow"),
    (80, 82, "showers"),
    (85, 86, "snow showers"),
    (95, 99, "thunderstorm"),
)

WET = {"drizzle", "rain", "showers", "snow", "snow showers", "thunderstorm"}


def condition_for(code: int) -> str:
    for first, last, condition in WMO_TABLE:
        if first <= code <= last:
            return condition
    return "unknown"


def advice_for(condition: str) -> str:
    return "take an umbrella" if condition in WET else "no umbrella needed"
