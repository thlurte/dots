#!/usr/bin/env python3
"""Fetch RSS/Atom feeds listed in the plugin settings.json."""
from __future__ import annotations

import email.utils
import json
import os
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from html import unescape
from pathlib import Path

SETTINGS = Path.home() / ".config/noctalia/plugins/rss-feeds/settings.json"
UA = "noctalia-rss/1.0 (+local desktop widget)"
ATOM = "{http://www.w3.org/2005/Atom}"


def load_settings() -> dict:
    try:
        return json.loads(SETTINGS.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


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
                dt = datetime.strptime(s.replace("+00:00", "+0000"), fmt.replace("%z", "%z") if "%z" in fmt else fmt)
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


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/rss+xml, application/atom+xml, application/xml, text/xml, */*"})
    with urllib.request.urlopen(req, timeout=12) as resp:
        return resp.read()


def atom_link(entry: ET.Element) -> str:
    for link in entry.findall(f"{ATOM}link"):
        rel = link.attrib.get("rel", "alternate")
        href = link.attrib.get("href", "")
        if href and rel in ("alternate", ""):
            return href
    link = entry.find(f"{ATOM}link")
    return link.attrib.get("href", "") if link is not None else ""


def parse_feed(data: bytes, feed_name: str) -> list[dict]:
    try:
        root = ET.fromstring(data)
    except ET.ParseError:
        return []
    tag = root.tag.lower()
    items: list[dict] = []

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
            if title:
                items.append(
                    {
                        "title": title[:160],
                        "link": link,
                        "feed": feed_name,
                        "ts": published,
                        "age": age(published),
                    }
                )
        return items

    if tag.endswith("feed") or root.find(f"{ATOM}entry") is not None:
        for entry in root.findall(f"{ATOM}entry"):
            title = text_of(entry.find(f"{ATOM}title"))
            link = atom_link(entry)
            published = parse_date(
                text_of(entry.find(f"{ATOM}published"))
                or text_of(entry.find(f"{ATOM}updated"))
            )
            if title:
                items.append(
                    {
                        "title": title[:160],
                        "link": link,
                        "feed": feed_name,
                        "ts": published,
                        "age": age(published),
                    }
                )
        return items

    # namespace-agnostic fallback
    for item in root.iter():
        local = item.tag.split("}")[-1].lower()
        if local != "item" and local != "entry":
            continue
        title_el = None
        link = ""
        published = 0.0
        for child in item:
            cl = child.tag.split("}")[-1].lower()
            if cl == "title":
                title_el = child
            elif cl == "link":
                link = child.attrib.get("href") or text_of(child) or link
            elif cl in ("pubdate", "published", "updated", "date"):
                published = parse_date(text_of(child)) or published
        title = text_of(title_el)
        if title:
            items.append(
                {
                    "title": title[:160],
                    "link": link,
                    "feed": feed_name,
                    "ts": published,
                    "age": age(published),
                }
            )
    return items


def main() -> int:
    cfg = load_settings()
    feeds = cfg.get("feeds") or []
    max_items = int(cfg.get("maxItems") or 10)
    enabled = [f for f in feeds if isinstance(f, dict) and f.get("url") and f.get("enabled", True)]

    collected: list[dict] = []
    errors: list[str] = []
    for feed in enabled:
        name = str(feed.get("name") or "feed").strip() or "feed"
        url = str(feed.get("url") or "").strip()
        try:
            collected.extend(parse_feed(fetch(url), name))
        except Exception as exc:  # noqa: BLE001 — surface per-feed failures
            errors.append(f"{name}: {exc}")

    collected.sort(key=lambda x: x.get("ts") or 0, reverse=True)
    out = {
        "items": collected[:max_items],
        "count": len(collected),
        "feeds": len(enabled),
        "errors": errors[:4],
        "updated": int(time.time()),
    }
    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
