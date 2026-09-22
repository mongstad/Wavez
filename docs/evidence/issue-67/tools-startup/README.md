# PR #73 Tools startup correction

The plain Tools Window was added to the scene tree with its default visible
state. It is now hidden before tree insertion, preventing the empty launch popup.
Explicit menu actions still open the selected tool through the existing path.

Compatibility shell: **507 checks PASS**, including new checks for offline and
interactive startup and capture opening without an unsolicited Tools window.
Existing checks still verify every tool opens on request, metadata retention,
state round trips, exports and recovery. Source hashes unchanged. Final Godot
import and whitespace checks passed. Forward+ was not rerun for this fix.

[Empty launch screenshot](empty.png). The test also asserts the separate native
Tools window is hidden; a main-viewport screenshot alone cannot prove that.

Pending owner review. Relaunch without a capture: no Tools window should appear.
Open a capture, then choose a tool explicitly: that tool should open normally.
No #68 work, control rearrangement or scientific/state changes.
