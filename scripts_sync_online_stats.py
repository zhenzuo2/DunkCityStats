#!/usr/bin/env python3
"""Sync Dunk City player attributes from dunkcitydynasty.fandom.com.

Usage:
  python3 scripts_sync_online_stats.py --csv /path/to/DunkCityStats.csv --mode max --inplace

Modes:
  init: use *_init attributes
  max: use *_max attributes

Notes:
  - Only players available on the wiki are updated.
  - Missing players are left unchanged and listed in a report.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path
from typing import Dict, List, Tuple

import requests

API = "https://dunkcitydynasty.fandom.com/api.php"
STATS = [
    ("Dunk", "dunk"),
    ("Layup/Close", "layup"),
    ("Mid-range", "midrange"),
    ("3-pt", "threept"),
    ("Dribble", "dribble"),
    ("Steal", "steal"),
    ("Block", "block"),
    ("Rebound", "rebound"),
    ("Contest", "contest"),
    ("Pass", "pass"),
    ("Vertical", "vertical"),
    ("Movement", "movement"),
    ("Consistency", "consistency"),
    ("Strength", "strength"),
]

# CSV player name -> wiki page title
TITLE_ALIASES = {
    "S.G.Alexander": "S.G. Alexander",
    "Murrary": "Murray",
    "Derozan": "DeRozan",
    "Peterson": "Morris Peterson",
}


def fetch_character_titles(session: requests.Session) -> List[str]:
    titles: List[str] = []
    cmcontinue = None
    while True:
        params = {
            "action": "query",
            "list": "categorymembers",
            "cmtitle": "Category:Characters",
            "cmlimit": "500",
            "format": "json",
        }
        if cmcontinue:
            params["cmcontinue"] = cmcontinue
        resp = session.get(API, params=params, timeout=30)
        resp.raise_for_status()
        data = resp.json()
        for member in data.get("query", {}).get("categorymembers", []):
            if member.get("ns") == 0:
                titles.append(member["title"])
        cmcontinue = data.get("continue", {}).get("cmcontinue")
        if not cmcontinue:
            break
    return titles


def fetch_wikitext(session: requests.Session, title: str) -> str | None:
    params = {
        "action": "parse",
        "page": title,
        "prop": "wikitext",
        "format": "json",
        "redirects": 1,
    }
    resp = session.get(API, params=params, timeout=30)
    resp.raise_for_status()
    data = resp.json()
    if "error" in data:
        return None
    return data.get("parse", {}).get("wikitext", {}).get("*", "")


def extract_stats(wikitext: str) -> Dict[str, Dict[str, int]]:
    parsed: Dict[str, Dict[str, int]] = {"init": {}, "max": {}}
    for _, key in STATS:
        init_match = re.search(rf"\|{key}_init\s*=\s*([0-9]+)", wikitext)
        max_match = re.search(rf"\|{key}_max\s*=\s*([0-9]+)", wikitext)
        if init_match:
            parsed["init"][key] = int(init_match.group(1))
        if max_match:
            parsed["max"][key] = int(max_match.group(1))
    return parsed


def calc_derived(row: Dict[str, str]) -> None:
    def iv(name: str) -> int:
        try:
            return int(float(str(row.get(name, "0")).strip()))
        except Exception:
            return 0

    core_names = [name for name, _ in STATS]
    total = sum(iv(name) for name in core_names)
    offense = iv("Dunk") + iv("Layup/Close") + iv("Mid-range") + iv("3-pt") + iv("Dribble") + iv("Pass")
    defense = iv("Steal") + iv("Block") + iv("Rebound") + iv("Contest") + iv("Consistency")
    athleticism = iv("Vertical") + iv("Movement") + iv("Strength")

    row["Total"] = str(total)
    row["Avg. Attribute"] = f"{(total / 14):.1f}"
    row["Offense"] = str(offense)
    row["Defense"] = str(defense)
    # keep original spelling used in CSV
    if "Athleticisim" in row:
        row["Athleticisim"] = str(athleticism)
    else:
        row["Athleticism"] = str(athleticism)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True, type=Path)
    parser.add_argument("--mode", choices=["init", "max"], default="max")
    parser.add_argument("--inplace", action="store_true")
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--report", type=Path, default=None)
    args = parser.parse_args()

    csv_path: Path = args.csv
    if not csv_path.exists():
        raise SystemExit(f"CSV not found: {csv_path}")

    with csv_path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        rows = list(reader)
        fieldnames = reader.fieldnames or []

    session = requests.Session()
    titles = fetch_character_titles(session)
    title_set = set(titles)

    # Build wiki stats cache
    stats_cache: Dict[str, Dict[str, Dict[str, int]]] = {}
    for title in titles:
        wt = fetch_wikitext(session, title)
        if not wt:
            continue
        parsed = extract_stats(wt)
        if len(parsed["init"]) >= 12 and len(parsed["max"]) >= 12:
            stats_cache[title] = parsed

    updated: List[Tuple[str, str]] = []
    missing: List[str] = []

    for row in rows:
        player = row.get("Player", "").strip()
        title = TITLE_ALIASES.get(player, player)
        if title not in title_set or title not in stats_cache:
            missing.append(player)
            continue

        source = stats_cache[title][args.mode]
        # Ensure full stat set exists
        if not all(key in source for _, key in STATS):
            missing.append(player)
            continue

        for csv_name, key in STATS:
            row[csv_name] = str(source[key])

        calc_derived(row)
        updated.append((player, title))

    if args.inplace:
        out_csv = csv_path
    else:
        out_csv = args.output or csv_path.with_name(csv_path.stem + f".online_{args.mode}.csv")

    with out_csv.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    report_path = args.report or csv_path.with_name(f"online_sync_report_{args.mode}.json")
    report = {
        "mode": args.mode,
        "source": "https://dunkcitydynasty.fandom.com/wiki/Category:Characters",
        "updated_count": len(updated),
        "missing_count": len(missing),
        "updated_players": [{"player": p, "wiki_title": t} for p, t in updated],
        "missing_players": sorted(set(missing)),
        "output_csv": str(out_csv),
    }
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")

    print(f"Updated players: {len(updated)}")
    print(f"Missing players: {len(sorted(set(missing)))}")
    print(f"CSV written: {out_csv}")
    print(f"Report written: {report_path}")


if __name__ == "__main__":
    main()
