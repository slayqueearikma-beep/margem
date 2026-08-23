"""Geospatial helpers for local marketplace discovery."""

from __future__ import annotations

import math

from sqlalchemy import func, literal

EARTH_RADIUS_KM = 6371.0


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle distance in kilometers between two WGS84 points."""
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lng2 - lng1)
    a = (
        math.sin(d_phi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    )
    return EARTH_RADIUS_KM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def haversine_km_sql(lat_col, lng_col, lat: float, lng: float):
    """SQLAlchemy expression: distance in km from (lat, lng) to a row."""
    lat1 = func.radians(literal(lat))
    lng1 = func.radians(literal(lng))
    lat2 = func.radians(lat_col)
    lng2 = func.radians(lng_col)
    d_lat = lat2 - lat1
    d_lng = lng2 - lng1
    inner = func.power(func.sin(d_lat / 2), 2) + func.cos(lat1) * func.cos(lat2) * func.power(
        func.sin(d_lng / 2), 2
    )
    return literal(EARTH_RADIUS_KM) * 2 * func.asin(func.sqrt(inner))
