# Issue #53 native review evidence

**Pending owner review.** Sole Ready issue at preflight; exact owner-linked branch
`53-ux3-transport-003-delay-transient-seek-status` was clean at accepted main
`195bd90`, the squash merge of PR #51. Local main/origin/main matched it. Previous
local branch was absent and stale remote branch was pruned. No Project writes.

Fedora KDE/Wayland, Godot 4.7.2, NVIDIA RTX 3070 Ti; small synthetic fixtures.

| Final check | Result |
|---|---|
| Forward+ transport | [204 passed](forward.json); source hashes unchanged; cold-seek label observed at 457 ms |
| Compatibility transport | [204 passed](compatibility.json); source hashes unchanged; cold-seek label observed at 458 ms |
| Godot headless editor import | Passed, no script errors |
| Git whitespace and changed local Markdown links | Passed |

The presentation-only threshold is 450 ms. Native scripted waits of 100/350 ms
never showed the label; 550 ms did. Deterministic checks cover 449/450 ms, changed
targets, capture generation reset, commit and cancellation. A real cached seek
commits without showing the label, and a real worker publication barrier exercises
sustained cold-seek feedback and rapid replacement without stale text. Preparation
failure clearing is a published-error injection check, not an actual corrupt file.
Geometry stress at 1440×900/1024×640 waits past the threshold before testing visible
text, long text and disappearance. Existing native transport coverage includes
exact Seek/recipes, sparse Hold, signed speed, buffering Pause, dock/fullscreen,
adaptive duration formatting and no new scientific refresh instrumentation.

[Long cold seek](long-cold-seek.png)

450 ms was selected from the native short/long wait evidence. Relative candidate
comparison is reasoned: 300 ms would briefly expose the 350 ms wait, while 600 ms
would suppress the entire 550 ms wait. This is not a user study, before/after
performance benchmark or proof of feel on every production capture. Owner review
of real uncached playback remains the final usability check.

Commands, from repository root with externally installed Godot:

```sh
python tools/validate_viewer_transport.py --godot "$GODOT" --renderer forward_plus --output-dir results/issue-53-reviewed-forward
python tools/validate_viewer_transport.py --godot "$GODOT" --renderer gl_compatibility --output-dir results/issue-53-reviewed-compatibility
"$GODOT" --headless --path viewer --editor --import --quit
git diff --check
```

An initial 201-check Forward+ run passed. Expanding cached-seek coverage introduced
a test-only GDScript type-inference error, causing both next launches to fail before
running tests. An explicit bool type fixed it; both final 204-check runs pass.
No unresolved focused failures. Generated fixtures/logs remain in ignored results/.

No full scientific suite, video suite, physical HiDPI matrix, production simulation
or large-capture benchmark was rerun. Readiness/controller/worker code is unchanged;
only the transport presentation adapter and its focused tests change. Earlier
reports remain historical. Follow the [manual owner checks](../../UX3_TRANSIENT_STATUS.md#validation-and-owner-review),
then stop for owner acceptance. No later issue is implemented.
