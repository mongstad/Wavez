"""Audit current WAVEZ paths for retired SimScope and SIMSCP4 identities.

Old terms in historical reports remain accurate evidence. Negative tests may
name them only to establish refusal. The generated report classifies every
remaining tracked occurrence for owner review.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
LEGACY = re.compile(r"SimScope|simscope|SIMSCP[0-9]*|\.ssc\b|FRM4|COMMIT4|SIMSCOPE_|\.simscope|\.sidx3|verify_ssc|profile_ssc", re.I)
ACTIVE_ROOTS = {"wavez_export", "viewer", "tools", "tests", "examples"}
CURRENT_DOCS = {
    "AGENTS.md", "CONTRIBUTING.md", "README.md", "QUICKSTART.md",
    "docs/WVZ1_FORMAT.md", "docs/SCENE_CAPTURE_GUIDE.md", "WAVEZ_API.md", "INSPECTION_STATE.md",
    "docs/START_HERE.md", "docs/CAPTURE_FORMAT_POLICY.md",
    "docs/CAPTURE_FORMAT_AND_API.md", "docs/SIMULATION_INTEGRATION_GUIDE.md",
    "docs/WAVEZ_HANDBOOK.md", "docs/WAVEZ_METADATA_BUDGET.md",
    "docs/WAVEZ_VIEW_PRESETS.md", "docs/ANALYSIS_SCHEMAS.md",
    "docs/SCIENTIFIC_ANALYSIS.md", "docs/SCIENTIFIC_ACCEPTANCE.md",
    "docs/ANALYSIS_GUIDE.md", "docs/UX_WORKFLOW.md", "docs/VIDEO_EXPORT.md",
    "docs/WVZ1_IMPLEMENTATION_VALIDATION.md",
}
NEGATIVE_TESTS = {
    "tests/test_scene_contract.py", "tools/validate_field_session.py",
    "viewer/layers/test_field_session.gd", "viewer/layers/test_scene_playback_lifecycle.gd",
    "viewer/ui/test_branding.gd",
    "tests/test_analysis_recipes.py", "viewer/scene/test_view_preset.gd",
    "viewer/video/test_source_identity.gd",
}
EXPLANATORY_CURRENT_DOCS = {
    "docs/CAPTURE_FORMAT_POLICY.md", "docs/WAVEZ_METADATA_BUDGET.md",
    "docs/WAVEZ_VIEW_PRESETS.md",
    "docs/WVZ1_IMPLEMENTATION_VALIDATION.md",
}
MIXED_HISTORICAL_DOCS = {
    "docs/FILE_DIALOGS.md",
    "docs/PLAYBACK_INTEGRITY.md", "docs/VIEW_PRESETS.md",
}


def classify(name, line, text=""):
    without_historical_urls = re.sub(r"https://github\.com/mongstad/Wavez/blob/[0-9a-f]{40}/[^\s)>]+", "", text)
    if LEGACY.search(text) and not LEGACY.search(without_historical_urls):
        return "fixed Git reference to historical source"
    if name in NEGATIVE_TESTS:
        return "negative refusal test"
    if name in EXPLANATORY_CURRENT_DOCS:
        return "explicit obsolete-format refusal or historical link"
    if name in MIXED_HISTORICAL_DOCS:
        if name == "docs/FILE_DIALOGS.md" and line <= 7:
            return "explicit historical preface"
        if name == "docs/PLAYBACK_INTEGRITY.md" and line <= 8:
            return "explicit historical preface"
        return "historical review-time section"
    if name in CURRENT_DOCS or name.split('/')[0] in ACTIVE_ROOTS or name == '.gitignore':
        return None
    return "historical document or evidence"


def historical_content_changes(names):
    """Permit navigation repairs while preserving recorded evidence bodies."""
    changed = []
    for name in names:
        path = ROOT / name
        original = subprocess.run(["git", "show", "origin/main:" + name], cwd=ROOT, capture_output=True)
        if original.returncode:
            # New review evidence has no historical body to protect.
            continue
        before = original.stdout
        after = path.read_bytes() if path.is_file() else b""
        if before == after:
            continue
        if path.suffix == ".md":
            # Only Markdown destinations may differ; labels/outcomes remain exact.
            destinations = rb"\]\([^\n)]+\)"
            if re.sub(destinations, b"](LINK)", before) == re.sub(destinations, b"](LINK)", after):
                continue
        changed.append(name)
    return changed


def audit():
    names = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard"], cwd=ROOT, text=True).splitlines()
    rows, unknown = [], []
    for name in sorted(set(names)):
        if name in {"tools/audit_branding.py", "docs/branding/legacy-reference-audit.json"}:
            continue
        path = ROOT / name
        if not path.is_file():
            continue
        filename_match = LEGACY.search(name)
        if filename_match:
            category = classify(name, 0, name)
            entry = dict(file=name, line=0, text=name, category=category)
            (rows if category else unknown).append(entry)
        try:
            lines = path.read_text().splitlines()
        except (UnicodeDecodeError, ValueError):
            continue
        for number, line in enumerate(lines, 1):
            if not LEGACY.search(line):
                continue
            category = classify(name, number, line)
            entry = dict(file=name, line=number, text=line, category=category)
            (rows if category else unknown).append(entry)
    evidence_diff = subprocess.check_output(["git", "diff", "--name-only", "origin/main", "--", "docs/evidence"], cwd=ROOT, text=True).splitlines()
    changed_evidence = historical_content_changes(evidence_diff)
    counts = Counter(row["category"] for row in rows)
    return dict(status="PASS" if not unknown and not changed_evidence else "FAIL",
                references=len(rows), categories=dict(counts), unclassified=unknown,
                changed_historical_evidence=changed_evidence, survivors=rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = audit()
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({key: value for key, value in report.items() if key != "survivors"}, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
