#!/usr/bin/env python3
"""Fetch Reddit hot posts via Atom RSS with cache + rotation to avoid 429/403."""
from __future__ import annotations

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

SETTINGS = Path.home() / ".config/noctalia/plugins/reddit-feeds/settings.json"
CACHE_FILE = Path.home() / ".cache/noctalia/reddit-feeds-cache.json"
ATOM = "{http://www.w3.org/2005/Atom}"
UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
)
MAX_SUBS_PER_RUN = 1
REQUEST_TIMEOUT = 25
VALID_SORTS = {"hot", "new", "top", "rising"}


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
        return {"subs": {}, "rotation": 0}


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


def clean_text(text: str, limit: int = 200) -> str:
    text = strip_html(text or "").replace("\n", " ").strip()
    return re.sub(r"\s+", " ", text)[:limit]


def parse_date(raw: str) -> float:
    raw = (raw or "").strip()
    if not raw:
        return 0.0
    for fmt in (
        "%Y-%m-%dT%H:%M:%S%z",
        "%Y-%m-%dT%H:%M:%SZ",
        "%Y-%m-%dT%H:%M:%S.%f%z",
        "%Y-%m-%dT%H:%M:%S.%fZ",
    ):
        try:
            s = raw.replace("Z", "+0000") if "%z" in fmt and raw.endswith("Z") else raw
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


def normalize_sub(raw: str) -> str:
    s = (raw or "").strip()
    s = re.sub(r"^https?://(www\.|old\.)?reddit\.com/r/", "", s, flags=re.I)
    s = s.strip("/").split("/")[0]
    if s.lower().startswith("r/"):
        s = s[2:]
    return s.strip()


def feed_url(sub: str, sort: str, limit: int) -> str:
    return f"https://www.reddit.com/r/{sub}/{sort}/.rss?limit={limit}"


class RateLimited(RuntimeError):
    pass


def fetch_bytes(url: str) -> bytes:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": UA,
            "Accept": "application/atom+xml, application/rss+xml, application/xml, text/xml, */*",
            "Accept-Language": "en-US,en;q=0.9",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            return resp.read()
    except urllib.error.HTTPError as exc:
        if exc.code in (403, 429):
            raise RateLimited(f"HTTP {exc.code}") from exc
        raise


def entry_link(entry: ET.Element) -> str:
    for link in entry.findall(f"{ATOM}link"):
        href = link.attrib.get("href", "")
        rel = link.attrib.get("rel", "alternate")
        if href and rel in ("alternate", ""):
            return href
    link = entry.find(f"{ATOM}link")
    return link.attrib.get("href", "") if link is not None else ""


def entry_id(entry: ET.Element, link: str) -> str:
    rid = (entry.findtext(f"{ATOM}id") or "").strip()
    if rid:
        # ids look like t3_abc123 — keep the last path segment
        return rid.split("/")[-1]
    m = re.search(r"/comments/([a-z0-9]+)/", link, flags=re.I)
    return m.group(1) if m else link


def parse_atom(data: bytes, label: str, sub: str) -> list[dict]:
    try:
        root = ET.fromstring(data)
    except ET.ParseError:
        return []
    items: list[dict] = []
    for entry in root.findall(f"{ATOM}entry"):
        title = clean_text(entry.findtext(f"{ATOM}title") or "", 180)
        if not title:
            continue
        link = entry_link(entry)
        ts = parse_date(
            entry.findtext(f"{ATOM}updated") or entry.findtext(f"{ATOM}published") or ""
        )
        author_el = entry.find(f"{ATOM}author")
        author = ""
        if author_el is not None:
            author = clean_text(author_el.findtext(f"{ATOM}name") or "", 40)
        items.append(
            {
                "id": entry_id(entry, link),
                "title": title,
                "link": link,
                "feed": f"r/{sub}",
                "label": label,
                "author": author,
                "ts": ts,
                "age": age(ts),
            }
        )
    return items


def per_sub_count(sub_count: int) -> int:
    if sub_count <= 2:
        return 8
    if sub_count <= 4:
        return 6
    return 4


def main() -> int:
    cfg = load_settings()
    cache = load_cache()
    subs_cache = cache.setdefault("subs", {})
    max_items = int(cfg.get("maxItems") or 20)
    sort = str(cfg.get("sort") or "hot").strip().lower()
    if sort not in VALID_SORTS:
        sort = "hot"

    raw_subs = cfg.get("subreddits") or []
    enabled = []
    for row in raw_subs:
        if not isinstance(row, dict):
            continue
        sub = normalize_sub(str(row.get("subreddit") or ""))
        if not sub or not row.get("enabled", True):
            continue
        name = str(row.get("name") or sub).strip() or sub
        enabled.append({"name": name, "subreddit": sub})

    if not enabled:
        print(json.dumps({"items": [], "count": 0, "feeds": 0, "errors": [], "updated": int(time.time())}))
        return 0

    n_subs = len(enabled)
    per_sub = per_sub_count(n_subs)
    start = int(cache.get("rotation", 0)) % n_subs
    batch_size = min(MAX_SUBS_PER_RUN, n_subs)
    batch = [enabled[(start + i) % n_subs] for i in range(batch_size)]
    cache["rotation"] = (start + batch_size) % n_subs

    errors: list[str] = []
    rate_limited = False

    for row in batch:
        sub = row["subreddit"]
        label = row["name"]
        url = feed_url(sub, sort, per_sub)
        try:
            posts = parse_atom(fetch_bytes(url), label, sub)
            if not posts:
                errors.append(f"r/{sub}: empty feed")
            else:
                subs_cache[sub.lower()] = {
                    "items": posts,
                    "fetched_at": int(time.time()),
                    "label": label,
                }
        except RateLimited:
            rate_limited = True
            errors.append("Reddit rate limit — showing cached posts; try refresh later")
            break
        except Exception as exc:  # noqa: BLE001
            errors.append(f"r/{sub}: {exc}")
            if sub.lower() in subs_cache and subs_cache[sub.lower()].get("items"):
                errors.append(f"r/{sub}: using cache")

        # small gap between requests in the same run
        time.sleep(0.8)

    save_cache(cache)

    collected: list[dict] = []
    for row in enabled:
        sub = row["subreddit"]
        label = row["name"]
        entry = subs_cache.get(sub.lower())
        if not entry or not entry.get("items"):
            continue
        for post in entry["items"]:
            item = dict(post)
            item["label"] = label
            item["feed"] = f"r/{sub}"
            collected.append(item)

    collected.sort(key=lambda x: x.get("ts") or 0, reverse=True)
    seen: set[str] = set()
    unique: list[dict] = []
    for post in collected:
        pid = post.get("id") or post.get("link")
        if not pid or pid in seen:
            continue
        seen.add(pid)
        unique.append(post)

    out = {
        "items": unique[:max_items],
        "count": len(unique),
        "feeds": n_subs,
        "errors": errors[:3],
        "updated": int(time.time()),
        "rate_limited": rate_limited,
        "sort": sort,
    }
    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
