"""Copy the picked round 3 heads (port ADR-099) from heads.json into the
players' build, art/levels/tools/heads.json, under the ids the game uses.

    .venv/bin/python art/faces-r1/export_heads.py

Each head is 48 rows of palette roles on the guide's cell, the neck at
(22, 44); players.py stamps it at every pose's neck.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "levels", "tools", "heads.json")

# id: snapped head, per body, in the CAREER EDIT order
PICKS = {
    "male": {"crew": "m1", "beard": "m2", "athlete": "m4", "moustache": "m5",
             "shaggy": "o1", "glasses": "o2", "goatee": "o3", "bald": "o4",
             "stubble": "p1", "fullbeard": "p2"},
    "female": {"bangs": "n1", "focused": "n2", "glasses": "n3",
               "laughlines": "n4", "laughing": "n5", "smile": "o5",
               "roundspecs": "p3", "grin": "p4"},
}


def main():
    heads = json.load(open(os.path.join(HERE, "heads.json")))
    out = {"doc": "Port ADR-099: the generated heads (art/faces-r1, round 3), "
                  "as rows of palette roles on a 48x48 cell with the neck at "
                  "(22, 44). Written by art/faces-r1/export_heads.py.",
           "male": {}, "female": {}}
    for body, picks in PICKS.items():
        for hid, src in picks.items():
            out[body][hid] = heads[src]
    with open(OUT, "w") as f:
        json.dump(out, f, indent=0)
        f.write("\n")
    print("wrote", OUT, {b: len(p) for b, p in PICKS.items()})


if __name__ == "__main__":
    main()
