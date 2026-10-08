"""Check Markdown files/anchors/Git permalinks and execute modern API examples."""
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export.analysis import SourceSnapshot
from wavez_export.analysis import channel_semantics as semantics


def anchors(text):
    """GitHub-style heading IDs, excluding fenced code and supporting duplicates."""
    result, counts = set(), {}
    fenced = False
    for line in text.splitlines():
        if line.lstrip().startswith(("```", "~~~")):
            fenced = not fenced
            continue
        if fenced:
            continue
        match = re.match(r"^#{1,6}\s+(.+?)\s*#*\s*$", line)
        if not match:
            continue
        title = re.sub(r"<[^>]+>", "", match[1]).lower()
        title = re.sub(r"[^\w\- ]", "", title).replace(" ", "-")
        count = counts.get(title, 0)
        counts[title] = count + 1
        result.add(title + (f"-{count}" if count else ""))
    result.update(re.findall(r'<a\s+(?:name|id)=["\']([^"\']+)', text))
    return result


def links(files):
    missing, checked, permalinks = [], 0, 0
    contents = {}
    for name in files:
        path = ROOT / name
        text = path.read_text()
        targets = re.findall(r"\]\((<?[^)\n]+>?)\)", text)
        targets += re.findall(r"^\s*\[[^\]]+\]:\s*(\S+)", text, re.M)
        for raw in targets:
            target = unquote(raw.strip("<>"))
            local, _, fragment = target.partition("#")
            historical = re.fullmatch(r"https://github.com/mongstad/Wavez/blob/([0-9a-f]{40})/(.+)", local)
            if historical:
                key = historical[1] + ":" + historical[2]
                if key not in contents:
                    found = subprocess.run(["git", "show", key], cwd=ROOT, capture_output=True)
                    contents[key] = found.stdout.decode("utf-8") if found.returncode == 0 else None
                body = contents[key]
                permalinks += 1
                if body is None:
                    missing.append(dict(document=name, target=target, reason="missing Git object"))
                elif fragment and fragment not in anchors(body):
                    missing.append(dict(document=name, target=target, reason="missing Git heading"))
                continue
            if "://" in local or local.startswith("mailto:"):
                continue
            destination = (path.parent / local) if local else path
            checked += 1
            if not destination.exists():
                missing.append(dict(document=name, target=target, reason="missing local file"))
            elif fragment and destination.suffix == ".md" and fragment not in anchors(destination.read_text()):
                missing.append(dict(document=name, target=target, reason="missing local heading"))
    return missing, checked, permalinks


def validate():
    files = subprocess.check_output(
        ["rg", "--files", "-g", "*.md", "-g", "!results/**"], cwd=ROOT, text=True
    ).splitlines()
    missing, checked, permalinks = links(files)
    examples = []
    cases = [
        ("WAVEZ_API.md", "## Minimal executable example", "example.wvz", "rho", "m", "kg/m^3"),
        ("docs/SIMULATION_INTEGRATION_GUIDE.md", "## Small native example", "example.wvz", "density", "m", "amplitude squared"),
        ("docs/SCENE_CAPTURE_GUIDE.md", "## Write actual data", "new-scene.wvz", "value", "world units", "scalar units"),
    ]
    for name, marker, capture, channel, position_unit, channel_unit in cases:
        doc = (ROOT / name).read_text()
        code = re.search(r"```python\n(.*?)```", doc.split(marker, 1)[1], re.S)[1]
        previous = Path.cwd()
        with tempfile.TemporaryDirectory(prefix="wavez-doc-") as directory:
            os.chdir(directory)
            try:
                exec(compile(code, name, "exec"), {})
                before = hashlib.sha256(Path(capture).read_bytes()).hexdigest()
                with SourceSnapshot(capture) as source:
                    assert semantics.time_unit(source) == "s"
                    assert semantics.position_unit(source, "field") == position_unit
                    assert semantics.declaration(source, "field", dict(channel=channel))["units"] == channel_unit
                assert hashlib.sha256(Path(capture).read_bytes()).hexdigest() == before
                examples.append(dict(document=name, status="PASS", source_unchanged=True,
                                     document_sha256=hashlib.sha256(doc.encode()).hexdigest()))
            finally:
                os.chdir(previous)
    return dict(status="FAIL" if missing else "PASS", documents=sorted(files),
                missing_local_links=missing, checked_local_links=checked,
                checked_git_permalinks=permalinks, examples=examples)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    try:
        report = validate()
    except Exception as error:
        report = dict(status="FAIL", error=f"{type(error).__name__}: {error}")
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
