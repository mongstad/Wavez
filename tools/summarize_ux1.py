"""Retain compact UX1 audit evidence and verify proposed contrast/source invariance."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASELINE = "47fef34dc5bdcbbc8db7f562f778deb100a70d5c"
COLORS = {
    "surface.0": "15171B", "surface.1": "1C1F24", "surface.2": "252930", "surface.3": "2D323A",
    "text.primary": "E6EAF0", "text.secondary": "B9C1CC", "text.muted": "9AA5B3",
    "text.disabled": "737C89", "text.numeric": "E6EAF0", "border.control": "707D8E",
    "focus.ring": "A8C9FF", "accent.primary": "8CB8FF", "accent.foreground": "142035",
    "selection.fill": "263F62", "selection.text": "DCEAFF", "state.success": "7FD1A7",
    "state.warning": "E8BF72", "state.error": "F08C91", "state.info": "9CBEE8",
}
IMAGES = [
    "01-empty", "03-loaded-default", "04-width-290", "05-playback", "06-export-actions",
    "07-video-dialog", "07-video-actions", "08-recipe-dialog", "10-selections", "11-temporal-plot",
    "12-hidden", "13-window-1280x720", "14-4k-scaled-target", "layer-surface", "layer-density",
]


def luminance(color):
    values = [int(color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    values = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in values]
    return sum(v * weight for v, weight in zip(values, [.2126, .7152, .0722]))


def contrast(a, b):
    low, high = sorted([luminance(COLORS[a]), luminance(COLORS[b])])
    return (high + .05) / (low + .05)


def write(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit-dir", type=Path, required=True)
    parser.add_argument("--evidence-dir", type=Path, required=True)
    args = parser.parse_args()
    source, destination = args.audit_dir.resolve(), args.evidence_dir.resolve()
    if source == destination:
        parser.error("Keep raw and retained evidence directories separate")
    destination.mkdir(parents=True, exist_ok=True)
    audit = json.loads((source / "audit.json").read_text())
    assert audit["baseline"] == BASELINE and not audit["failures"]
    spec = (ROOT / "docs/UX1_DESIGN_SYSTEM.md").read_text()
    assert all("#" + value in spec for value in COLORS.values())
    pairs = []
    foregrounds = ["text.primary", "text.secondary", "text.muted", "text.numeric", "accent.primary",
                   "state.success", "state.warning", "state.error", "state.info", "focus.ring", "border.control"]
    for foreground in foregrounds:
        for i in range(4):
            background = f"surface.{i}"
            target = 3.0 if foreground in ["focus.ring", "border.control"] else 4.5
            ratio = contrast(foreground, background)
            pairs.append(dict(foreground=foreground, background=background, ratio=round(ratio, 3), target=target, passed=ratio >= target))
    for foreground, background in [("accent.foreground", "accent.primary"), ("selection.text", "selection.fill")]:
        ratio = contrast(foreground, background)
        pairs.append(dict(foreground=foreground, background=background, ratio=round(ratio, 3), target=4.5, passed=ratio >= 4.5))
    assert all(pair["passed"] for pair in pairs), pairs
    write(destination / "contrast.json", dict(status="PASS", purpose="Proposed UX1 palette only; not current UI accessibility certification", colors=COLORS, pairs=pairs))
    paths = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", BASELINE], cwd=ROOT, text=True).splitlines()
    protected = [name for name in paths if name.startswith(("viewer/", "wavez_export/", "examples/", "tests/"))]
    unchanged = []
    for name in protected:
        original = subprocess.check_output(["git", "show", BASELINE + ":" + name], cwd=ROOT)
        current = (ROOT / name).read_bytes()
        assert original == current, name
        unchanged.append(dict(path=name, sha256=hashlib.sha256(current).hexdigest()))
    write(destination / "source-invariance.json", dict(baseline=BASELINE, status="PASS", count=len(unchanged), files=unchanged))
    counts = Counter(row["class"] for row in audit["inventory"])
    summary = {k: v for k, v in audit.items() if k not in ["inventory", "observations"]}
    summary["control_count"] = len(audit["inventory"])
    summary["control_counts"] = dict(sorted(counts.items()))
    summary["count_scope"] = "Constructed non-internal descendants, includes hidden and video controls; not simultaneously visible controls"
    summary["observations"] = [{k: v for k, v in row.items() if k != "controls"} for row in audit["observations"]]
    summary["images"] = []
    for name in IMAGES:
        path = source / (name + ".png")
        shutil.copyfile(path, destination / path.name)
        summary["images"].append(dict(file=path.name, bytes=path.stat().st_size, sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    write(destination / "summary.json", summary)
    write(destination / "control-inventory.json", [{k: row[k] for k in ["class", "path", "text", "font_size", "focus_mode", "tooltip", "options", "disabled"] if k in row} for row in audit["inventory"]])
    shutil.copyfile(source / "audit.log.txt", destination / "audit.log.txt")
    shutil.copyfile(source / "hud.log.txt", destination / "hud.log.txt")
    shutil.copyfile(source / "hud/after.json", destination / "hud.json")
    print(json.dumps(dict(status="PASS", palette_pairs=len(pairs), unchanged_files=len(unchanged), audit_checks=len(audit["checks"]), retained_images=len(IMAGES))))


if __name__ == "__main__":
    main()
