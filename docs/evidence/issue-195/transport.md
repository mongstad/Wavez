# Native transport observations

Ordinary interactive playback, candidate build 25. Requested durations exclude
the three-second paused warmup. Draw callbacks are not monitor FPS. Fullscreen
here means native window mode; the production shell route is separately covered
by the source and packaged budget/lifecycle tests.

| Renderer / case | Wall s | Recorded s / wall s | Holds | Main p95 / p99 ms | Mean ready runway s | Peak process RSS MiB |
|---|---:|---:|---:|---:|---:|---:|
| forward_plus / fixed-full | 239.990 | 1.00004 | 0 | 17.74 / 18.80 | 0.272 | 1135.2 |
| forward_plus / radius-full | 240.021 | 0.99991 | 0 | 17.88 / 18.90 | 0.258 | 1361.9 |
| gl_compatibility / fixed | 90.015 | 0.99988 | 0 | 10.35 / 11.05 | 0.278 | 572.5 |
| gl_compatibility / radius | 90.006 | 0.99997 | 0 | 10.36 / 10.94 | 0.263 | 695.5 |
| gl_compatibility / reverse | 40.028 | -0.99948 | 0 | 10.77 / 11.28 | 0.267 | 805.0 |
| gl_compatibility / quarter-speed | 40.013 | 0.24994 | 0 | 3.56 / 10.40 | 0.405 | 910.1 |
| gl_compatibility / z-height | 40.037 | 0.99914 | 0 | 10.49 / 11.01 | 0.261 | 937.7 |
| gl_compatibility / twist-phase | 40.001 | 1.00001 | 0 | 10.54 / 11.10 | 0.260 | 965.0 |
| gl_compatibility / fullscreen | 40.012 | 0.99985 | 0 | 10.59 / 11.13 | 0.267 | 1022.6 |

All nine cases had zero timer mismatches, zero process swap, no cache/preparation
errors and at most six decoded endpoints and one staged GPU mesh. Reported peak
RSS includes the finite observer and its retained prior-case traces; it is not
an estimate of the mesh cache alone. See [summary.json](summary.json) for phase
timings, measured bounds, raw paths and digests.
