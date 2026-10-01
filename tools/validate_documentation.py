"""Check repository Markdown links and execute the three modern API examples."""
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


def validate():
    files = subprocess.check_output(
        ["rg", "--files", "-g", "*.md", "-g", "!results/**"], cwd=ROOT, text=True
    ).splitlines()
    missing = []
    for name in files:
        path = ROOT / name
        for target in re.findall(r"\]\((<?[^)]+>?)\)", path.read_text()):
            target = unquote(target.strip("<>").split("#")[0])
            if target and "://" not in target and not target.startswith("mailto:"):
                if not (path.parent / target).exists():
                    missing.append(dict(document=name, target=target))
    examples = []
    cases = [
        ("SIMSCOPE_API.md", "## Minimal executable example", "example.ssc", "rho", "m", "kg/m^3"),
        ("docs/SIMULATION_INTEGRATION_GUIDE.md", "## Small native example", "example.ssc", "density", "m", "amplitude squared"),
        ("G3_GUIDE.md", "## Write actual data", "new-scene.ssc", "value", "world units", "scalar units"),
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
                missing_local_links=missing, examples=examples)


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
