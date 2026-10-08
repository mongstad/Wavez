"""Focused #212 Auto Orbit editor checks; synthetic events stay inside Godot."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture
from tools.package_linux import build, stage


def fixtures(out):
    for kind in ("particles", "field", "mesh", "mixed"):
        for name, scale in (("small", .01), ("large", 1000.)):
            objects = []
            if kind in ("particles", "mixed"):
                objects.append(dict(id="p", kind="particles", identity="persistent_i8", units="m"))
            if kind in ("field", "mixed"):
                objects.append(dict(id="field", kind="volume", units="m"))
            if kind in ("mesh", "mixed"):
                objects.append(dict(id="mesh", kind="mesh", identity="stable_topology", units="m"))
            with SceneCapture(out / f"{kind}-{name}.wvz", objects=objects, compression="none") as writer:
                for time in (0., 1.):
                    points = (np.array([[-2, 0, 0], [2, 0, 0], [0, 3, 1]], dtype="f8") + [0, 0, time]) * scale
                    if kind in ("particles", "mixed"):
                        writer.add_particles("p", time, points, ids=np.array([7, 9007199254740993, 2**63-1], dtype="i8"))
                    if kind in ("field", "mixed"):
                        z, y, x = np.indices((5, 6, 7))
                        writer.add_volume("field", time, dict(density=(x+2*y+3*z+time).astype("f8")), origin=np.array([-3,-3,-2])*scale, spacing=np.ones(3)*scale)
                    if kind in ("mesh", "mixed"):
                        writer.add_mesh("mesh", time, points, np.array([[0,1,2]]), vertex_channels=dict(vertex_id=np.array([7,8,9], dtype="i8")))


def dense_fixture(out):
    z, y, x = np.indices((32, 32, 32))
    density = (.6 + .2*np.sin(x*.4) + .1*np.cos(y*.3) + .1*np.sin(z*.5)).astype("f8")
    with SceneCapture(out / "dense-field.wvz", objects=[dict(id="field", kind="volume", units="m")], compression="none") as writer:
        writer.add_volume("field", 0., dict(density=density), origin=[-8.,-8.,-8.], spacing=[16./31]*3)


def equator_fixtures(out):
    # Asymmetric three-lobe phi field and L-shaped solid, with a second set
    # whose recorded values evolve. All object coordinate frames stay fixed.
    z, y, x = np.indices((32, 32, 32))
    x, y, z = (v*.35-4 for v in (x, y, z))
    phi = (np.exp(-((x-2)**2+(y-1)**2+(z+1)**2)/.8)
           + .65*np.exp(-((x+1)**2+(y+1)**2+z*z)/1.4)
           + .4*np.exp(-((x-1)**2+(y-3)**2+(z-2)**2)/.5))
    vertices, triangles = [], []
    for low, high in (([-1,-1,-1], [2,-.4,-.4]), ([-1,-1,-1], [-.4,1.6,-.4])):
        base = len(vertices)
        vertices.extend([[a,b,c] for a in (low[0],high[0]) for b in (low[1],high[1]) for c in (low[2],high[2])])
        triangles.extend([[base+a,base+b,base+c] for a,b,c in
                          ((0,1,3),(0,3,2),(4,6,7),(4,7,5),(0,4,5),(0,5,1),
                           (2,3,7),(2,7,6),(0,2,6),(0,6,4),(1,5,7),(1,7,3))])
    vertices = np.asarray(vertices, dtype="f8") + [2,1,-1]
    rng = np.random.default_rng(212)
    points = np.concatenate([rng.normal(c, .15, (40,3)) for c in ([2,1,-1],[-1,-1,0],[1,3,2])])
    for kind in ("particles", "field", "mesh", "mixed"):
        objects = [dict(id=id, kind=type, units="m", **identity) for id,type,identity in
                   (("p","particles",dict(identity="persistent_i8")), ("field","volume",{}),
                    ("mesh","mesh",dict(identity="stable_topology")))
                   if kind == "mixed" or kind == dict(p="particles",field="field",mesh="mesh")[id]]
        for evolving in (False, True):
            with SceneCapture(out / f"equator-{kind}-{'evolving' if evolving else 'stationary'}.wvz",
                              objects=objects, compression="none") as writer:
                for time in (0.,1.,2.):
                    change = time if evolving else 0.
                    if kind in ("particles","mixed"):
                        writer.add_particles("p",time,points+[.4*change,0,0],ids=np.arange(len(points),dtype="i8"))
                    if kind in ("mesh","mixed"):
                        writer.add_mesh("mesh",time,vertices+[0,.2*change,0],np.asarray(triangles),vertex_channels=dict(vertex_id=np.arange(len(vertices),dtype="i8")))
                    if kind in ("field","mixed"):
                        writer.add_volume("field",time,dict(phi=(phi*(1+.25*change)).astype("f8")),origin=[-4]*3,spacing=[.35]*3)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="External Godot executable or exported Linux executable")
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--renderer", choices=["headless", "forward_plus", "gl_compatibility"], default="headless")
    parser.add_argument("--project", type=Path, default=ROOT / "viewer")
    parser.add_argument("--packaged", action="store_true")
    parser.add_argument("--export", action="store_true", help="Build a temporary release validation package with a test entry scene")
    parser.add_argument("--baseline-probe", action="store_true")
    parser.add_argument("--placement-refinement", action="store_true", help="Run the automatic placement anchor and shaded-guide refinement")
    parser.add_argument("--equator-refinement", action="store_true", help="Check a stable Apply-time equator, asymmetric world references and evolving playback")
    args = parser.parse_args()
    if args.export and args.packaged: parser.error("Choose --export or an existing --packaged validation executable")
    if args.placement_refinement and args.equator_refinement: parser.error("Choose one refinement driver")
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    fixtures(out)
    if args.placement_refinement: dense_fixture(out)
    if args.equator_refinement: equator_fixtures(out)
    driver = "test_orbit_center_equator.gd" if args.equator_refinement else ("test_orbit_center_placement.gd" if args.placement_refinement else "test_orbit_center_view.gd")
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob("*.wvz")}
    env = dict(os.environ, XDG_CONFIG_HOME=str(out / "config"), XDG_DATA_HOME=str(out / "userdata"))
    executable = args.godot
    package = None
    if args.export:
        project = out / "export-source"
        inventory = stage(project)
        script = (project / "ui/shell" / driver).read_text()
        if args.placement_refinement or args.equator_refinement:
            parent = (project / "ui/shell/test_orbit_center_view.gd").read_text()
            # Inline the existing helpers; the refinement supplies its own run.
            script = parent[:parent.index("func run() -> void:")] + script.split("\n", 1)[1]
        script = script.replace("extends SceneTree", "extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame")
        script = script.replace("func _initialize()", "func _ready()").replace("create_timer(", "get_tree().create_timer(").replace("quit(", "get_tree().quit(")
        (project / "ui/shell/orbit_center_view_entry.gd").write_text(script)
        (project / "OrbitCenterViewValidation.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://ui/shell/orbit_center_view_entry.gd" id="1"]\n[node name="OrbitCenterViewValidation" type="Node"]\nscript = ExtResource("1")\n')
        config = project / "project.godot"
        config.write_text(config.read_text().replace('run/main_scene="res://Main.tscn"', 'run/main_scene="res://OrbitCenterViewValidation.tscn"'))
        binary = out / "WAVEZ-validation.x86_64"
        build(args.godot, project, binary, out / "build-logs")
        executable = str(binary)
        args.packaged = True
        package = dict(test_entry_scene=True, first_party_python=inventory,
                       artifacts={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in [binary, binary.with_suffix('.pck')]})
    command = [executable]
    imports = []
    if not args.packaged:
        command += ["--path", str(args.project.resolve())]
        for attempt in range(2):
            result = subprocess.run(command + ["--headless", "--editor", "--import"], env=env, capture_output=True, text=True, timeout=180)
            log = result.stdout + result.stderr
            (out / f"import-{attempt}.log").write_text(log)
            imports.append(dict(returncode=result.returncode, warnings=[line for line in log.splitlines() if "WARNING:" in line]))
            if result.returncode or "ERROR:" in log:
                raise RuntimeError(f"Import failed: {out / f'import-{attempt}.log'}")
            if "WARNING:" not in log: break
        else:
            raise RuntimeError(f"Unresolved import warnings: {out}")
    command += ["--headless"] if args.renderer == "headless" else ["--rendering-method", args.renderer]
    command += ["--resolution", "1440x900", "--audio-driver", "Dummy"]
    if not args.packaged: command += ["--script", "res://ui/shell/" + driver]
    command += ["--", "--orbit-view-output=" + str(out)]
    if args.baseline_probe: command.append("--baseline-probe")
    result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=210)
    log = result.stdout + result.stderr; (out / "native.log").write_text(log)
    report_path = out / "orbit-view-report.json"
    if not report_path.is_file(): raise RuntimeError(f"No completed report: {out / 'native.log'}")
    report = json.loads(report_path.read_text())
    unchanged = hashes == {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob("*.wvz")}
    report.update(returncode=result.returncode, source_hashes_unchanged=unchanged, source_sha256=hashes,
                  import_attempts=imports, packaged=args.packaged,
                  package_build=package,
                  diagnostics=[line for line in log.splitlines() if "ERROR:" in line or "WARNING:" in line])
    report["status"] = "PASS" if not report["failures"] and not report["diagnostics"] and unchanged and result.returncode == 0 else "FAIL"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(f"Orbit-center view: {report['checks']} checks, {len(report['failures'])} failures ({args.renderer}); {report['status']}")
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
