#!/usr/bin/env python3
import ipaddress
import json
import os
import subprocess
import urllib.request

CACHE = os.path.expanduser("~/.cache/noctalia/socket-geo.json")
FIELDS = "status,lat,lon,city,country,query"


def parse_peer(peer: str) -> str | None:
    peer = peer.strip()
    if not peer:
        return None
    if peer.startswith("["):
        end = peer.rfind("]")
        if end < 0:
            return None
        raw = peer[1:end]
    else:
        raw = peer.rsplit(":", 1)[0]
    try:
        ip = ipaddress.ip_address(raw)
    except ValueError:
        return None
    if (
        ip.is_private
        or ip.is_loopback
        or ip.is_link_local
        or ip.is_multicast
        or ip.is_reserved
        or ip.is_unspecified
    ):
        return None
    if ip.version == 4 and ip in ipaddress.ip_network("100.64.0.0/10"):
        return None
    return str(ip)


def remotes() -> dict[str, int]:
    out = subprocess.check_output(
        ["ss", "-H", "-tn", "state", "established"], text=True, errors="replace"
    )
    counts: dict[str, int] = {}
    for line in out.splitlines():
        cols = line.split()
        if len(cols) < 4:
            continue
        ip = parse_peer(cols[3])
        if not ip:
            continue
        counts[ip] = counts.get(ip, 0) + 1
    return counts


def load_cache() -> dict:
    try:
        with open(CACHE, encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def save_cache(cache: dict) -> None:
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    tmp = CACHE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(cache, f)
    os.replace(tmp, CACHE)


def lookup(unknown: list[str], cache: dict) -> None:
    if not unknown:
        return
    batch = unknown[:40]
    req = urllib.request.Request(
        f"http://ip-api.com/batch?fields={FIELDS}",
        data=json.dumps(batch).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=3) as resp:
            rows = json.loads(resp.read().decode())
    except (OSError, json.JSONDecodeError):
        return
    if not isinstance(rows, list):
        return
    for row in rows:
        if not isinstance(row, dict) or row.get("status") != "success":
            continue
        ip = row.get("query")
        if not ip:
            continue
        cache[ip] = {
            "lat": row.get("lat"),
            "lon": row.get("lon"),
            "city": row.get("city") or "",
            "country": row.get("country") or "",
        }
    save_cache(cache)


def main() -> None:
    counts = remotes()
    cache = load_cache()
    unknown = [ip for ip in counts if ip not in cache]
    lookup(unknown, cache)
    clusters: dict[tuple, dict] = {}
    for ip, n in counts.items():
        geo = cache.get(ip)
        if not geo or geo.get("lat") is None or geo.get("lon") is None:
            continue
        key = (round(float(geo["lat"]), 1), round(float(geo["lon"]), 1))
        row = clusters.get(key)
        if not row:
            clusters[key] = {
                "ip": ip,
                "n": n,
                "lat": geo["lat"],
                "lon": geo["lon"],
                "label": geo.get("city") or geo.get("country") or ip,
            }
        else:
            row["n"] += n
    points = sorted(clusters.values(), key=lambda r: -r["n"])
    print(json.dumps({"points": points, "pending": len(unknown)}))


if __name__ == "__main__":
    main()
