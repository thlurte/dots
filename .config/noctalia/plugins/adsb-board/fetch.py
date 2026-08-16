#!/usr/bin/env python3
"""Aircraft near home via dump1090 JSON or OpenSky Network."""
from __future__ import annotations

import json
import math
import time
import urllib.error
import urllib.request
from pathlib import Path

SETTINGS = Path.home() / ".config/noctalia/plugins/adsb-board/settings.json"
GLOBE_SETTINGS = Path.home() / ".config/noctalia/plugins/news-globe/settings.json"
CACHE = Path.home() / ".cache/noctalia/adsb-board-cache.json"
UA = "noctalia-adsb-board/1.0"


def load_settings() -> dict:
    cfg: dict = {}
    for path in (SETTINGS, GLOBE_SETTINGS):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                cfg.update(data)
        except (OSError, json.JSONDecodeError):
            pass
    return cfg


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return 2 * r * math.asin(min(1.0, math.sqrt(a)))


def fetch_json(url: str, timeout: int = 15) -> dict | list:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def from_dump1090(data: dict, home_lat: float, home_lon: float, radius_km: float) -> list[dict]:
    out = []
    for ac in data.get("aircraft") or []:
        lat, lon = ac.get("lat"), ac.get("lon")
        if lat is None or lon is None:
            continue
        lat_f, lon_f = float(lat), float(lon)
        dist = haversine_km(home_lat, home_lon, lat_f, lon_f)
        if dist > radius_km:
            continue
        out.append(
            {
                "id": ac.get("hex") or f"{lat_f},{lon_f}",
                "callsign": (ac.get("flight") or ac.get("hex") or "?").strip(),
                "lat": lat_f,
                "lon": lon_f,
                "alt": ac.get("alt_baro") or ac.get("alt_geom") or ac.get("altitude"),
                "gs": ac.get("gs") or ac.get("speed"),
                "track": ac.get("track") or ac.get("true_heading") or 0,
                "dist_km": round(dist),
                "source": "dump1090",
            }
        )
    return out


def from_opensky(data: dict, home_lat: float, home_lon: float, radius_km: float) -> list[dict]:
    out = []
    for st in data.get("states") or []:
        # [icao24, callsign, origin, time, last, lon, lat, baro, on_ground, vel, true_track, ...]
        if len(st) < 11:
            continue
        lon, lat = st[5], st[6]
        if lon is None or lat is None:
            continue
        if st[8]:  # on ground
            continue
        lat_f, lon_f = float(lat), float(lon)
        dist = haversine_km(home_lat, home_lon, lat_f, lon_f)
        if dist > radius_km:
            continue
        callsign = (st[1] or st[0] or "?").strip()
        out.append(
            {
                "id": st[0] or callsign,
                "callsign": callsign,
                "lat": lat_f,
                "lon": lon_f,
                "alt": st[7],
                "gs": st[9],
                "track": st[10] or 0,
                "dist_km": round(dist),
                "source": "opensky",
            }
        )
    return out


def main() -> int:
    cfg = load_settings()
    home_lat = float(cfg.get("homeLat") or 7.73)
    home_lon = float(cfg.get("homeLon") or 81.70)
    radius_km = float(cfg.get("radiusKm") or 800)
    dump_url = str(cfg.get("dump1090Url") or "").strip()
    max_items = int(cfg.get("maxItems") or 60)

    # bbox for OpenSky (~radius)
    dlat = radius_km / 111.0
    dlon = radius_km / max(111.0 * math.cos(math.radians(home_lat)), 30.0)
    lamin, lamax = home_lat - dlat, home_lat + dlat
    lomin, lomax = home_lon - dlon, home_lon + dlon

    planes: list[dict] = []
    source = ""
    errors: list[str] = []

    if dump_url:
        try:
            data = fetch_json(dump_url)
            planes = from_dump1090(data if isinstance(data, dict) else {}, home_lat, home_lon, radius_km)
            source = "dump1090"
        except Exception as exc:  # noqa: BLE001
            errors.append(f"dump1090: {exc}")

    if not planes:
        url = (
            "https://opensky-network.org/api/states/all"
            f"?lamin={lamin:.3f}&lomin={lomin:.3f}&lamax={lamax:.3f}&lomax={lomax:.3f}"
        )
        try:
            data = fetch_json(url)
            planes = from_opensky(data if isinstance(data, dict) else {}, home_lat, home_lon, radius_km)
            source = "opensky"
        except urllib.error.HTTPError as exc:
            errors.append(f"opensky HTTP {exc.code}")
        except Exception as exc:  # noqa: BLE001
            errors.append(f"opensky: {exc}")

    planes.sort(key=lambda p: p.get("dist_km") or 9999)
    planes = planes[:max_items]

    out = {
        "planes": planes,
        "count": len(planes),
        "source": source,
        "home": {"lat": home_lat, "lon": home_lon},
        "radius_km": radius_km,
        "errors": errors[:2],
        "updated": int(time.time()),
    }

    if not planes and errors:
        try:
            cached = json.loads(CACHE.read_text(encoding="utf-8"))
            cached["errors"] = errors[:2]
            cached["stale"] = True
            print(json.dumps(cached))
            return 0
        except (OSError, json.JSONDecodeError):
            pass

    CACHE.parent.mkdir(parents=True, exist_ok=True)
    CACHE.write_text(json.dumps(out), encoding="utf-8")
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
