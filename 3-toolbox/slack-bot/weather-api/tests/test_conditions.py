import pytest

from weather_api.conditions import advice_for, condition_for


@pytest.mark.parametrize(
    "code, expected",
    [
        (0, "sunny"),
        (1, "partly cloudy"),
        (2, "partly cloudy"),
        (3, "cloudy"),
        (45, "fog"),
        (53, "drizzle"),
        (71, "snow"),
        (81, "showers"),
        (95, "thunderstorm"),
        (42, "unknown"),
    ],
)
def test_condition_for(code, expected):
    assert condition_for(code) == expected


def test_wet_condition_needs_umbrella():
    assert advice_for("showers") == "take an umbrella"


def test_dry_condition_needs_no_umbrella():
    assert advice_for("sunny") == "no umbrella needed"
