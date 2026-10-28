"""Validate the install contract without reading or changing user settings."""

import csv
import json
import re
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[2]
PLATFORMS = {"windows", "macos", "linux", "wsl"}
VARIABLES = {
    "HOME", "CONFIG", "LOCALAPPDATA", "APPDATA", "NVIM", "VSCODE",
    "PSPROFILE", "PSMODULES", "WEZTERM", "TERMINAL", "GLAZEWM",
}


def table(name, columns):
    path = ROOT / "catalog" / name
    data = path.read_bytes()
    assert b"\r" not in data, f"{name}: use LF line endings"
    assert data.endswith(b"\n"), f"{name}: missing final newline"
    with path.open(encoding="utf-8", newline="") as stream:
        reader = csv.DictReader(stream, delimiter="\t")
        assert reader.fieldnames == columns, f"{name}: unexpected columns"
        rows = list(reader)
    for row in rows:
        assert set(row) == set(columns) and all(row.values()), f"{name}: incomplete row: {row}"
        assert all("\n" not in value and "\r" not in value for value in row.values())
    return rows


tools = table("tools.tsv", ["id", "label", "platforms", "command", "required", "optional", "group"])
targets = table("targets.tsv", ["tool", "platforms", "kind", "source", "destination"])
packages = table("packages.tsv", ["id", "winget", "brew", "apt", "dnf", "pacman"])
requirements = table("requirements.tsv", ["command", "minimum"])
tool_map = {tool["id"]: tool for tool in tools}
package_ids = {package["id"] for package in packages}
assert len(tool_map) == len(tools), "Duplicate tool ID"
assert len(package_ids) == len(packages), "Duplicate package ID"
assert len({row["command"] for row in requirements}) == len(requirements), "Duplicate version requirement"
for requirement in requirements:
    assert re.fullmatch(r"\d+\.\d+\.\d+", requirement["minimum"]), requirement

for tool in tools:
    assert re.fullmatch(r"[a-z][a-z0-9-]*", tool["id"]), tool
    supported = set(tool["platforms"].split(","))
    assert supported <= PLATFORMS, tool
    assert tool["group"] in {"cli", "gui", "desktop"}, tool
    for dependency in (tool["required"] + "," + tool["optional"]).split(","):
        assert dependency in package_ids | {"-", "vscode-extensions"}, f"Unknown dependency: {dependency}"
    for platform in supported:
        assert any(row["tool"] == tool["id"] and platform in row["platforms"].split(",") for row in targets), f"No target for {tool['id']} on {platform}"

for target in targets:
    assert target["tool"] in tool_map, target
    assert set(target["platforms"].split(",")) <= set(tool_map[target["tool"]]["platforms"].split(",")), target
    assert target["kind"] in {"file", "directory", "absent"}, target
    assert ".." not in Path(target["source"]).parts, target
    assert ".." not in target["destination"].split("/"), target
    assert set(re.findall(r"\{([^}]+)\}", target["destination"])) <= VARIABLES, target
    source = ROOT / target["source"]
    if target["kind"] == "absent":
        assert target["source"] == "-", target
    else:
        assert source.exists() and not source.is_symlink(), f"Missing or linked source: {source}"
        assert source.is_dir() == (target["kind"] == "directory"), target
        if source.is_dir():
            assert not any(path.is_symlink() for path in source.rglob("*")), source
    for other in targets:
        if target is other or target["tool"] != other["tool"]:
            continue
        if not set(target["platforms"].split(",")) & set(other["platforms"].split(",")):
            continue
        assert target["destination"] != other["destination"], f"Duplicate destination: {target}"
        assert not other["destination"].startswith(target["destination"] + "/"), f"Overlapping tool targets: {target} and {other}"

for package in packages:
    for manager, name in package.items():
        if manager == "id" or name == "-":
            continue
        assert re.fullmatch(r"(?:--cask )?[A-Za-z0-9][A-Za-z0-9.+_-]*", name), f"Unsafe package arguments: {package}"

for relative in ["config/nvim/common/lazy-lock.json", "config/windows-terminal/windows/settings.json", "config/zebar/windows/settings.json"]:
    json.loads((ROOT / relative).read_text(encoding="utf-8"))
assert not list((ROOT / "config").rglob("fish_variables")), "Runtime fish state is tracked"

markdown = [ROOT / "README.md", ROOT / "AGENTS.md"] + list((ROOT / "docs").rglob("*.md")) + list((ROOT / ".github").rglob("*.md"))
for path in markdown:
    for link in re.findall(r"\[[^\]]+\]\(([^)]+)\)", path.read_text(encoding="utf-8")):
        if re.match(r"[a-z]+:", link) or link.startswith("#"):
            continue
        destination = unquote(link.split("#", 1)[0])
        assert (path.parent / destination).exists(), f"Broken link in {path.relative_to(ROOT)}: {link}"

print(f"PASS: {len(tools)} tools, {len(targets)} targets, package/version catalogs, config JSON, and documentation links.")
