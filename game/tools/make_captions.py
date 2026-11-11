"""CAPTIONS (port ADR-108, PORT-124): game/data/captions.json from the
announcer's script (design/announcer/lines.csv and additions.csv), every
line in the bitmap fonts' letters: capitals, digits and !?.,:-'/%+.
    python3 game/tools/make_captions.py
"""
import csv
import json
import re
from pathlib import Path

KIT = Path(__file__).resolve().parents[2]
SOURCES = [KIT / "design/announcer/lines.csv", KIT / "design/announcer/additions.csv"]
OUT = KIT / "game/data/captions.json"
FONT = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!?.,:-'/%+ ")


def clean(text):
    t = text.upper()
    t = t.replace("’", "'").replace("‘", "'").replace('"', "'").replace("“", "'").replace("”", "'")
    t = t.replace("—", " - ").replace("–", "-").replace("…", "...").replace(";", ",")
    t = t.replace("&", " AND ").replace("(", "").replace(")", "")
    t = "".join(c for c in t if c in FONT)
    return re.sub(r" +", " ", t).strip()


def main():
    lines = {}
    for src in SOURCES:
        with src.open(newline="") as f:
            for row in csv.DictReader(f):
                lines[row["id"]] = clean(row["text"])
    OUT.write_text(json.dumps({"comment": "The announcer's lines as captions (tools/make_captions.py "
                                          "from design/announcer/*.csv; port ADR-108).",
                               "lines": dict(sorted(lines.items()))}, indent=1) + "\n")
    print(f"{len(lines)} captions -> {OUT.relative_to(KIT)}")


if __name__ == "__main__":
    main()
