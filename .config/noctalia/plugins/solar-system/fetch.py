#!/usr/bin/env python3
"""Heliocentric ecliptic planet positions — JPL Keplerian (Table 1, 1800–2050).

https://ssd.jpl.nasa.gov/planets/approx_pos.html
Also: moon phase, conjunction/opposition aspects, Earth peri→apo season arc.
"""
from __future__ import annotations

import json
import math
import time
from datetime import datetime, timezone
from pathlib import Path

SETTINGS = Path.home() / ".config/noctalia/plugins/solar-system/settings.json"
ORBIT_SAMPLES = 128
ASPECT_SEP_DEG = 10.0  # show tick if within this many degrees

# a0, adot, e0, edot, I0, Idot, L0, Ldot, ϖ0, ϖdot, Ω0, Ωdot
_ELEMENTS = {
    "Mercury": (0.38709927, 0.00000037, 0.20563593, 0.00001906, 7.00497902, -0.00594749, 252.25032350, 149472.67411175, 77.45779628, 0.16047689, 48.33076593, -0.12534081),
    "Venus": (0.72333566, 0.00000390, 0.00677672, -0.00004107, 3.39467605, -0.00078890, 181.97909950, 58517.81538729, 131.60246718, 0.00268329, 76.67984255, -0.27769418),
    "Earth": (1.00000261, 0.00000562, 0.01671123, -0.00004392, -0.00001531, -0.01294668, 100.46457166, 35999.37244981, 102.93768193, 0.32327364, 0.0, 0.0),
    "Mars": (1.52371034, 0.00001847, 0.09339410, 0.00007882, 1.84969142, -0.00813131, -4.55343205, 19140.30268499, -23.94362959, 0.44441088, 49.55953891, -0.29257343),
    "Jupiter": (5.20288700, -0.00011607, 0.04838624, -0.00013253, 1.30439695, -0.00183714, 34.39644051, 3034.74612775, 14.72847983, 0.21252668, 100.47390909, 0.20469106),
    "Saturn": (9.53667594, -0.00125060, 0.05386179, -0.00050991, 2.48599187, 0.00193609, 49.95424423, 1222.49362201, 92.59887831, -0.41897216, 113.66242448, -0.28867794),
    "Uranus": (19.18916464, -0.00196176, 0.04725744, -0.00004397, 0.77263783, -0.00242939, 313.23810451, 428.48202785, 170.95427630, 0.40805281, 74.01692503, 0.04240589),
    "Neptune": (30.06992276, 0.00026291, 0.00859048, 0.00005105, 1.77004347, 0.00035372, -55.12002969, 218.45945325, 44.96476227, -0.32241464, 131.78422574, -0.00508664),
}

_COLORS = {
    "Mercury": "#b0b0b0",
    "Venus": "#e8c87a",
    "Earth": "#4aa3ff",
    "Mars": "#e07050",
    "Jupiter": "#d4a574",
    "Saturn": "#e6d5a5",
    "Uranus": "#7ec8c8",
    "Neptune": "#4169e1",
}

_OUTER = {"Mars", "Jupiter", "Saturn", "Uranus", "Neptune"}


def load_settings() -> dict:
    try:
        return json.loads(SETTINGS.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def julian_day(dt: datetime) -> float:
    y, m = dt.year, dt.month
    d = dt.day + (dt.hour + dt.minute / 60.0 + dt.second / 3600.0) / 24.0
    if m <= 2:
        y -= 1
        m += 12
    a = y // 100
    b = 2 - a + a // 4
    return int(365.25 * (y + 4716)) + int(30.6001 * (m + 1)) + d + b - 1524.5


def julian_centuries_j2000(dt: datetime) -> float:
    return (julian_day(dt) - 2451545.0) / 36525.0


def _norm360(x: float) -> float:
    return x % 360.0


def _angsep(a: float, b: float) -> float:
    """Smallest absolute angular separation (deg)."""
    d = abs(_norm360(a - b))
    return min(d, 360.0 - d)


def kepler(m_deg: float, e: float) -> float:
    m = math.radians(_norm360(m_deg))
    e_anom = m if e < 0.8 else math.pi
    for _ in range(16):
        e_anom = e_anom - (e_anom - e * math.sin(e_anom) - m) / (1 - e * math.cos(e_anom))
    return math.degrees(e_anom)


def elements_at(name: str, t: float) -> tuple[float, float, float, float, float]:
    a0, adot, e0, edot, i0, idot, _l0, _ldot, w0, wdot, o0, odot = _ELEMENTS[name]
    a = a0 + adot * t
    e = e0 + edot * t
    I = math.radians(i0 + idot * t)
    Omega = math.radians(o0 + odot * t)
    peri = (w0 + wdot * t) - (o0 + odot * t)
    return a, e, I, peri, Omega


def mean_anomaly(name: str, t: float) -> float:
    _a0, _adot, _e0, _edot, _i0, _idot, l0, ldot, w0, wdot, _o0, _odot = _ELEMENTS[name]
    return _norm360((l0 + ldot * t) - (w0 + wdot * t))


def xyz_from_anomaly(a: float, e: float, I: float, peri: float, Omega: float, m_deg: float) -> tuple[float, float, float]:
    E = kepler(m_deg, e)
    Er = math.radians(E)
    x_orb = a * (math.cos(Er) - e)
    y_orb = a * math.sqrt(max(0.0, 1 - e * e)) * math.sin(Er)
    cosw, sinw = math.cos(math.radians(peri)), math.sin(math.radians(peri))
    cosO, sinO = math.cos(Omega), math.sin(Omega)
    cosI, sinI = math.cos(I), math.sin(I)
    x1 = cosw * x_orb - sinw * y_orb
    y1 = sinw * x_orb + cosw * y_orb
    x = cosO * x1 - sinO * cosI * y1
    y = sinO * x1 + cosO * cosI * y1
    z = sinI * y1
    return x, y, z


def planet_state(name: str, t: float) -> tuple[float, float, float, float, float, float, float]:
    a, e, I, peri, Omega = elements_at(name, t)
    M = mean_anomaly(name, t)
    x, y, z = xyz_from_anomaly(a, e, I, peri, Omega, M)
    r = math.sqrt(x * x + y * y + z * z)
    lon = math.degrees(math.atan2(y, x)) % 360.0
    return x, y, z, lon, r, e, a


def visual_radius(r_au: float, r_min: float = 0.14, r_max: float = 0.94) -> float:
    lo, hi = math.log(0.307), math.log(30.1)
    u = (math.log(max(0.25, r_au)) - lo) / (hi - lo)
    u = max(0.0, min(1.0, u))
    return r_min + u * (r_max - r_min)


def visual_xy(x: float, y: float) -> tuple[float, float]:
    r = math.hypot(x, y)
    if r < 1e-12:
        return 0.0, 0.0
    vr = visual_radius(r)
    return (x / r) * vr, (y / r) * vr


def orbit_polyline(name: str, t: float, n: int = ORBIT_SAMPLES) -> list[list[float]]:
    a, e, I, peri, Omega = elements_at(name, t)
    pts: list[list[float]] = []
    for i in range(n):
        m = 360.0 * i / n
        x, y, _z = xyz_from_anomaly(a, e, I, peri, Omega, m)
        vx, vy = visual_xy(x, y)
        pts.append([round(vx, 5), round(vy, 5)])
    return pts


def moon_phase(dt: datetime) -> dict:
    """Synodic phase from known new-moon epoch (simple, ~hours)."""
    jd = julian_day(dt)
    # New moon near 2000-01-06 18:14 TT ≈ JD 2451550.1
    synodic = 29.530588853
    age = (jd - 2451550.1) % synodic
    if age < 0:
        age += synodic
    phase = age / synodic  # 0=new … 0.5=full … 1=new
    illum = 0.5 * (1.0 - math.cos(2.0 * math.pi * phase))
    waxing = phase < 0.5
    if phase < 0.03 or phase > 0.97:
        name = "New"
    elif 0.22 < phase < 0.28:
        name = "First quarter"
    elif 0.47 < phase < 0.53:
        name = "Full"
    elif 0.72 < phase < 0.78:
        name = "Last quarter"
    elif waxing and phase < 0.25:
        name = "Waxing crescent"
    elif waxing:
        name = "Waxing gibbous"
    elif phase < 0.75:
        name = "Waning gibbous"
    else:
        name = "Waning crescent"
    return {
        "illumination": round(illum, 4),
        "phase": round(phase, 4),
        "age_days": round(age, 2),
        "waxing": waxing,
        "name": name,
    }


def find_aspects(planets: list[dict]) -> list[dict]:
    """Heliocentric conjunctions + Earth–outer oppositions within ASPECT_SEP_DEG."""
    by_name = {p["name"]: p for p in planets}
    aspects: list[dict] = []
    names = [p["name"] for p in planets]

    # Conjunctions: shared ecliptic longitude
    for i, a in enumerate(names):
        for b in names[i + 1 :]:
            lon_a = float(by_name[a]["lon"])
            lon_b = float(by_name[b]["lon"])
            sep = _angsep(lon_a, lon_b)
            if sep <= ASPECT_SEP_DEG:
                lon = _norm360(0.5 * (lon_a + lon_b)) if sep < 90 else lon_a
                # better midpoint along short arc
                if _angsep(lon_a, lon_b) == sep:
                    # average on circle
                    xa, ya = math.cos(math.radians(lon_a)), math.sin(math.radians(lon_a))
                    xb, yb = math.cos(math.radians(lon_b)), math.sin(math.radians(lon_b))
                    lon = math.degrees(math.atan2(ya + yb, xa + xb)) % 360.0
                aspects.append(
                    {
                        "type": "conjunction",
                        "a": a,
                        "b": b,
                        "lon": round(lon, 2),
                        "sep": round(sep, 2),
                        "color_a": by_name[a]["color"],
                        "color_b": by_name[b]["color"],
                    }
                )

    # Oppositions: Earth vs outer (heliocentric ≈ geocentric opposition cue)
    if "Earth" in by_name:
        elon = float(by_name["Earth"]["lon"])
        for name in names:
            if name not in _OUTER:
                continue
            plon = float(by_name[name]["lon"])
            sep = abs(_angsep(elon, plon) - 180.0)
            if sep <= ASPECT_SEP_DEG:
                # tick at outer planet's lon (opposition direction from Sun through outer)
                aspects.append(
                    {
                        "type": "opposition",
                        "a": "Earth",
                        "b": name,
                        "lon": round(plon, 2),
                        "lon_earth": round(elon, 2),
                        "sep": round(sep, 2),
                        "color_a": by_name["Earth"]["color"],
                        "color_b": by_name[name]["color"],
                    }
                )

    aspects.sort(key=lambda x: x["sep"])
    return aspects[:8]


def earth_season(t: float) -> dict:
    """Perihelion → aphelion arc on Earth's orbit + endpoints + now fraction."""
    a, e, I, peri, Omega = elements_at("Earth", t)
    M_now = mean_anomaly("Earth", t)

    def at_m(m: float) -> list[float]:
        x, y, _z = xyz_from_anomaly(a, e, I, peri, Omega, m)
        vx, vy = visual_xy(x, y)
        return [round(vx, 5), round(vy, 5)]

    peri_pt = at_m(0.0)
    apo_pt = at_m(180.0)
    # outbound half: M = 0 → 180 (peri → apo)
    n = 64
    arc = [at_m(180.0 * i / (n - 1)) for i in range(n)]
    # fraction along peri→apo→peri year by mean anomaly
    frac = M_now / 360.0
    return {
        "peri": peri_pt,
        "apo": apo_pt,
        "arc": arc,
        "m_now": round(M_now, 2),
        "year_frac": round(frac, 4),
        "toward_apo": M_now <= 180.0,
    }


def main() -> int:
    cfg = load_settings()
    include = cfg.get("planets") or list(_ELEMENTS.keys())
    now = datetime.now(timezone.utc)
    t = julian_centuries_j2000(now)

    planets = []
    for name in include:
        if name not in _ELEMENTS:
            continue
        x, y, z, lon, r, e, a = planet_state(name, t)
        vx, vy = visual_xy(x, y)
        planets.append(
            {
                "name": name,
                "x": round(x, 6),
                "y": round(y, 6),
                "z": round(z, 6),
                "lon": round(lon, 3),
                "au": round(r, 5),
                "a": round(a, 5),
                "e": round(e, 6),
                "color": _COLORS.get(name, "#ffffff"),
                "vx": round(vx, 5),
                "vy": round(vy, 5),
                "vr": round(math.hypot(vx, vy), 5),
                "angle": round(math.degrees(math.atan2(y, x)) % 360.0, 3),
                "orbit": orbit_polyline(name, t),
            }
        )

    aspects = find_aspects(planets)
    season = earth_season(t)
    moon = moon_phase(now)

    out = {
        "ok": True,
        "planets": planets,
        "aspects": aspects,
        "season": season,
        "moon": moon,
        "utc": now.strftime("%Y-%m-%d %H:%M UTC"),
        "epoch": "JPL Table1 1800–2050 · true e",
        "accuracy": "~arcmin class (JPL approx_pos); moon ~hours",
        "updated": int(time.time()),
    }
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
