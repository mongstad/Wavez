"""Read the authoritative WAVEZ application identity without starting Godot."""
import argparse
import configparser
import json
from pathlib import Path
import re

PROJECT = Path(__file__).resolve().parents[1] / "viewer" / "project.godot"
PATTERN = re.compile(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.([1-9][0-9]*)")


def read_version(project: Path = PROJECT) -> dict[str, str]:
    # Godot has a header assignment before its INI-style sections. JSON decoding
    # handles the quoted string; no Godot installation or Python package import.
    config = configparser.ConfigParser(interpolation=None)
    try:
        config.read_string("[header]\n" + project.read_text(encoding="utf-8"))
        value = json.loads(config["application"]["config/version"])
    except (OSError, configparser.Error, KeyError, ValueError) as error:
        raise ValueError(f"Cannot read WAVEZ application/config/version from {project}: {error}") from error
    match = PATTERN.fullmatch(value) if isinstance(value, str) else None
    if match is None:
        raise ValueError("Invalid application/config/version: expected vMAJOR.MINOR.PATCH.BUILD with canonical non-negative release numbers and a positive BUILD")
    return dict(full=value, release="v" + ".".join(match.groups()[:3]), build=match[4])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=PROJECT, help="Path to project.godot")
    formats = parser.add_mutually_exclusive_group()
    formats.add_argument("--release", action="store_true", help="Print only vMAJOR.MINOR.PATCH")
    formats.add_argument("--json", action="store_true", help="Print full, release and build fields")
    args = parser.parse_args()
    try:
        identity = read_version(args.project)
    except ValueError as error:
        parser.exit(1, f"{error}\n")
    print(json.dumps(identity) if args.json else identity["release" if args.release else "full"])


if __name__ == "__main__":
    main()
