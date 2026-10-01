"""Classify remaining old-brand references and preserve issue-155 historical evidence."""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = "d6e4bd8e19e8c5e187c6a7c263c9bacdcd80bdbe"
HISTORICAL_DOCS = ['G2_STORAGE.md',
 'G3_REPORT.md',
 'G3_TIMELINE_FIX.md',
 'G4_DESIGN.md',
 'G4_REPORT.md',
 'PLAYBACK_PERFORMANCE.md',
 'PROVENANCE.md',
 'SIMSCOPE_ACCEPTANCE_MATRIX.md',
 'SIMSCOPE_NEXT_DESIGN.md',
 'docs/ABOUT_SIMSCOPE.md',
 'docs/BACKGROUND_EXPORT_VALIDATION.md',
 'docs/CAMERA_TUMBLE_VALIDATION.md',
 'docs/CURRENT_STATUS.md',
 'docs/CUSTOM_ORBIT.md',
 'docs/DYNAMIC_FIELD_PREPARATION.md',
 'docs/EVIDENCE_INDEX.md',
 'docs/EXIT_MENU.md',
 'docs/EXPERIMENT_LESSONS.md',
 'docs/FIELD_PREPARATION_BUDGET.md',
 'docs/FILE_DIALOGS.md',
 'docs/FULLSCREEN_RESTORE_VALIDATION.md',
 'docs/G4_ACCEPTANCE.md',
 'docs/LAYER_LEGENDS.md',
 'docs/LEGEND_CARD_REVIEW.md',
 'docs/LEGEND_CONTENT_LAYOUT.md',
 'docs/LEGEND_DEFAULTS.md',
 'docs/LEGEND_INITIAL_LAYOUT_VALIDATION.md',
 'docs/LEGEND_PLACEMENT_VALIDATION.md',
 'docs/LEGEND_VISIBILITY_VALIDATION.md',
 'docs/LOAD_ERROR_RECOVERY.md',
 'docs/MAINTENANCE_REPORT.md',
 'docs/MESH_PLAYBACK_MAINTENANCE_REPORT.md',
 'docs/ORBIT_CENTER.md',
 'docs/PANEL_DISCLOSURE_VALIDATION.md',
 'docs/PARALLEL_FIELD_PREPARATION.md',
 'docs/PAUSED_RENDERING.md',
 'docs/PERFORMANCE_MAINTENANCE_REPORT.md',
 'docs/PLAYBACK_INTEGRITY.md',
 'docs/PLAYBACK_RUNWAY_REVIEW.md',
 'docs/PROBE_MARKER_VALIDATION.md',
 'docs/ROLLING_PLAYBACK_CACHE.md',
 'docs/SSC_ACCELERATION.md',
 'docs/SSC_ADAPTIVE_CACHE.md',
 'docs/SSC_CAPTURE_PARAMETERS.md',
 'docs/SSC_CHANNEL_SWITCH_STABILITY.md',
 'docs/SSC_CONTINUOUS_PLAYBACK.md',
 'docs/SSC_LAZY_LOADING.md',
 'docs/SSC_LOAD_PERFORMANCE.md',
 'docs/SSC_METADATA_BUDGET.md',
 'docs/STATUS_PLAYBACK_STATE.md',
 'docs/TIMELINE_ENDPOINTS.md',
 'docs/UX1_REPORT.md',
 'docs/UX1_UI_AUDIT.md',
 'docs/UX2_REPORT.md',
 'docs/UX3_FULLSCREEN.md',
 'docs/UX3_MEDIA_TRANSPORT.md',
 'docs/UX3_REPORT.md',
 'docs/UX3_SHELL.md',
 'docs/UX3_STATUS.md',
 'docs/UX3_TRANSIENT_STATUS.md',
 'docs/UX3_TRANSPORT.md',
 'docs/UX4_DESIGN.md',
 'docs/UX4_MENUS.md',
 'docs/UX4_PANEL.md',
 'docs/UX4_TOOLS.md',
 'docs/UX5_CLEANUP.md',
 'docs/UX5_STYLE_SLICE.md',
 'docs/UX_IA_REVIEW.md',
 'docs/UX_STYLE_VALIDATION.md',
 'docs/VERSIONING_VALIDATION.md',
 'docs/VIDEO_ACTIONS_VALIDATION.md',
 'docs/VIDEO_CANCEL_CONFIRMATION.md',
 'docs/VIDEO_EXPORT_LOCKS.md',
 'docs/VIDEO_PROGRESS_VALIDATION.md',
 'docs/VIDEO_REGRESSION.md',
 'docs/VIDEO_STARTUP_116.md',
 'docs/VIEW_PRESETS.md',
 'docs/VOLUME_COLOR_NORMALIZATION.md',
 'docs/VOLUME_DEFAULTS_VALIDATION.md',
 'docs/VOLUME_DISPLAY_PRESETS.md',
 'docs/VOLUME_OPACITY_MAPPING.md',
 'docs/WINDOW_EDGE_REVEAL.md',
 'viewer/ui/about/README.md']
# Historical records retain names/commands from their original checkpoint.
RULES = {
    "serialized compatibility kind": r"simscope-(?:inspection|view-preset|export-source|matched-render|export-staging|numerical-export|member-cache)",
    "diagnostic environment contract": r"SIMSCOPE_(?:FIELD_WORKERS|METADATA_BUDGET_MIB|VIDEO_PROFILE)",
    "cache and staging location": r"\.simscope-(?:cache|export-)",
    "working repository URL": r"github\.com/mongstad/SimScope",
    "existing user data directory": r"(?:Godot|godot)/app_userdata/SimScope",
    "stable documentation filename": r"(?:SIMSCOPE_(?:API|HANDBOOK|ACCEPTANCE_MATRIX|NEXT_DESIGN)|ABOUT_SIMSCOPE)\.md",
    "existing checkout and board": r"`SimScope/?`|SimScope Development",
    "external historical fixture path": r"(?:02B|03B)/simscope/",
}


def audit():
    names = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard"], cwd=ROOT, text=True).splitlines()
    rows, unknown = [], []
    for name in sorted(set(names)):
        path = ROOT / name
        if not path.is_file(): continue
        if name in {"tools/audit_branding.py", "docs/branding/legacy-reference-audit.json"}:
            continue  # Explicit classification vocabulary and its generated report.
        if "simscope" in name.lower():
            category = "historical evidence path" if name.startswith("docs/evidence/") else "stable documentation filename" if re.search(RULES["stable documentation filename"], name) else None
            entry = dict(file=name, line=0, categories=[category] if category else [])
            (rows if category else unknown).append(entry)
        raw = path.read_bytes()
        try: text = raw.decode("utf-8")
        except UnicodeDecodeError:
            if re.search(b"simscope", raw, re.I):
                entry = dict(file=name, line=0, categories=["historical binary evidence"])
                (rows if name.startswith("docs/evidence/") else unknown).append(entry)
            continue
        for number, line in enumerate(text.splitlines(), 1):
            if not re.search("simscope", line, re.I): continue
            if name.startswith("docs/evidence/") or name in HISTORICAL_DOCS:
                categories = ["historical report, provenance or checkpoint"]
            elif name == "viewer/ui/test_branding.gd" and 'contains("simscope")' in line:
                categories = ["old-brand regression assertion"]
            elif name == "docs/BRANDING_MIGRATION.md":
                categories = ["explicit migration explanation"]
            elif name == "README.md" and line.startswith("The project was renamed from SimScope under #155."):
                categories = ["explicit migration explanation"]
            elif name == ".gitignore" and line == ".simscope-*/":
                categories = ["cache and staging location"]
            else:
                categories = []
                remaining = line
                for category, pattern in RULES.items():
                    if re.search(pattern, remaining):
                        categories.append(category)
                        remaining = re.sub(pattern, "", remaining)
                if re.search("simscope", remaining, re.I):
                    unknown.append(dict(file=name, line=number, text=line)); continue
            rows.append(dict(file=name, line=number, categories=categories))
    # Evidence is immutable; do not silently update baseline hashes to bless a rewrite.
    changed_evidence = subprocess.check_output(["git", "diff", "--name-only", BASE, "--", "docs/evidence"], cwd=ROOT, text=True).splitlines()
    rewritten_history = []
    for name in HISTORICAL_DOCS:
        # These four have a current branding note / link repair; their original history is inspected separately.
        if name in {"G4_DESIGN.md", "docs/ABOUT_SIMSCOPE.md", "docs/CURRENT_STATUS.md", "viewer/ui/about/README.md"}: continue
        original = subprocess.check_output(["git", "show", BASE + ":" + name], cwd=ROOT)
        if (ROOT / name).read_bytes() != original: rewritten_history.append(name)
    counts = Counter(category for row in rows for category in row["categories"])
    return dict(status="FAIL" if unknown or changed_evidence or rewritten_history else "PASS", base=BASE,
                references=len(rows), categories=dict(counts), unclassified=unknown,
                changed_historical_evidence=changed_evidence, rewritten_historical_documents=rewritten_history,
                survivors=rows)


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
