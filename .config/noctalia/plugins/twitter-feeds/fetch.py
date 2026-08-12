#!/usr/bin/env python3
"""Fetch X/Twitter timelines via bird CLI with cache + rotation to avoid 429s."""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

SETTINGS = Path.home() / ".config/noctalia/plugins/twitter-feeds/settings.json"
CACHE_FILE = Path.home() / ".cache/noctalia/twitter-feeds-cache.json"
CANDIDATES = [
    Path.home() / ".npm-global/bin/bird",
    Path.home() / ".local/bin/bird",
    Path("/usr/local/bin/bird"),
    Path("/usr/bin/bird"),
]
MAX_ACCOUNTS_PER_RUN = 3
REQUEST_TIMEOUT = 22
BIRD = None


def resolve_bird() -> str:
    for path in CANDIDATES:
        if path.is_file() and os.access(path, os.X_OK):
            return str(path)
    which = shutil.which("bird")
    if which:
        return which
    raise FileNotFoundError("bird not found — install @steipete/bird")


def bird_env() -> dict:
    env = os.environ.copy()
    extras = [
        str(Path.home() / ".npm-global/bin"),
        str(Path.home() / ".local/bin"),
        "/usr/local/bin",
        "/usr/bin",
    ]
    path = env.get("PATH", "")
    for p in extras:
        if p and p not in path.split(":"):
            path = p + ":" + path
    env["PATH"] = path
    return env


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
        return {"handles": {}, "rotation": 0}


def save_cache(cache: dict) -> None:
    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = CACHE_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")
    tmp.replace(CACHE_FILE)


def parse_created(raw: str) -> float:
    raw = (raw or "").strip()
    if not raw:
        return 0.0
    for fmt in (
        "%a %b %d %H:%M:%S %z %Y",
        "%Y-%m-%dT%H:%M:%S.%fZ",
        "%Y-%m-%dT%H:%M:%SZ",
    ):
        try:
            s = raw.replace("Z", "+0000") if "%z" in fmt and raw.endswith("Z") else raw
            dt = datetime.strptime(s, fmt)
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


def extract_json(text: str):
    text = text.strip()
    start_arr = text.find("[")
    start_obj = text.find("{")
    starts = [i for i in (start_arr, start_obj) if i >= 0]
    if not starts:
        raise ValueError("no JSON in bird output")
    return json.loads(text[min(starts):])


def clean_text(text: str) -> str:
    text = (text or "").replace("\n", " ").strip()
    return re.sub(r"\s+", " ", text)[:220]


def normalize_handle(raw: str) -> str:
    h = (raw or "").strip()
    if h.startswith("@"):
        h = h[1:]
    return h.split("/")[-1].strip()


def per_user_count(account_count: int) -> int:
    if account_count <= 2:
        return 5
    if account_count <= 4:
        return 4
    return 3


class RateLimited(RuntimeError):
    pass


def fetch_user(handle: str, n: int) -> list[dict]:
    bird = BIRD or resolve_bird()
    cmd = [bird, "user-tweets", handle, "-n", str(n), "--json", "--plain"]
    proc = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=REQUEST_TIMEOUT,
        check=False,
        env=bird_env(),
    )
    stdout = proc.stdout or ""
    stderr = proc.stderr or ""
    combined = stdout + "\n" + stderr
    if "429" in combined or "Rate limit" in combined:
        raise RateLimited("rate limited by X")
    if proc.returncode != 0 and "[" not in stdout:
        msg = (stderr or stdout or "bird failed").strip().splitlines()
        raise RuntimeError(msg[-1][:140] if msg else "bird failed")
    data = extract_json(stdout or combined)
    if not isinstance(data, list):
        raise RuntimeError("unexpected bird payload")
    items = []
    for tw in data:
        if not isinstance(tw, dict):
            continue
        author = tw.get("author") or {}
        username = author.get("username") or handle
        tid = str(tw.get("id") or "")
        if not tid:
            continue
        ts = parse_created(str(tw.get("createdAt") or ""))
        items.append(
            {
                "id": tid,
                "title": clean_text(str(tw.get("text") or "")),
                "link": f"https://x.com/{username}/status/{tid}",
                "feed": f"@{username}",
                "name": author.get("name") or username,
                "ts": ts,
                "age": age(ts),
                "likes": tw.get("likeCount") or 0,
                "rts": tw.get("retweetCount") or 0,
            }
        )
    return items


def label_tweets(tweets: list[dict], handle: str, label: str) -> list[dict]:
    out = []
    for t in tweets:
        row = dict(t)
        if not row.get("feed", "").startswith("@"):
            row["feed"] = f"@{handle}"
        row["label"] = label if label and label.lower() != handle.lower() else row["feed"]
        out.append(row)
    return out


def main() -> int:
    global BIRD
    try:
        BIRD = resolve_bird()
    except FileNotFoundError as exc:
        print(json.dumps({"items": [], "count": 0, "feeds": 0, "errors": [str(exc)], "updated": int(time.time())}))
        return 0

    cfg = load_settings()
    cache = load_cache()
    handles_cache = cache.setdefault("handles", {})
    accounts = cfg.get("accounts") or []
    max_items = int(cfg.get("maxItems") or 20)
    enabled = [
        a
        for a in accounts
        if isinstance(a, dict) and normalize_handle(str(a.get("handle") or "")) and a.get("enabled", True)
    ]

    if not enabled:
        print(json.dumps({"items": [], "count": 0, "feeds": 0, "errors": [], "updated": int(time.time())}))
        return 0

    n_acc = len(enabled)
    per_user = per_user_count(n_acc)
    start = int(cache.get("rotation", 0)) % n_acc
    batch_size = min(MAX_ACCOUNTS_PER_RUN, n_acc)
    batch = [enabled[(start + i) % n_acc] for i in range(batch_size)]
    cache["rotation"] = (start + batch_size) % n_acc

    errors: list[str] = []
    rate_limited = False

    for acc in batch:
        handle = normalize_handle(str(acc.get("handle") or ""))
        label = str(acc.get("name") or handle).strip() or handle
        try:
            tweets = label_tweets(fetch_user(handle, per_user), handle, label)
            handles_cache[handle] = {
                "items": tweets,
                "fetched_at": int(time.time()),
            }
        except RateLimited:
            rate_limited = True
            errors.append("X rate limit — showing cached tweets; try refresh later")
            break
        except Exception as exc:  # noqa: BLE001
            errors.append(f"@{handle}: {exc}")
            if handle in handles_cache and handles_cache[handle].get("items"):
                errors.append(f"@{handle}: using cache")

    save_cache(cache)

    collected: list[dict] = []
    for acc in enabled:
        handle = normalize_handle(str(acc.get("handle") or ""))
        label = str(acc.get("name") or handle).strip() or handle
        entry = handles_cache.get(handle)
        if entry and entry.get("items"):
            collected.extend(label_tweets(entry["items"], handle, label))

    collected.sort(key=lambda x: x.get("ts") or 0, reverse=True)
    seen: set[str] = set()
    unique: list[dict] = []
    for t in collected:
        tid = t.get("id")
        if not tid or tid in seen:
            continue
        seen.add(tid)
        unique.append(t)

    if rate_limited and not errors:
        errors.append("X rate limit — cached only")

    out = {
        "items": unique[:max_items],
        "count": len(unique),
        "feeds": n_acc,
        "errors": errors[:3],
        "updated": int(time.time()),
        "rate_limited": rate_limited,
    }
    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
