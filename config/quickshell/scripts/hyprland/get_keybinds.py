#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

SECTION_PATTERN = re.compile(r"^#\s*=+\s*(.*?)\s*=+\s*$")


def parse_bind_line(line: str, section: str, submap: str | None) -> dict[str, object]:
    _, payload = line.split("=", 1)
    parts = [part.strip() for part in payload.split(",", 4)]
    if len(parts) < 4:
        raise ValueError(f"Invalid bindd line: {line}")

    mods, key, description, dispatcher = parts[:4]
    command = parts[4] if len(parts) == 5 else ""

    return {
        "mods": mods.split() if mods else [],
        "key": key,
        "description": description,
        "dispatcher": dispatcher,
        "command": command,
        "section": section,
        "submap": submap,
    }


def parse_keybinds(path: Path) -> list[dict[str, object]]:
    items: list[dict[str, object]] = []
    current_section = "General"
    current_submap: str | None = None

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line:
            continue

        section_match = SECTION_PATTERN.match(line)
        if section_match:
            current_section = section_match.group(1).strip() or "General"
            continue

        if line.startswith("submap ="):
            submap_name = line.split("=", 1)[1].strip()
            current_submap = None if submap_name == "reset" else submap_name
            continue

        if not line.startswith("bindd ="):
            continue

        items.append(parse_bind_line(line, current_section, current_submap))

    return items


def main() -> None:
    parser = argparse.ArgumentParser(description="Parse Hyprland bindd keybinds")
    parser.add_argument("--path", required=True, help="Path to keybinds.conf")
    args = parser.parse_args()

    print(json.dumps(parse_keybinds(Path(args.path))))


if __name__ == "__main__":
    main()
