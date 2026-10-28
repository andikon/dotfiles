"""Check the shortcut registry and generated docs; pass --write to update docs."""
import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "config/wezterm/windows/shortcuts.tsv"
GUIDE = ROOT / "docs/tools/wezterm.md"
START, END = "<!-- shortcuts:start -->", "<!-- shortcuts:end -->"


def key_label(row):
    modifiers = [
        {"CTRL": "Ctrl", "SHIFT": "Shift"}.get(mod, mod)
        for mod in row["mods"].split("|")
        if mod not in {"LEADER", "NONE"} and not (mod == "SHIFT" and row["key"] == "?")
    ]
    key = row["key"]
    if len(key) == 1 and key.isupper():
        key = key.lower()
    return ("Prefix, " if "LEADER" in row["mods"] else "") + "+".join([*modifiers, key])


def main():
    with REGISTRY.open(encoding="utf-8", newline="") as source:
        rows = list(csv.DictReader(source, delimiter="\t"))
    seen = set()
    table = [START, "<!-- Generated from config/wezterm/windows/shortcuts.tsv. -->", "",
             "| Group | Key | Action |", "| --- | --- | --- |"]
    for row in rows:
        assert all(row.values()), f"Incomplete shortcut: {row}"
        assert row["scope"] in {"key", "resize", "mouse"}, row
        identity = (row["scope"], row["mods"], row["key"])
        assert identity not in seen, f"Duplicate shortcut: {identity}"
        seen.add(identity)
        table.append(f'| {row["group"]} | `{key_label(row)}` | {row["description"]} |')
    table.extend(["", END])
    expected = "\n".join(table)
    guide = GUIDE.read_text(encoding="utf-8")
    start, end = guide.index(START), guide.index(END) + len(END)
    if "--write" in sys.argv:
        GUIDE.write_text(guide[:start] + expected + guide[end:], encoding="utf-8", newline="\n")
    else:
        assert guide[start:end] == expected, "Shortcut docs are stale; run python tests/wezterm/verify-shortcuts.py --write"
    print(f"PASS: {len(rows)} shortcut definitions and generated documentation.")


if __name__ == "__main__":
    main()
