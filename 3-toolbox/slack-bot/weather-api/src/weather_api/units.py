"""Temperature units. The API stores Celsius; Fahrenheit is computed on the way out."""
from typing import Literal

Units = Literal["celsius", "fahrenheit"]


def c_to_f(celsius: float) -> int:
    """Celsius to whole-degree Fahrenheit, the way US customers read it."""
    return int(celsius * 9 / 5 + 32)


def convert(celsius: float, units: Units) -> float | int:
    if units == "fahrenheit":
        return c_to_f(celsius)
    return round(celsius, 1)
