#!/usr/bin/env python3

from __future__ import annotations

import csv
import re
from pathlib import Path
from typing import Iterable

import numpy as np
from PIL import Image


PROJECT_DIR = Path("/Users/zzuo1/Documents/DunkCityStats/DunkCityStats")
DOWNLOADS_DIR = Path("/Users/zzuo1/Downloads")
OUTPUT_DIR = PROJECT_DIR / "HeadshotExtraction" / "from_downloads_0925_0929"
MAPPING_CSV = PROJECT_DIR / "HeadshotExtraction" / "download_0925_0929_mapping.csv"
COVERAGE_CSV = (
    PROJECT_DIR / "HeadshotExtraction" / "download_0925_0929_needs_screenshot_coverage.csv"
)
TARGET_CSV = PROJECT_DIR / "DunkCityStats.csv"

# The blue name bars sit directly below each portrait. We detect them first, then crop
# exactly one portrait-height above each bar for a clean avatar tile.
NAME_BAR_MIN_WIDTH = 220
NAME_BAR_MAX_WIDTH = 260
NAME_BAR_MIN_HEIGHT = 50
NAME_BAR_MAX_HEIGHT = 70
PORTRAIT_HEIGHT = 298


PLAYERS_BY_IMAGE: dict[str, tuple[str, list[str]]] = {
    "IMG_0925.PNG": (
        "C",
        [
            "Jokic",
            "Embiid",
            "Davis",
            "Olajuwon",
            "Gasol",
            "Wallace",
            "Capela",
            "Adebayo",
            "Porzingis",
            "Lopez",
            "Nurkic",
            "Adams",
            "Miller",
        ],
    ),
    "IMG_0926.PNG": (
        "PF",
        [
            "Antetokounmpo",
            "Tatum",
            "Nowitzki",
            "Rodman",
            "Malone",
            "Towns",
            "Williamson",
            "Anderson",
            "Gordon",
            "Siakam",
            "Jackson Jr.",
            "Kuminga",
            "Julio",
            "McDyess",
        ],
    ),
    "IMG_0927.PNG": (
        "SF",
        [
            "James",
            "Durant",
            "Leonard",
            "Butler",
            "Brown",
            "James '16",
            "DeRozan",
            "Wiggins",
            "George",
            "Ingram",
            "Brooks",
            "Hayward",
            "Johnson",
            "Fu Zhi",
            "Peterson",
        ],
    ),
    "IMG_0928.PNG": (
        "SG",
        [
            "Harden",
            "Allen",
            "Thompson",
            "Booker",
            "LaVine",
            "McCollum",
            "Clarkson",
            "Seth Curry",
            "Schroder",
            "Crawford",
        ],
    ),
    "IMG_0929.PNG": (
        "PG",
        [
            "Curry",
            "Kidd",
            "S.G. Alexander",
            "Westbrook",
            "Paul",
            "Doncic",
            "Murray",
            "Ball",
            "Zhou Chang",
            "Hong Shou",
        ],
    ),
}


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")
    return slug or "unknown"


def _component_boxes(mask: np.ndarray) -> Iterable[tuple[int, int, int, int, int]]:
    h, w = mask.shape
    visited = np.zeros_like(mask, dtype=np.uint8)
    for y in range(h):
        xs = np.where(mask[y] & (visited[y] == 0))[0]
        for x in xs:
            if visited[y, x]:
                continue
            queue = [(y, x)]
            visited[y, x] = 1
            i = 0
            area = 0
            min_x = max_x = x
            min_y = max_y = y

            while i < len(queue):
                cy, cx = queue[i]
                i += 1
                area += 1
                min_x = min(min_x, cx)
                max_x = max(max_x, cx)
                min_y = min(min_y, cy)
                max_y = max(max_y, cy)

                if cy > 0 and mask[cy - 1, cx] and not visited[cy - 1, cx]:
                    visited[cy - 1, cx] = 1
                    queue.append((cy - 1, cx))
                if cy + 1 < h and mask[cy + 1, cx] and not visited[cy + 1, cx]:
                    visited[cy + 1, cx] = 1
                    queue.append((cy + 1, cx))
                if cx > 0 and mask[cy, cx - 1] and not visited[cy, cx - 1]:
                    visited[cy, cx - 1] = 1
                    queue.append((cy, cx - 1))
                if cx + 1 < w and mask[cy, cx + 1] and not visited[cy, cx + 1]:
                    visited[cy, cx + 1] = 1
                    queue.append((cy, cx + 1))

            yield area, min_x, min_y, max_x, max_y


def find_name_bars(image: np.ndarray) -> list[tuple[int, int, int, int]]:
    # Name bars are dark slate blue rectangles.
    r = image[:, :, 0]
    g = image[:, :, 1]
    b = image[:, :, 2]
    mask = (r > 55) & (r < 120) & (g > 70) & (g < 130) & (b > 100) & (b < 170)

    # Restrict search area to the middle content panel.
    x0, x1 = 300, 2500
    y0, y1 = 250, 1200
    window = mask[y0:y1, x0:x1]

    bars: list[tuple[int, int, int, int]] = []
    for _, min_x, min_y, max_x, max_y in _component_boxes(window):
        width = max_x - min_x + 1
        height = max_y - min_y + 1
        if (
            NAME_BAR_MIN_WIDTH <= width <= NAME_BAR_MAX_WIDTH
            and NAME_BAR_MIN_HEIGHT <= height <= NAME_BAR_MAX_HEIGHT
        ):
            bars.append((min_x + x0, min_y + y0, max_x + x0, max_y + y0))

    bars.sort(key=lambda box: (box[1], box[0]))
    return bars


def extract() -> list[dict[str, str]]:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, str]] = []

    for image_name, (position, players) in PLAYERS_BY_IMAGE.items():
        image_path = DOWNLOADS_DIR / image_name
        if not image_path.exists():
            raise FileNotFoundError(f"Missing screenshot: {image_path}")

        image = Image.open(image_path).convert("RGB")
        array = np.array(image)
        bars = find_name_bars(array)

        if len(bars) != len(players):
            raise RuntimeError(
                f"{image_name}: expected {len(players)} name bars but found {len(bars)}"
            )

        for idx, (player, bar) in enumerate(zip(players, bars), start=1):
            left, top, right, _ = bar
            crop_top = max(0, top - PORTRAIT_HEIGHT)
            crop_box = (left, crop_top, right + 1, top)
            portrait = image.crop(crop_box)

            filename = f"{slugify(player)}.png"
            out_path = OUTPUT_DIR / filename
            if out_path.exists():
                # Keep filenames stable if a duplicate player name appears across files.
                filename = f"{slugify(player)}_{image_path.stem.lower()}.png"
                out_path = OUTPUT_DIR / filename

            portrait.save(out_path)
            records.append(
                {
                    "Player": player,
                    "Position": position,
                    "SourceImage": image_name,
                    "Slot": str(idx),
                    "CropPath": str(out_path),
                    "BarLeft": str(left),
                    "BarTop": str(top),
                    "BarRight": str(right),
                }
            )

    return records


def write_mapping_csv(records: list[dict[str, str]]) -> None:
    fieldnames = [
        "Player",
        "Position",
        "SourceImage",
        "Slot",
        "CropPath",
        "BarLeft",
        "BarTop",
        "BarRight",
    ]
    with MAPPING_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(records)


def write_needs_coverage_csv(found_players: set[str]) -> None:
    needs_path = PROJECT_DIR / "players_need_screenshot.csv"
    with needs_path.open(newline="", encoding="utf-8") as f:
        needs = list(csv.DictReader(f))

    out_rows = []
    for row in needs:
        player = row["Player"]
        out_rows.append(
            {
                "Player": player,
                "Position": row.get("Position", ""),
                "NeedsScreenshotReason": row.get("NeedsScreenshotReason", ""),
                "FoundInDownloads0925_0929": "YES" if player in found_players else "NO",
                "Note": "" if player in found_players else "not present in provided screenshots",
            }
        )

    fieldnames = [
        "Player",
        "Position",
        "NeedsScreenshotReason",
        "FoundInDownloads0925_0929",
        "Note",
    ]
    with COVERAGE_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(out_rows)


def update_missing_headshot_sources(records: list[dict[str, str]]) -> int:
    by_player = {row["Player"]: row for row in records}
    with TARGET_CSV.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames or []
        rows = list(reader)

    updated = 0
    for row in rows:
        player = row.get("Player", "")
        if player not in by_player:
            continue

        status = row.get("HeadshotStatus", "").strip().lower()
        source = row.get("HeadshotSource", "").strip()
        if source and status not in {"missing", "unmatched"}:
            continue

        rel = Path("HeadshotExtraction") / "from_downloads_0925_0929" / (
            Path(by_player[player]["CropPath"]).name
        )
        row["HeadshotSource"] = str(rel)
        row["HeadshotStatus"] = "matched_local"
        note = row.get("HeadshotNote", "").strip()
        row["HeadshotNote"] = (
            f"{note};from_download_screenshot" if note else "from_download_screenshot"
        )
        updated += 1

    with TARGET_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    return updated


def main() -> None:
    records = extract()
    write_mapping_csv(records)
    found_players = {row["Player"] for row in records}
    write_needs_coverage_csv(found_players)
    updated = update_missing_headshot_sources(records)

    print(f"Saved {len(records)} headshot crops to: {OUTPUT_DIR}")
    print(f"Wrote mapping: {MAPPING_CSV}")
    print(f"Wrote screenshot coverage report: {COVERAGE_CSV}")
    print(f"Updated missing headshot rows in CSV: {updated}")


if __name__ == "__main__":
    main()
