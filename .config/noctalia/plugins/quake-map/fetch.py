#!/usr/bin/env python3
"""Fetch recent earthquakes from USGS GeoJSON."""
from __future__ import annotations

import json
import time
import urllib.request
from pathlib import Path

SETTINGS = Path.home() / ".config/noctalia/plugins/quake-map/settings.json"
GLOBE_SETTINGS = Path.home() / ".config/noctalia/plugins/news-globe/settings.json"
CACHE = Path.home() / ".cache/noctalia/quake-map-cache.json"
UA = "noctalia-quake-map/1.0"
FEEDS = {
    "2.5_day": "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_day.geojson",
    "4.5_day": "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_day.geojson",
    "significant_week": "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/significant_week.geojson",
}


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


def age(ts_ms: float) -> str:
    secs = max(0, int(time.time() - ts_ms / 1000.0))
    if secs < 60:
        return f"{secs}s"
    if secs < 3600:
        return f"{secs // 60}m"
    if secs < 86400:
        return f"{secs // 3600}h"
    return f"{secs // 86400}d"


def main() -> int:
    cfg = load_settings()
    feed_key = str(cfg.get("feed") or "2.5_day")
    url = FEEDS.get(feed_key, FEEDS["2.5_day"])
    min_mag = float(cfg.get("minMag") or 2.5)
    max_items = int(cfg.get("maxItems") or 40)

    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as exc:  # noqa: BLE001
        # serve stale cache
        try:
            cached = json.loads(CACHE.read_text(encoding="utf-8"))
            cached["errors"] = [str(exc)]
            print(json.dumps(cached))
            return 0
        except (OSError, json.JSONDecodeError):
            print(json.dumps({"quakes": [], "errors": [str(exc)], "updated": int(time.time())}))
            return 0

    quakes = []
    for feat in data.get("features") or []:
        props = feat.get("properties") or {}
        geom = feat.get("geometry") or {}
        coords = geom.get("coordinates") or [0, 0, 0]
        mag = props.get("mag")
        if mag is None:
            continue
        try:
            mag_f = float(mag)
        except (TypeError, ValueError):
            continue
        if mag_f < min_mag:
            continue
        lon, lat = float(coords[0]), float(coords[1])
        depth = float(coords[2]) if len(coords) > 2 else 0.0
        ts = float(props.get("time") or 0)
        quakes.append(
            {
                "id": props.get("code") or props.get("ids") or f"{lat},{lon},{ts}",
                "mag": mag_f,
                "place": props.get("place") or "",
                "lat": lat,
                "lon": lon,
                "depth": depth,
                "ts": ts,
                "age": age(ts),
                "url": props.get("url") or "",
                "felt": props.get("felt"),
                "tsunami": bool(props.get("tsunami")),
            }
        )

    quakes.sort(key=lambda q: q.get("ts") or 0, reverse=True)
    quakes = quakes[:max_items]
    out = {
        "quakes": quakes,
        "count": len(quakes),
        "feed": feed_key,
        "errors": [],
        "updated": int(time.time()),
    }
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    CACHE.write_text(json.dumps(out), encoding="utf-8")
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
