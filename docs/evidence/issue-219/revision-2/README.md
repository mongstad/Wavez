# Issue #219 owner-review revision 2

The owner found that **Failure details…** in Jobs was misleading: it opened a general **Status details** dialog even when no failure existed. This revision removes that button from Jobs. The dialog now contains only five category rows and Close, and its height is reduced to match. Job-specific progress and errors remain in each row's Details… view. Aggregate retained failures remain signalled by the status line and Jobs indicator, and are reviewed through **File → Details…**. That dialog lists failures first and offers **Acknowledge failures** only when retained notices exist.

The [first candidate](../README.md) and [review revision 1](../revision-1/README.md) remain unchanged as historical evidence.

## Screenshots

- [Jobs without failure controls](jobs-idle.png)
- [Status details with a retained failure and acknowledgement](status-failure-details.png)

## Focused validation

`python tools/validate_viewer_status.py --godot /home/Nozba/Desktop/Godot_v4.7.2-stable_linux.x86_64 --output-dir /tmp/wavez-issue-219-revision2-release --renderer gl_compatibility` passed **300 checks** with unchanged generated WVZ1 source hashes. Checks cover Jobs open with and without a retained failure, no misleading failure action, File → Details… disclosure and acknowledgement, live video Details, cancellation, layout at 1440×900 and 1024×640, and constrained-height scrolling. Two known encoder PID-cleanup diagnostics were classified by the runner; no other errors or warnings occurred.

The Jobs/status presentation path is shared across renderers. Forward+, packaging, physical desktop scaling, and extended live use were not run for this local UI revision. Owner visual review remains pending.
