#!/usr/bin/env python3
"""ISS position + SGP4/TLE orbital trail (last ~1.1 revs). No system pip needed."""
from __future__ import annotations

import json
import math
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

PLUGIN = Path(__file__).resolve().parent
sys.path.insert(0, str(PLUGIN / "vendor"))

from sgp4.api import Satrec, jday  # noqa: E402

SETTINGS = PLUGIN / "settings.json"
GLOBE_SETTINGS = Path.home() / ".config/noctalia/plugins/news-globe/settings.json"
CACHE = Path.home() / ".cache/noctalia/iss-track-cache.json"
UA = "noctalia-iss-track/1.1"
ISS_URL = "https://api.wheretheiss.at/v1/satellites/25544"
TLE_URL = "https://api.wheretheiss.at/v1/satellites/25544/tles"
CELESTRAK_TLE = "https://celestrak.org/NORAD/elements/gp.php?CATNR=25544&FORMAT=TLE"

# ~93 min ISS period; sample every 25s → ~280 pts (smooth, lighter on QML)
ORBIT_SEC = int(93 * 60 * 1.05)
STEP_SEC = 25
FUTURE_SEC = 12 * 60  # short look-ahead so trail leads the craft a bit
TLE_MAX_AGE = 6 * 3600


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


def load_cache() -> dict:
    try:
        data = json.loads(CACHE.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def save_cache(data: dict) -> None:
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    CACHE.write_text(json.dumps(data), encoding="utf-8")


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return 2 * r * math.asin(min(1.0, math.sqrt(a)))


def bearing_deg(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dl = math.radians(lon2 - lon1)
    y = math.sin(dl) * math.cos(p2)
    x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl)
    return (math.degrees(math.atan2(y, x)) + 360.0) % 360.0


def fetch_json(url: str, timeout: int = 20) -> dict | list | str:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read().decode("utf-8")
        ctype = (resp.headers.get("Content-Type") or "").lower()
        if "json" in ctype or raw.lstrip().startswith(("{", "[")):
            return json.loads(raw)
        return raw


def fetch_tle(cache: dict) -> tuple[str, str, int]:
    """Return (line1, line2, fetched_ts). Prefer cache if fresh."""
    cached_l1 = cache.get("tle_line1")
    cached_l2 = cache.get("tle_line2")
    fetched = int(cache.get("tle_fetched") or 0)
    if cached_l1 and cached_l2 and time.time() - fetched < TLE_MAX_AGE:
        return str(cached_l1), str(cached_l2), fetched

    # 1) wheretheiss JSON
    try:
        data = fetch_json(TLE_URL, timeout=15)
        if isinstance(data, dict) and data.get("line1") and data.get("line2"):
            return str(data["line1"]).strip(), str(data["line2"]).strip(), int(time.time())
    except Exception:  # noqa: BLE001
        pass

    # 2) CelesTrak plain TLE
    try:
        raw = fetch_json(CELESTRAK_TLE, timeout=15)
        text = raw if isinstance(raw, str) else str(raw)
        lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
        # Usually: name, line1, line2
        l1 = next((ln for ln in lines if ln.startswith("1 ")), "")
        l2 = next((ln for ln in lines if ln.startswith("2 ")), "")
        if l1 and l2:
            return l1, l2, int(time.time())
    except Exception:  # noqa: BLE001
        pass

    if cached_l1 and cached_l2:
        return str(cached_l1), str(cached_l2), fetched
    raise RuntimeError("no TLE available")


def gmst_rad(jd: float) -> float:
    """Greenwich mean sidereal time (rad) for Julian date."""
    t = (jd - 2451545.0) / 36525.0
    gmst = (
        280.46061837
        + 360.98564736629 * (jd - 2451545.0)
        + 0.000387933 * t * t
        - (t * t * t) / 38710000.0
    )
    return math.radians(gmst % 360.0)


def teme_to_lla(r_km: tuple[float, float, float], jd: float) -> tuple[float, float, float]:
    """TEME position (km) → geodetic lat, lon (deg), alt (km). WGS-84."""
    x, y, z = r_km
    theta = gmst_rad(jd)
    c, s = math.cos(theta), math.sin(theta)
    xe = c * x + s * y
    ye = -s * x + c * y
    ze = z

    lon = math.atan2(ye, xe)
    hyp = math.hypot(xe, ye)
    a = 6378.137
    e2 = 6.69437999014e-3
    lat = math.atan2(ze, hyp * (1.0 - e2))
    for _ in range(8):
        sin_lat = math.sin(lat)
        n = a / math.sqrt(1.0 - e2 * sin_lat * sin_lat)
        lat = math.atan2(ze + e2 * n * sin_lat, hyp)
    sin_lat = math.sin(lat)
    n = a / math.sqrt(1.0 - e2 * sin_lat * sin_lat)
    alt = hyp / max(1e-9, math.cos(lat)) - n
    return math.degrees(lat), (math.degrees(lon) + 540.0) % 360.0 - 180.0, alt


def unix_to_jd(ts: float) -> tuple[float, float]:
    dt = datetime.fromtimestamp(ts, tz=timezone.utc)
    return jday(
        dt.year,
        dt.month,
        dt.day,
        dt.hour,
        dt.minute,
        dt.second + dt.microsecond * 1e-6,
    )


def propagate(sat: Satrec, ts: float) -> dict | None:
    jd, fr = unix_to_jd(ts)
    err, r, v = sat.sgp4(jd, fr)
    if err != 0 or r is None:
        return None
    lat, lon, alt = teme_to_lla((float(r[0]), float(r[1]), float(r[2])), jd + fr)
    speed = 0.0
    if v is not None:
        speed = math.sqrt(float(v[0]) ** 2 + float(v[1]) ** 2 + float(v[2]) ** 2)  # km/s
    return {
        "lat": round(lat, 4),
        "lon": round(lon, 4),
        "alt": round(alt, 2),
        "ts": int(ts),
        "velocity": round(speed * 3600.0, 1),  # km/h
    }


def build_trail(sat: Satrec, now: float) -> list[dict]:
    start = now - ORBIT_SEC
    end = now + FUTURE_SEC
    trail: list[dict] = []
    t = start
    while t <= end + 0.5:
        pt = propagate(sat, t)
        if pt:
            trail.append(pt)
        t += STEP_SEC
    return trail


def main() -> int:
    cfg = load_settings()
    home_lat = float(cfg.get("homeLat") or 7.73)
    home_lon = float(cfg.get("homeLon") or 81.70)
    cache = load_cache()
    errors: list[str] = []
    now = time.time()

    try:
        line1, line2, tle_fetched = fetch_tle(cache)
        sat = Satrec.twoline2rv(line1, line2)
    except Exception as exc:  # noqa: BLE001
        out = {
            "ok": False,
            "errors": [f"tle: {exc}"],
            "trail": cache.get("trail") or [],
            "home": {"lat": home_lat, "lon": home_lon},
            "updated": int(now),
        }
        if cache.get("lat") is not None:
            for k in (
                "lat",
                "lon",
                "altitude",
                "velocity",
                "visibility",
                "footprint",
                "dist_km",
                "bearing",
                "visible_now",
                "eta_min",
            ):
                if k in cache:
                    out[k] = cache[k]
            out["ok"] = True
            out["stale"] = True
        print(json.dumps(out))
        return 0

    here = propagate(sat, now)
    if not here:
        errors.append("sgp4 failed at now")
        print(
            json.dumps(
                {
                    "ok": False,
                    "errors": errors,
                    "trail": cache.get("trail") or [],
                    "home": {"lat": home_lat, "lon": home_lon},
                    "updated": int(now),
                }
            )
        )
        return 0

    lat, lon, alt = here["lat"], here["lon"], here["alt"]
    vel = here.get("velocity") or 0.0

    # Rebuild trail often — local SGP4 is free vs API batches
    trail_age = now - float(cache.get("trail_built") or 0)
    trail = list(cache.get("trail") or [])
    if trail_age > 90 or len(trail) < 80:
        trail = build_trail(sat, now)
        cache["trail_built"] = int(now)
    else:
        # splice current + drop points older than window
        cutoff = now - ORBIT_SEC - 30
        trail = [p for p in trail if float(p.get("ts") or 0) >= cutoff]
        # refresh last segment from ~2 min ago → now + future
        rebuild_from = now - 150
        trail = [p for p in trail if float(p.get("ts") or 0) < rebuild_from]
        t = rebuild_from
        while t <= now + FUTURE_SEC + 0.5:
            pt = propagate(sat, t)
            if pt:
                trail.append(pt)
            t += STEP_SEC

    trail.sort(key=lambda p: p.get("ts") or 0)

    # Optional visibility / footprint from wheretheiss (non-critical)
    visibility = str(cache.get("visibility") or "")
    footprint = float(cache.get("footprint") or 0)
    try:
        iss = fetch_json(ISS_URL, timeout=8)
        if isinstance(iss, dict):
            visibility = str(iss.get("visibility") or visibility)
            footprint = float(iss.get("footprint") or footprint or 0)
    except Exception as exc:  # noqa: BLE001
        errors.append(f"iss meta: {exc}")

    dist = haversine_km(home_lat, home_lon, lat, lon)
    brg = bearing_deg(home_lat, home_lon, lat, lon)
    radius = max(footprint * 0.5, 800.0)
    visible_now = dist <= radius and visibility != "eclipsed"

    eta_min = None
    if len(trail) >= 8 and not visible_now:
        # find soonest future trail point inside footprint radius
        for p in trail:
            ts = float(p.get("ts") or 0)
            if ts < now:
                continue
            d = haversine_km(home_lat, home_lon, float(p["lat"]), float(p["lon"]))
            if d <= radius:
                eta_min = int(max(0, (ts - now) / 60.0))
                if eta_min > 120:
                    eta_min = None
                break

    out = {
        "ok": True,
        "lat": lat,
        "lon": lon,
        "altitude": alt,
        "velocity": vel,
        "visibility": visibility,
        "footprint": footprint,
        "dist_km": round(dist),
        "bearing": round(brg),
        "visible_now": visible_now,
        "eta_min": eta_min,
        "trail": trail,
        "trail_count": len(trail),
        "source": "sgp4",
        "home": {"lat": home_lat, "lon": home_lon},
        "url": "https://spotthestation.nasa.gov/",
        "errors": errors,
        "updated": int(now),
        "trail_built": cache.get("trail_built"),
        "tle_line1": line1,
        "tle_line2": line2,
        "tle_fetched": tle_fetched,
    }
    # Cache without dumping huge duplicate every time is fine
    save_cache(out)
    # Don't spam TLE into stdout for QML
    slim = {k: v for k, v in out.items() if k not in ("tle_line1", "tle_line2")}
    print(json.dumps(slim))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
