# Issue #42 native transport evidence

Pending owner review. Scope, exact commands, failed attempts, limitations and the
manual acceptance checklist are in [the transport report](../../UX3_TRANSPORT.md).
Earlier shell/design evidence is intentionally preserved unchanged.

| Report | Environment | Result |
|---|---|---|
| [Forward+](forward.json) | Godot 4.7.2, native NVIDIA RTX 3070 Ti; synthetic + retained FreeCollapse capture | 58 checks, zero failures; source hashes unchanged |
| [Compatibility](compatibility.json) | Godot 4.7.2 native; synthetic capture | 55 checks, zero failures; source hash unchanged |
| [Shell](shell.json) | Native Forward+ | 97 checks, zero failures |
| [Regression summary](regressions.json) | Existing focused headless/native suites | See individual counts and scope |

Native viewport screenshots (intentional UI changes, not scientific pixel-equivalence evidence):

- [1440×900: 64-pixel transport](loaded-1440.png)
- [1024×640: two-row compact transport](loaded-1024.png)
- [Focused Seek time with explicit Go/Cancel](seek.png)
- [Real worker held at publication: displayed 0, submitted request 2.25](buffering.png)
- [Read-only retained real capture](real-capture.png)

The source metadata and retained source hash are recorded in the Forward+ report.
No scientific solver was run and no capture is committed here. Raw reproducible
runs are under ignored `results/issue-42-*`; source validators remain in `tools/`.
The two old external benchmark paths for frozen 02B/03B no longer exist locally;
this revision does not claim rerunning those benchmarks or their performance bounds.
