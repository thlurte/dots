#!/usr/bin/env python3
"""Fetch world-news RSS/Atom feeds and pin stories to places named in titles."""
from __future__ import annotations

import email.utils
import hashlib
import json
import re
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from html import unescape
from pathlib import Path

SETTINGS = Path.home() / ".config/noctalia/plugins/news-globe/settings.json"
CACHE_FILE = Path.home() / ".cache/noctalia/news-globe-cache.json"
UA = "noctalia-news-globe/1.0 (+local desktop widget)"
ATOM = "{http://www.w3.org/2005/Atom}"
MAX_FEEDS_PER_RUN = 5
REQUEST_TIMEOUT = 25
PER_FEED_ITEMS = 10
MAX_PINS = 52

# Longest names first so "South Korea" wins over "Korea", etc.
_PLACES: list[tuple[str, float, float]] = [
    ("United Arab Emirates", 24.45, 54.38),
    ("Democratic Republic of the Congo", -4.32, 15.31),
    ("Democratic Republic of Congo", -4.32, 15.31),
    ("Bosnia and Herzegovina", 43.86, 18.41),
    ("Central African Republic", 4.39, 18.56),
    ("Papua New Guinea", -9.44, 147.18),
    ("Northern Ireland", 54.60, -5.93),
    ("Strait of Hormuz", 26.57, 56.25),
    ("Taiwan Strait", 24.50, 119.50),
    ("Côte d'Ivoire", 6.83, -5.29),
    ("Cote d'Ivoire", 6.83, -5.29),
    ("Saudi Arabia", 24.71, 46.68),
    ("South Africa", -25.75, 28.19),
    ("South Korea", 37.57, 126.98),
    ("North Korea", 39.04, 125.75),
    ("South Sudan", 4.86, 31.58),
    ("New Zealand", -41.29, 174.78),
    ("New Caledonia", -22.28, 166.46),
    ("United States", 38.90, -77.04),
    ("United Kingdom", 51.51, -0.13),
    ("Czech Republic", 50.08, 14.44),
    ("Burkina Faso", 12.37, -1.53),
    ("Ivory Coast", 6.83, -5.29),
    ("Sri Lanka", 6.93, 79.85),
    ("Hong Kong", 22.32, 114.17),
    ("West Bank", 31.95, 35.23),
    ("Lake Victoria", -1.00, 33.00),
    ("Palestine", 31.90, 35.20),
    ("Palestinian", 31.90, 35.20),
    ("Afghanistan", 34.53, 69.17),
    ("Argentina", -34.60, -58.38),
    ("Australia", -35.28, 149.13),
    ("Azerbaijan", 40.41, 49.87),
    ("Bangladesh", 23.81, 90.41),
    ("Belarus", 53.90, 27.57),
    ("Belgium", 50.85, 4.35),
    ("Brazil", -15.79, -47.88),
    ("Britain", 51.51, -0.13),
    ("British", 51.51, -0.13),
    ("Canada", 45.42, -75.70),
    ("Chile", -33.45, -70.67),
    ("China", 39.90, 116.41),
    ("Chinese", 39.90, 116.41),
    ("Colombia", 4.71, -74.07),
    ("Congolese", -4.32, 15.31),
    ("Congo", -4.32, 15.31),
    ("Croatia", 45.81, 15.98),
    ("Cuba", 23.11, -82.37),
    ("Denmark", 55.68, 12.57),
    ("Egypt", 30.04, 31.24),
    ("England", 51.51, -0.13),
    ("English", 51.51, -0.13),
    ("Ethiopia", 9.03, 38.75),
    ("Finland", 60.17, 24.94),
    ("France", 48.86, 2.35),
    ("French", 48.86, 2.35),
    ("Gaza", 31.50, 34.47),
    ("Georgia", 41.72, 44.79),
    ("Germany", 52.52, 13.40),
    ("German", 52.52, 13.40),
    ("Greece", 37.98, 23.73),
    ("Guatemala", 14.63, -90.51),
    ("Haiti", 18.59, -72.31),
    ("Honduras", 14.07, -87.19),
    ("Hungary", 47.50, 19.04),
    ("India", 28.61, 77.21),
    ("Indian", 28.61, 77.21),
    ("Indonesia", -6.21, 106.85),
    ("Iran", 35.69, 51.39),
    ("Iraq", 33.31, 44.37),
    ("Ireland", 53.35, -6.26),
    ("Israel", 31.77, 35.22),
    ("Israeli", 31.77, 35.22),
    ("Italy", 41.90, 12.50),
    ("Italian", 41.90, 12.50),
    ("Japan", 35.68, 139.69),
    ("Japanese", 35.68, 139.69),
    ("Jordan", 31.95, 35.91),
    ("Kashmir", 34.08, 74.80),
    ("Kenya", -1.29, 36.82),
    ("Lebanon", 33.89, 35.50),
    ("Libya", 32.89, 13.19),
    ("Mexico", 19.43, -99.13),
    ("Morocco", 34.02, -6.84),
    ("Myanmar", 16.87, 96.20),
    ("Netherlands", 52.37, 4.90),
    ("Nicaragua", 12.11, -86.24),
    ("Nigeria", 9.08, 7.40),
    ("Norway", 59.91, 10.75),
    ("Pakistan", 33.68, 73.05),
    ("Panama", 8.98, -79.52),
    ("Philippines", 14.60, 120.98),
    ("Poland", 52.23, 21.01),
    ("Portugal", 38.72, -9.14),
    ("Qatar", 25.29, 51.53),
    ("Romania", 44.43, 26.10),
    ("Russia", 55.76, 37.62),
    ("Russian", 55.76, 37.62),
    ("Rwanda", -1.94, 30.06),
    ("Scotland", 55.95, -3.19),
    ("Senegal", 14.69, -17.44),
    ("Serbia", 44.82, 20.46),
    ("Singapore", 1.35, 103.82),
    ("Somalia", 2.05, 45.32),
    ("Spain", 40.42, -3.70),
    ("Spanish", 40.42, -3.70),
    ("Sudan", 15.50, 32.56),
    ("Sweden", 59.33, 18.07),
    ("Switzerland", 46.95, 7.45),
    ("Syria", 33.51, 36.29),
    ("Taiwan", 25.03, 121.57),
    ("Thailand", 13.76, 100.50),
    ("Türkiye", 39.93, 32.86),
    ("Turkiye", 39.93, 32.86),
    ("Turkish", 39.93, 32.86),
    ("Turkey", 39.93, 32.86),
    ("Ukraine", 50.45, 30.52),
    ("Ukrainian", 50.45, 30.52),
    ("Venezuela", 10.48, -66.90),
    ("Vietnam", 21.03, 105.85),
    ("Wales", 51.48, -3.18),
    ("Yemen", 15.37, 44.19),
    ("Zambia", -15.42, 28.28),
    ("Zimbabwe", -17.83, 31.05),
    ("Hormuz", 26.57, 56.25),
    ("Golan", 33.00, 35.74),
    ("Donbas", 48.00, 37.80),
    ("Donetsk", 48.02, 37.80),
    ("Crimea", 45.05, 34.10),
    ("Red Sea", 20.00, 38.50),
    ("Black Sea", 43.00, 34.00),
    ("Mediterranean", 35.00, 18.00),
    ("Sahel", 15.00, 0.00),
    ("Houthi", 15.37, 44.19),
    ("Hamas", 31.50, 34.47),
    ("Hezbollah", 33.89, 35.50),
    ("Taliban", 34.53, 69.17),
    ("Congolese", -4.32, 15.31),
    ("DRC", -4.32, 15.31),
    ("UAE", 24.45, 54.38),
    ("London", 51.51, -0.13),
    ("Paris", 48.86, 2.35),
    ("Berlin", 52.52, 13.40),
    ("Moscow", 55.76, 37.62),
    ("Kyiv", 50.45, 30.52),
    ("Kiev", 50.45, 30.52),
    ("Beijing", 39.90, 116.41),
    ("Shanghai", 31.23, 121.47),
    ("Tokyo", 35.68, 139.69),
    ("Seoul", 37.57, 126.98),
    ("Taipei", 25.03, 121.57),
    ("Delhi", 28.61, 77.21),
    ("Mumbai", 19.08, 72.88),
    ("Cairo", 30.04, 31.24),
    ("Tehran", 35.69, 51.39),
    ("Baghdad", 33.31, 44.37),
    ("Damascus", 33.51, 36.29),
    ("Beirut", 33.89, 35.50),
    ("Jerusalem", 31.77, 35.22),
    ("Tel Aviv", 32.09, 34.78),
    ("Riyadh", 24.71, 46.68),
    ("Doha", 25.29, 51.53),
    ("Dubai", 25.20, 55.27),
    ("Istanbul", 41.01, 28.98),
    ("Ankara", 39.93, 32.86),
    ("Washington", 38.90, -77.04),
    ("New York", 40.71, -74.01),
    ("Los Angeles", 34.05, -118.24),
    ("Chicago", 41.88, -87.63),
    ("Miami", 25.76, -80.19),
    ("Ottawa", 45.42, -75.70),
    ("Toronto", 43.65, -79.38),
    ("Mexico City", 19.43, -99.13),
    ("Buenos Aires", -34.60, -58.38),
    ("Santiago", -33.45, -70.67),
    ("Lima", -12.05, -77.04),
    ("Havana", 23.11, -82.37),
    ("Lagos", 6.52, 3.38),
    ("Nairobi", -1.29, 36.82),
    ("Addis Ababa", 9.03, 38.75),
    ("Cape Town", -33.92, 18.42),
    ("Johannesburg", -26.20, 28.04),
    ("Khartoum", 15.50, 32.56),
    ("Kinshasa", -4.32, 15.31),
    ("Lusaka", -15.42, 28.28),
    ("Harare", -17.83, 31.05),
    ("Kabul", 34.53, 69.17),
    ("Islamabad", 33.68, 73.05),
    ("Karachi", 24.86, 67.01),
    ("Dhaka", 23.81, 90.41),
    ("Bangkok", 13.76, 100.50),
    ("Jakarta", -6.21, 106.85),
    ("Manila", 14.60, 120.98),
    ("Hanoi", 21.03, 105.85),
    ("Sydney", -33.87, 151.21),
    ("Melbourne", -37.81, 144.96),
    ("Canberra", -35.28, 149.13),
    ("Auckland", -36.85, 174.76),
    ("Wellington", -41.29, 174.78),
    ("Pyongyang", 39.04, 125.75),
    ("Brussels", 50.85, 4.35),
    ("American", 38.90, -77.04),
    ("U.S.", 38.90, -77.04),
    ("US", 38.90, -77.04),
    ("UK", 51.51, -0.13),
    ("EU", 50.85, 4.35),
]

_PLACE_PATTERNS: list[tuple[re.Pattern[str], str, float, float]] = []
for _name, _lat, _lon in _PLACES:
    bare = _name.strip()
    # Allow common suffixes (Palestinians, Israelis) without matching mid-word (using)
    if bare in ("U.S.", "US", "UK", "EU", "DRC", "UAE"):
        pat = re.compile(rf"(?<![A-Za-z]){re.escape(bare)}(?![A-Za-z])", re.IGNORECASE)
    else:
        pat = re.compile(rf"(?<![A-Za-z]){re.escape(bare)}", re.IGNORECASE)
    _PLACE_PATTERNS.append((pat, bare, _lat, _lon))


def locate(title: str) -> tuple[float, float, str] | None:
    """Return (lat, lon, place) for the first place name found in title."""
    if not title:
        return None
    for pat, name, lat, lon in _PLACE_PATTERNS:
        if pat.search(title):
            return lat, lon, name
    return None


# IANA zones for gazetteer labels (fallback: longitude ÷ 15)
_PLACE_TZ: dict[str, str] = {
    "United Arab Emirates": "Asia/Dubai",
    "UAE": "Asia/Dubai",
    "Democratic Republic of the Congo": "Africa/Kinshasa",
    "Democratic Republic of Congo": "Africa/Kinshasa",
    "Congolese": "Africa/Kinshasa",
    "Congo": "Africa/Kinshasa",
    "DRC": "Africa/Kinshasa",
    "Kinshasa": "Africa/Kinshasa",
    "Bosnia and Herzegovina": "Europe/Sarajevo",
    "Central African Republic": "Africa/Bangui",
    "Papua New Guinea": "Pacific/Port_Moresby",
    "Northern Ireland": "Europe/London",
    "Strait of Hormuz": "Asia/Dubai",
    "Hormuz": "Asia/Dubai",
    "Taiwan Strait": "Asia/Taipei",
    "Côte d'Ivoire": "Africa/Abidjan",
    "Cote d'Ivoire": "Africa/Abidjan",
    "Ivory Coast": "Africa/Abidjan",
    "Saudi Arabia": "Asia/Riyadh",
    "Riyadh": "Asia/Riyadh",
    "South Africa": "Africa/Johannesburg",
    "Johannesburg": "Africa/Johannesburg",
    "Cape Town": "Africa/Johannesburg",
    "South Korea": "Asia/Seoul",
    "Seoul": "Asia/Seoul",
    "North Korea": "Asia/Pyongyang",
    "Pyongyang": "Asia/Pyongyang",
    "South Sudan": "Africa/Juba",
    "New Zealand": "Pacific/Auckland",
    "Auckland": "Pacific/Auckland",
    "Wellington": "Pacific/Auckland",
    "New Caledonia": "Pacific/Noumea",
    "United States": "America/New_York",
    "American": "America/New_York",
    "U.S.": "America/New_York",
    "US": "America/New_York",
    "Washington": "America/New_York",
    "New York": "America/New_York",
    "United Kingdom": "Europe/London",
    "UK": "Europe/London",
    "Britain": "Europe/London",
    "British": "Europe/London",
    "England": "Europe/London",
    "English": "Europe/London",
    "Scotland": "Europe/London",
    "Wales": "Europe/London",
    "London": "Europe/London",
    "Czech Republic": "Europe/Prague",
    "Burkina Faso": "Africa/Ouagadougou",
    "Sri Lanka": "Asia/Colombo",
    "Hong Kong": "Asia/Hong_Kong",
    "West Bank": "Asia/Hebron",
    "Palestine": "Asia/Hebron",
    "Palestinian": "Asia/Hebron",
    "Gaza": "Asia/Gaza",
    "Lake Victoria": "Africa/Nairobi",
    "Afghanistan": "Asia/Kabul",
    "Kabul": "Asia/Kabul",
    "Argentina": "America/Argentina/Buenos_Aires",
    "Buenos Aires": "America/Argentina/Buenos_Aires",
    "Australia": "Australia/Sydney",
    "Sydney": "Australia/Sydney",
    "Melbourne": "Australia/Melbourne",
    "Canberra": "Australia/Sydney",
    "Azerbaijan": "Asia/Baku",
    "Bangladesh": "Asia/Dhaka",
    "Dhaka": "Asia/Dhaka",
    "Belarus": "Europe/Minsk",
    "Belgium": "Europe/Brussels",
    "Brussels": "Europe/Brussels",
    "EU": "Europe/Brussels",
    "Brazil": "America/Sao_Paulo",
    "Canada": "America/Toronto",
    "Toronto": "America/Toronto",
    "Ottawa": "America/Toronto",
    "Chile": "America/Santiago",
    "Santiago": "America/Santiago",
    "China": "Asia/Shanghai",
    "Chinese": "Asia/Shanghai",
    "Beijing": "Asia/Shanghai",
    "Shanghai": "Asia/Shanghai",
    "Colombia": "America/Bogota",
    "Croatia": "Europe/Zagreb",
    "Cuba": "America/Havana",
    "Havana": "America/Havana",
    "Denmark": "Europe/Copenhagen",
    "Egypt": "Africa/Cairo",
    "Cairo": "Africa/Cairo",
    "Ethiopia": "Africa/Addis_Ababa",
    "Addis Ababa": "Africa/Addis_Ababa",
    "Finland": "Europe/Helsinki",
    "France": "Europe/Paris",
    "French": "Europe/Paris",
    "Paris": "Europe/Paris",
    "Georgia": "Asia/Tbilisi",
    "Germany": "Europe/Berlin",
    "German": "Europe/Berlin",
    "Berlin": "Europe/Berlin",
    "Greece": "Europe/Athens",
    "Guatemala": "America/Guatemala",
    "Haiti": "America/Port-au-Prince",
    "Honduras": "America/Tegucigalpa",
    "Hungary": "Europe/Budapest",
    "India": "Asia/Kolkata",
    "Indian": "Asia/Kolkata",
    "Delhi": "Asia/Kolkata",
    "Mumbai": "Asia/Kolkata",
    "Indonesia": "Asia/Jakarta",
    "Jakarta": "Asia/Jakarta",
    "Iran": "Asia/Tehran",
    "Tehran": "Asia/Tehran",
    "Iraq": "Asia/Baghdad",
    "Baghdad": "Asia/Baghdad",
    "Ireland": "Europe/Dublin",
    "Israel": "Asia/Jerusalem",
    "Israeli": "Asia/Jerusalem",
    "Jerusalem": "Asia/Jerusalem",
    "Tel Aviv": "Asia/Jerusalem",
    "Italy": "Europe/Rome",
    "Italian": "Europe/Rome",
    "Japan": "Asia/Tokyo",
    "Japanese": "Asia/Tokyo",
    "Tokyo": "Asia/Tokyo",
    "Jordan": "Asia/Amman",
    "Kashmir": "Asia/Kolkata",
    "Kenya": "Africa/Nairobi",
    "Nairobi": "Africa/Nairobi",
    "Lebanon": "Asia/Beirut",
    "Beirut": "Asia/Beirut",
    "Libya": "Africa/Tripoli",
    "Mexico": "America/Mexico_City",
    "Mexico City": "America/Mexico_City",
    "Morocco": "Africa/Casablanca",
    "Myanmar": "Asia/Yangon",
    "Netherlands": "Europe/Amsterdam",
    "Nicaragua": "America/Managua",
    "Nigeria": "Africa/Lagos",
    "Lagos": "Africa/Lagos",
    "Norway": "Europe/Oslo",
    "Pakistan": "Asia/Karachi",
    "Islamabad": "Asia/Karachi",
    "Karachi": "Asia/Karachi",
    "Panama": "America/Panama",
    "Philippines": "Asia/Manila",
    "Manila": "Asia/Manila",
    "Poland": "Europe/Warsaw",
    "Portugal": "Europe/Lisbon",
    "Qatar": "Asia/Qatar",
    "Doha": "Asia/Qatar",
    "Romania": "Europe/Bucharest",
    "Russia": "Europe/Moscow",
    "Russian": "Europe/Moscow",
    "Moscow": "Europe/Moscow",
    "Rwanda": "Africa/Kigali",
    "Senegal": "Africa/Dakar",
    "Serbia": "Europe/Belgrade",
    "Singapore": "Asia/Singapore",
    "Somalia": "Africa/Mogadishu",
    "Spain": "Europe/Madrid",
    "Spanish": "Europe/Madrid",
    "Sudan": "Africa/Khartoum",
    "Khartoum": "Africa/Khartoum",
    "Sweden": "Europe/Stockholm",
    "Switzerland": "Europe/Zurich",
    "Syria": "Asia/Damascus",
    "Damascus": "Asia/Damascus",
    "Taiwan": "Asia/Taipei",
    "Taipei": "Asia/Taipei",
    "Thailand": "Asia/Bangkok",
    "Bangkok": "Asia/Bangkok",
    "Türkiye": "Europe/Istanbul",
    "Turkiye": "Europe/Istanbul",
    "Turkish": "Europe/Istanbul",
    "Turkey": "Europe/Istanbul",
    "Istanbul": "Europe/Istanbul",
    "Ankara": "Europe/Istanbul",
    "Ukraine": "Europe/Kyiv",
    "Ukrainian": "Europe/Kyiv",
    "Kyiv": "Europe/Kyiv",
    "Kiev": "Europe/Kyiv",
    "Donbas": "Europe/Kyiv",
    "Donetsk": "Europe/Kyiv",
    "Crimea": "Europe/Simferopol",
    "Venezuela": "America/Caracas",
    "Vietnam": "Asia/Ho_Chi_Minh",
    "Hanoi": "Asia/Ho_Chi_Minh",
    "Yemen": "Asia/Aden",
    "Houthi": "Asia/Aden",
    "Zambia": "Africa/Lusaka",
    "Lusaka": "Africa/Lusaka",
    "Zimbabwe": "Africa/Harare",
    "Harare": "Africa/Harare",
    "Golan": "Asia/Damascus",
    "Red Sea": "Asia/Riyadh",
    "Black Sea": "Europe/Istanbul",
    "Mediterranean": "Europe/Rome",
    "Sahel": "Africa/Niamey",
    "Hamas": "Asia/Gaza",
    "Hezbollah": "Asia/Beirut",
    "Taliban": "Asia/Kabul",
    "Los Angeles": "America/Los_Angeles",
    "Chicago": "America/Chicago",
    "Miami": "America/New_York",
    "Dubai": "Asia/Dubai",
    "Lima": "America/Lima",
}


def tz_for(place: str, lon: float) -> tuple[str, int]:
    """Return (label, utc_offset_minutes) for a place."""
    iana = _PLACE_TZ.get(place or "")
    if iana:
        try:
            from zoneinfo import ZoneInfo

            now = datetime.now(ZoneInfo(iana))
            off = now.utcoffset()
            mins = int(off.total_seconds() // 60) if off else 0
            return iana.split("/")[-1].replace("_", " "), mins
        except Exception:  # noqa: BLE001
            pass
    mins = int(round(float(lon or 0) / 15.0)) * 60
    sign = "+" if mins >= 0 else "-"
    ah, am = divmod(abs(mins), 60)
    return (f"UTC{sign}{ah}" if am == 0 else f"UTC{sign}{ah}:{am:02d}"), mins


def load_settings() -> dict:
    try:
        return json.loads(SETTINGS.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def load_cache() -> dict:
    try:
        data = json.loads(CACHE_FILE.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {"feeds": {}, "rotation": 0}


def save_cache(cache: dict) -> None:
    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = CACHE_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")
    tmp.replace(CACHE_FILE)


def strip_html(text: str) -> str:
    out = []
    i = 0
    while i < len(text):
        if text[i] == "<":
            j = text.find(">", i)
            if j < 0:
                break
            i = j + 1
            continue
        out.append(text[i])
        i += 1
    return unescape("".join(out)).strip()


def clean_text(text: str, limit: int = 160) -> str:
    text = strip_html(text or "").replace("\n", " ").strip()
    return re.sub(r"\s+", " ", text)[:limit]


def text_of(el: ET.Element | None) -> str:
    if el is None:
        return ""
    if el.text and el.text.strip():
        return strip_html(el.text)
    parts = []
    if el.text:
        parts.append(el.text)
    for child in list(el):
        parts.append(ET.tostring(child, encoding="unicode", method="text"))
        if child.tail:
            parts.append(child.tail)
    return strip_html("".join(parts))


def parse_date(raw: str) -> float:
    raw = (raw or "").strip()
    if not raw:
        return 0.0
    try:
        return email.utils.parsedate_to_datetime(raw).timestamp()
    except (TypeError, ValueError, IndexError):
        pass
    for fmt in (
        "%Y-%m-%dT%H:%M:%S%z",
        "%Y-%m-%dT%H:%M:%SZ",
        "%Y-%m-%dT%H:%M:%S.%f%z",
        "%Y-%m-%dT%H:%M:%S.%fZ",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d",
    ):
        try:
            s = raw.replace("Z", "+0000") if fmt.endswith("%z") and raw.endswith("Z") else raw
            if fmt.endswith("Z") and raw.endswith("Z"):
                dt = datetime.strptime(raw, fmt).replace(tzinfo=timezone.utc)
            else:
                dt = datetime.strptime(s.replace("+00:00", "+0000"), fmt)
                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=timezone.utc)
            return dt.timestamp()
        except ValueError:
            continue
    return 0.0


def age(ts: float) -> str:
    if ts <= 0:
        return ""
    secs = max(0, int(time.time() - ts))
    if secs < 60:
        return f"{secs}s"
    if secs < 3600:
        return f"{secs // 60}m"
    if secs < 86400:
        return f"{secs // 3600}h"
    return f"{secs // 86400}d"


def fetch_bytes(url: str) -> bytes:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": UA,
            "Accept": "application/rss+xml, application/atom+xml, application/xml, text/xml, */*",
        },
    )
    with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
        return resp.read()


def atom_link(entry: ET.Element) -> str:
    for link in entry.findall(f"{ATOM}link"):
        rel = link.attrib.get("rel", "alternate")
        href = link.attrib.get("href", "")
        if href and rel in ("alternate", ""):
            return href
    link = entry.find(f"{ATOM}link")
    return link.attrib.get("href", "") if link is not None else ""


def parse_feed(data: bytes, feed_name: str, lat: float, lon: float) -> list[dict]:
    try:
        root = ET.fromstring(data)
    except ET.ParseError:
        return []
    items: list[dict] = []
    tag = root.tag.lower()

    def local(tag: str) -> str:
        return (tag or "").split("}")[-1].lower()

    def child_text(el: ET.Element, name: str) -> str:
        want = name.lower()
        for child in list(el):
            if local(child.tag) == want:
                return text_of(child)
        return ""

    def push(title: str, link: str, published: float, summary: str = "") -> None:
        title = clean_text(title, 220)
        if not title:
            return
        items.append(
            {
                "id": link or f"{feed_name}:{title[:40]}",
                "title": title,
                "summary": clean_text(summary, 420),
                "link": link,
                "feed": feed_name,
                "label": feed_name,
                "lat": lat,
                "lon": lon,
                "ts": published,
                "age": age(published),
            }
        )

    rdf_items = [el for el in list(root) if local(el.tag) == "item"]
    if rdf_items:
        for item in rdf_items:
            title = child_text(item, "title")
            link = child_text(item, "link")
            summary = child_text(item, "description")
            published = parse_date(child_text(item, "date") or child_text(item, "pubDate"))
            push(title, link, published, summary)
        return items[:PER_FEED_ITEMS]

    if tag.endswith("rss") or root.find("channel") is not None:
        channel = root.find("channel")
        if channel is None:
            channel = root
        for item in channel.findall("item"):
            title = text_of(item.find("title"))
            link = text_of(item.find("link"))
            if not link:
                guid = item.find("guid")
                if guid is not None and guid.attrib.get("isPermaLink", "true") != "false":
                    link = text_of(guid)
            published = parse_date(text_of(item.find("pubDate")) or text_of(item.find("date")))
            summary = text_of(item.find("description"))
            push(title, link, published, summary)
        return items[:PER_FEED_ITEMS]

    if tag.endswith("feed") or root.find(f"{ATOM}entry") is not None:
        for entry in root.findall(f"{ATOM}entry"):
            title = text_of(entry.find(f"{ATOM}title"))
            link = atom_link(entry)
            published = parse_date(
                text_of(entry.find(f"{ATOM}published")) or text_of(entry.find(f"{ATOM}updated"))
            )
            summary = text_of(entry.find(f"{ATOM}summary") or entry.find(f"{ATOM}content"))
            push(title, link, published, summary)
        return items[:PER_FEED_ITEMS]

    for item in root.iter():
        kind = item.tag.split("}")[-1].lower()
        if kind not in ("item", "entry"):
            continue
        title_el = None
        link = ""
        published = 0.0
        summary = ""
        for child in item:
            cl = child.tag.split("}")[-1].lower()
            if cl == "title":
                title_el = child
            elif cl == "link":
                link = child.attrib.get("href") or text_of(child) or link
            elif cl in ("pubdate", "published", "updated", "date"):
                published = parse_date(text_of(child)) or published
            elif cl in ("description", "summary"):
                summary = text_of(child) or summary
        push(text_of(title_el), link, published, summary)
    return items[:PER_FEED_ITEMS]


class RateLimited(RuntimeError):
    pass


def fetch_feed(url: str, name: str, lat: float, lon: float) -> list[dict]:
    try:
        return parse_feed(fetch_bytes(url), name, lat, lon)
    except urllib.error.HTTPError as exc:
        if exc.code in (403, 429):
            raise RateLimited(f"HTTP {exc.code}") from exc
        raise


def main() -> int:
    cfg = load_settings()
    cache = load_cache()
    feeds_cache = cache.setdefault("feeds", {})
    max_items = int(cfg.get("maxItems") or 24)

    raw = cfg.get("feeds") or []
    enabled = []
    for row in raw:
        if not isinstance(row, dict):
            continue
        url = str(row.get("url") or "").strip()
        if not url or not row.get("enabled", True):
            continue
        name = str(row.get("name") or "feed").strip() or "feed"
        try:
            lat = float(row.get("lat"))
            lon = float(row.get("lon"))
        except (TypeError, ValueError):
            lat, lon = 0.0, 0.0
        enabled.append(
            {
                "name": name,
                "url": url,
                "lat": lat,
                "lon": lon,
                "alwaysPin": bool(row.get("alwaysPin")),
            }
        )

    if not enabled:
        print(json.dumps({"items": [], "count": 0, "feeds": 0, "errors": [], "updated": int(time.time())}))
        return 0

    n = len(enabled)
    start = int(cache.get("rotation", 0)) % n
    batch_size = min(MAX_FEEDS_PER_RUN, n)
    batch = [enabled[(start + i) % n] for i in range(batch_size)]
    cache["rotation"] = (start + batch_size) % n

    errors: list[str] = []
    rate_limited = False

    for row in batch:
        key = row["url"]
        try:
            posts = fetch_feed(row["url"], row["name"], row["lat"], row["lon"])
            if posts:
                feeds_cache[key] = {
                    "items": posts,
                    "fetched_at": int(time.time()),
                    "name": row["name"],
                    "lat": row["lat"],
                    "lon": row["lon"],
                }
            else:
                errors.append(f"{row['name']}: empty")
        except RateLimited:
            rate_limited = True
            errors.append("Rate limited — showing cache")
            break
        except Exception as exc:  # noqa: BLE001
            errors.append(f"{row['name']}: {exc}")
        time.sleep(0.5)

    save_cache(cache)

    collected: list[dict] = []
    for row in enabled:
        entry = feeds_cache.get(row["url"])
        if not entry or not entry.get("items"):
            continue
        for post in entry["items"]:
            item = dict(post)
            item["label"] = row["name"]
            item["feed"] = row["name"]
            hit = locate((item.get("title") or "") + " " + (item.get("summary") or ""))
            if hit:
                item["lat"], item["lon"], item["place"] = hit
                tz_label, tz_off = tz_for(item["place"], item["lon"])
                item["tz"] = tz_label
                item["tz_offset_min"] = tz_off
            else:
                # No place in title — keep feed HQ; tech feeds can still pin there
                item["lat"] = row["lat"]
                item["lon"] = row["lon"]
                item["place"] = row["name"] if row.get("alwaysPin") else ""
                item["tz"] = ""
                item["tz_offset_min"] = None
            collected.append(item)

    collected.sort(key=lambda x: x.get("ts") or 0, reverse=True)
    seen: set[str] = set()
    unique: list[dict] = []
    for post in collected:
        pid = post.get("id") or post.get("link") or post.get("title")
        if not pid or pid in seen:
            continue
        seen.add(str(pid))
        unique.append(post)

    def _jitter(lat: float, lon: float, key: str) -> tuple[float, float]:
        h = int(hashlib.md5(key.encode("utf-8")).hexdigest()[:8], 16)
        dlat = ((h % 97) - 48) / 48.0 * 2.2
        dlon = (((h // 97) % 97) - 48) / 48.0 * 2.2
        return lat + dlat, lon + dlon

    # One pin per geocoded story (slight jitter so same-country pins don't stack)
    pins: list[dict] = []
    for post in unique:
        place = (post.get("place") or "").strip()
        if not place:
            continue
        pin = dict(post)
        key = str(pin.get("id") or pin.get("link") or pin.get("title") or place)
        jlat, jlon = _jitter(float(pin.get("lat") or 0), float(pin.get("lon") or 0), key)
        pin["lat"], pin["lon"] = jlat, jlon
        pin["is_pin"] = True
        pins.append(pin)
        if len(pins) >= MAX_PINS:
            break

    out = {
        "items": unique[:max_items],
        "pins": pins,
        "count": len(unique),
        "feeds": n,
        "errors": errors[:3],
        "updated": int(time.time()),
        "rate_limited": rate_limited,
    }
    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
