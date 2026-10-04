# Issue #219 owner-review revision 1

The owner asked for less space between each Jobs heading and its Open…, Details…, Cancel actions, and for **Acknowledge failures** to move into the dialog that displays retained failure messages. The original issue evidence in the parent directory remains the record of the first candidate.

The revised Jobs dialog uses a 160-pixel heading column and a narrower window. Its action columns remain aligned, with the shared right inset still separating Cancel from a visible scrollbar. **Acknowledge failures** now appears only in Status details when retained failures exist. Those failures appear first in the text. Activating the button clears retained notices and closes the dialog; it does not cancel jobs or remove results.

## Native snapshots

- [Idle Jobs](jobs-idle.png): narrower rows without the failure acknowledgement action.
- [Active video Jobs](jobs-active-video.png): active Cancel and no inline progress.
- [Constrained-height Jobs](jobs-scrollbar.png): aligned actions and scrollbar clearance.
- [Status details with a retained failure](status-failure-details.png): failure text and acknowledgement in one dialog.

## Focused validation

`python tools/validate_viewer_status.py --godot /home/Nozba/Desktop/Godot_v4.7.2-stable_linux.x86_64 --output-dir /tmp/wavez-issue-219-revision1-verified --renderer gl_compatibility` passed **298 checks** with unchanged generated WVZ1 source hashes. The runner reported two known encoder PID-cleanup diagnostics after worker cancellation; no other errors or warnings. Checks cover the compact headings, Jobs width at 1440×900 and 1024×640, scrollbar clearance and scrolling, absence of acknowledgement in Jobs and job Details, failure-first Status details, acknowledgement, live video Details, and existing cancellation and worker behavior.

The Jobs and status dialog code is shared across renderers. Forward+, packaging, physical desktop scaling, and extended live use were not run for this local UI revision. Owner visual review remains pending.
