#!/usr/bin/env python3
"""Build globe weather overlays: rain radar, SST/ocean, and wind samples."""
from __future__ import annotations

import io
import json
import math
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

CACHE = Path.home() / ".cache/noctalia/news-globe"
RAIN_PATH = CACHE / "rain.png"
OCEAN_PATH = CACHE / "ocean.png"
UA = "noctalia-news-globe/1.1 (+local desktop widget)"
GIBS = "https://gibs.earthdata.nasa.gov/wms/epsg4326/best/wms.cgi"
W, H = 1024, 512


def _get(url: str, timeout: int = 40) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def _save_png(img: Image.Image, path: Path) -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp.png")
    img.save(tmp, format="PNG", optimize=True)
    tmp.replace(path)


def _empty() -> Image.Image:
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def _gibs(layer: str, width: int = W, height: int = H) -> Image.Image | None:
    url = (
        f"{GIBS}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS={layer}"
        f"&CRS=EPSG:4326&BBOX=-90,-180,90,180&WIDTH={width}&HEIGHT={height}"
        "&FORMAT=image/png&TRANSPARENT=TRUE"
    )
    try:
        data = _get(url)
        img = Image.open(io.BytesIO(data)).convert("RGBA")
        if img.size != (width, height):
            img = img.resize((width, height), Image.Resampling.BILINEAR)
        # Reject empty / tiny error images
        alpha = np.asarray(img.getchannel("A"))
        if int(np.count_nonzero(alpha > 12)) < 200:
            return None
        return img
    except (urllib.error.URLError, OSError, ValueError):
        return None


def build_rain() -> tuple[Image.Image, str]:
    """Global precipitation field (IMERG).

    Ground radar (RainViewer) is deliberately not used: it only covers ~3% of
    the planet, so on a globe it reads as speckle rather than weather.
    """
    imerg = _gibs("IMERG_Precipitation_Rate")
    if imerg is None:
        return _empty(), "none"
    # Soften the 0.1-degree pixel grid and lift faint drizzle so cells stay
    # readable once the field is wrapped onto a sphere.
    soft = imerg.filter(ImageFilter.GaussianBlur(0.8))
    arr = np.asarray(soft).astype(np.float32)
    arr[..., 3] = np.clip(arr[..., 3] * 1.2, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA"), "imerg"


def build_ocean() -> tuple[Image.Image, str]:
    sst = _gibs("GHRSST_L4_MUR_Sea_Surface_Temperature")
    if sst is None:
        sst = _gibs("MODIS_Aqua_L3_SST_Thermal_4km_Day_Daily")
        if sst is None:
            return _empty(), "none"
        return sst, "modis-sst"
    # Slightly glassier so land/earth still shows through
    arr = np.asarray(sst).astype(np.float32)
    arr[..., 3] = np.clip(arr[..., 3] * 0.72, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA"), "mur-sst"


def fetch_wind() -> dict:
    """Regular lat/lon grid of eastward (u) / northward (v) wind, m/s."""
    lat0, dlat, nlat = -70.0, 10.0, 15
    lon0, dlon, nlon = -180.0, 10.0, 36
    lats: list[float] = []
    lons: list[float] = []
    idx: list[int] = []
    for ilat in range(nlat):
        lat = lat0 + ilat * dlat
        for ilon in range(nlon):
            lon = lon0 + ilon * dlon
            lats.append(lat)
            lons.append(lon)
            idx.append(ilat * nlon + ilon)
    u = [0.0] * (nlat * nlon)
    v = [0.0] * (nlat * nlon)
    s = [0.0] * (nlat * nlon)
    for i in range(0, len(lats), 90):
        bla, blo, bidx = lats[i : i + 90], lons[i : i + 90], idx[i : i + 90]
        qs = (
            "https://api.open-meteo.com/v1/forecast?"
            f"latitude={','.join(str(x) for x in bla)}"
            f"&longitude={','.join(str(x) for x in blo)}"
            "&current=wind_speed_10m,wind_direction_10m"
            "&wind_speed_unit=ms"
        )
        try:
            raw = json.loads(_get(qs, timeout=30))
        except (urllib.error.URLError, json.JSONDecodeError, OSError):
            continue
        rows = raw if isinstance(raw, list) else [raw]
        for row, k in zip(rows, bidx):
            cur = row.get("current") or {}
            try:
                spd = float(cur.get("wind_speed_10m"))
                deg = float(cur.get("wind_direction_10m"))
            except (TypeError, ValueError):
                continue
            if not math.isfinite(spd) or not math.isfinite(deg):
                continue
            rad = math.radians(deg)
            # Meteorological "from" → eastward / northward
            u[k] = round(-spd * math.sin(rad), 2)
            v[k] = round(-spd * math.cos(rad), 2)
            s[k] = round(spd, 1)
        time.sleep(0.05)
    return {
        "lat0": lat0,
        "lon0": lon0,
        "dlat": dlat,
        "dlon": dlon,
        "nlat": nlat,
        "nlon": nlon,
        "u": u,
        "v": v,
        "s": s,
    }


def main() -> int:
    args = set(sys.argv[1:])
    skip_rain = "--skip-rain" in args
    skip_ocean = "--skip-ocean" in args
    skip_wind = "--skip-wind" in args
    CACHE.mkdir(parents=True, exist_ok=True)
    rain_src = "skip"
    ocean_src = "skip"
    wind: dict = {}
    if not skip_rain:
        rain, rain_src = build_rain()
        _save_png(rain, RAIN_PATH)
    if not skip_ocean:
        ocean, ocean_src = build_ocean()
        _save_png(ocean, OCEAN_PATH)
    if not skip_wind:
        wind = fetch_wind()
    out = {
        "rain": str(RAIN_PATH) if RAIN_PATH.is_file() else "",
        "ocean": str(OCEAN_PATH) if OCEAN_PATH.is_file() else "",
        "rain_src": rain_src,
        "ocean_src": ocean_src,
        "wind": wind,
        "updated": int(time.time()),
    }
    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
