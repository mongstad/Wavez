"""Summarize opt-in profile_mesh_transport.gd observations without changing playback."""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import statistics


def distribution(values):
    ordered = sorted(values)
    if not ordered:
        return {}
    return {"count": len(ordered), "mean": statistics.mean(ordered),
            "p50": statistics.median(ordered),
            "p95": ordered[math.ceil(len(ordered) * .95) - 1],
            "p99": ordered[math.ceil(len(ordered) * .99) - 1], "max": ordered[-1]}


def summarize(case):
    rows = case["rows"]
    start = float(case["case"].get("start", 0))
    wall = case["wall_s"]
    before, after = case["before"]["cache"], case["after"]["cache"]
    completed = after["completed"] - before["completed"]
    holds, label_intervals, spans = [], [], []
    hold_start = label_start = None
    previous_label = rows[0]["timer"]
    timer_mismatches = 0
    commits = 0
    for row in rows:
        held = bool(row["wait"]) and row["committed"] == row["committed_before"]
        if held and hold_start is None:
            hold_start = row["wall_s"]
        if not held and hold_start is not None:
            holds.append(row["wall_s"] - hold_start)
            hold_start = None
        if row["committed"] != row["committed_before"]:
            commits += 1
        if row["timer"] != previous_label:
            if label_start is not None:
                label_intervals.append(row["wall_s"] - label_start)
            label_start, previous_label = row["wall_s"], row["timer"]
        whole = math.floor(max(0, row["committed"]))  # This capture starts at zero.
        expected = f"{whole // 60:02d}:{whole % 60:02d}" if whole < 3600 else f"{whole // 3600:02d}:{whole // 60 % 60:02d}:{whole % 60:02d}"
        timer_mismatches += row["timer"] != expected
        spans.extend(hi - lo for lo, hi in row["coverage"]["scene"])
    if hold_start is not None:
        holds.append(wall - hold_start)  # Last interval is right-censored.
    advanced = rows[-1]["committed"] - start
    draws = case["draws"]
    runway = []
    for row in rows:
        distance = 0.0
        for lo, hi in row["coverage"]["scene"]:
            if lo <= row["committed"] <= hi:
                distance = row["committed"] - lo if case["physical_rate"] < 0 else hi - row["committed"]
        runway.append(distance)
    return {
        "name": case["case"]["name"], "start": start, "wall_s": wall,
        "committed_end": rows[-1]["committed"], "recorded_per_wall_second": advanced / wall,
        "physical_rate": case["physical_rate"], "draw_callbacks_per_second": len(draws) / wall,
        "draw_interval_ms": distribution([(b-a)*1000 for a, b in zip(draws, draws[1:])]),
        "process_callbacks": len(rows), "process_delta_s": sum(r["delta_s"] for r in rows),
        "main_callback_ms": distribution([r["callback_ms"] for r in rows]),
        "commits_per_second": commits / wall, "worker_completed": completed,
        "worker_pairs_per_second": completed / wall,
        "worker_ms_per_completed_pair": (after["worker_ms"]-before["worker_ms"]) / completed if completed else None,
        "decode_ms_per_completed_pair": (after["decode_ms"]-before["decode_ms"]) / completed if completed and "decode_ms" in after else None,
        "decode_calls_delta": after.get("decode_calls", 0)-before.get("decode_calls", 0),
        "holds": distribution(holds), "hold_observed_s": sum(holds),
        "hold_method": "Consecutive callbacks with a wait reason and no committed-clock change; final hold may be partial",
        "timer_interval_s": distribution(label_intervals), "timer_mismatches": timer_mismatches,
        "status_counts": {s: sum(r["status"] == s for r in rows) for s in sorted({r["status"] for r in rows})},
        "peak_cache_bytes": max(r["cache_bytes"] for r in rows), "cpu_limit": case["after"]["cpu_limit"],
        "peak_staged": max(r["staged"] for r in rows),
        "peak_ready_pairs": max(len(r["ready_sequences"]) for r in rows),
        "final_ready_pairs": len(rows[-1]["ready_sequences"]),
        "peak_in_flight_bytes": max(r["in_flight_bytes"] for r in rows),
        "coverage_span_seconds": distribution(spans),
        "directional_ready_runway_seconds": distribution(runway),
        "peak_decoded_bytes": max(r.get("decoded_bytes", 0) for r in rows),
        "peak_decoded_samples": max(r.get("decoded_samples", 0) for r in rows),
        "peak_active_jobs": max(r.get("active_jobs", 0) for r in rows),
        "pipeline_phase_ms_per_completed_pair": {
            key: (value - before.get("pipeline_stages", {}).get(key, 0)) / completed
            for key, value in after.get("pipeline_stages", {}).items()} if completed else {},
        "peak_sampled_rss_bytes": max((s["memory"]["process_rss"] for s in case.get("memory_samples", [])), default=0),
        "peak_sampled_swap_bytes": max((s["memory"]["process_swap"] for s in case.get("memory_samples", [])), default=0),
        "first_row": rows[0], "last_row": rows[-1],
        "cache_failures": after["failures"], "pressure_failures": after["pressure_failures"],
        "errors": case["errors"], "profile": case["profile"], "memory_after": case.get("memory_after"),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("raw", nargs="+", type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    summary, trace = [], []
    for path in args.raw:
        report = json.loads(path.read_text())
        if report["first"] != 0:
            raise ValueError("This investigation's timer oracle expects the zero-origin cavity capture")
        cases = []
        for case in report["cases"]:
            cases.append(summarize(case))
            rows = case["rows"]
            for second in range(math.ceil(case["wall_s"])):
                row = next((r for r in rows if r["wall_s"] >= second), rows[-1])
                trace.append({"run": path.parent.name, "renderer": report["renderer"], "case": case["case"]["name"],
                              **{key: row[key] for key in ["wall_s", "requested", "committed", "pending", "index", "alpha", "timer", "status", "cache_bytes", "staged", "completed"]},
                              "coverage": json.dumps(row["coverage"]), "ready_sequences": json.dumps(row["ready_sequences"]),
                              "wait": row["wait"]})
        summary.append({"raw_path": str(path), "raw_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                        **{key: value for key, value in report.items() if key != "cases"}, "cases": cases})
    (args.output_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    with (args.output_dir / "correlation.csv").open("w", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=list(trace[0]))
        writer.writeheader(); writer.writerows(trace)
    for report in summary:
        for case in report["cases"]:
            print(f'{report["renderer"]} {case["name"]}: {case["recorded_per_wall_second"]:.3f} recorded s/wall s; '
                  f'{case["draw_callbacks_per_second"]:.1f} draw callbacks/s; {case["holds"].get("count", 0)} holds; '
                  f'{case["timer_mismatches"]} timer mismatches')


if __name__ == "__main__":
    main()
