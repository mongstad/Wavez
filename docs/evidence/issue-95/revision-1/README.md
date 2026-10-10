# Part I onboarding revision — PR #339

Revises [Sol's owner feedback](https://github.com/mongstad/Wavez/pull/339#issuecomment-6102560035)
on the existing #95 branch. Candidate **v0.1.0.92** remains unchanged; owner review
is pending. The initial reports and manifest remain historical and unmodified.

## Changes

- The guide leads with extracting the Linux package into a local folder and
  double-clicking `WAVEZ.x86_64` in Dolphin/a Linux file manager.
- It retains `WAVEZ.x86_64` plus `WAVEZ.pck` together, explains Dolphin's
  Properties → Permissions → Allow executing file as program, and accounts
  for configurable single-click opening/run confirmations.
- Terminal launch, `chmod +x`, startup messages and Compatibility are alternatives.
- The beginner guide's internal Popup diagnosis/link and Windows activation
  instructions are removed; platform wording is limited to Linux x86_64.

Parts II–III, all four Python examples, authoritative technical documents,
engineering investigation, packaging code and application identity are byte-for-byte
unchanged relative to `41a4c2f35990bb33a6becfc7989f313f0aecab54`. The existing
package tool still sets `binary_format/embed_pck=false`. No package was rebuilt
and no embedded-PCK export was implemented.

## Focused validation

- [Documentation checks](documentation.json): all **34** guide-local links and
  anchors resolve; launch ordering, Linux-only content and the two filenames pass.
  Protected-file hashes and Parts II–III byte comparison confirm the narrow scope.
- Installed Dolphin **26.08.1**, KDE/Wayland: `kreadconfig6` reports
  `KDE/SingleClick=false`. The installed `libKF6KIOWidgets.so.6` contains the
  Permissions label and “Allow executing file as program” wording.
  KDE's [Dolphin view handbook](https://docs.kde.org/stable_kf6/en/dolphin/dolphin/dolphin-view.html)
  and [configuration handbook](https://docs.kde.org/trunk_kf6/en/dolphin/dolphin/configuring-dolphin.html)
  confirm configurable opening gestures and executable-open confirmations.
- [Desktop launch](desktop-launch.json): KDE `kioclient --noninteractive exec`
  opened the existing two-file production package, exited **0** without output,
  and produced one active native window belonging to the new executable PID.
  Its [session log](session.txt) confirms WAVEZ v0.1.0.92 started and ended after
  the PID-scoped KWin close. The [runtime log](runtime.txt) has no errors/warnings.
  Test config/data were isolated under `/tmp`; no owner window was closed.
- `git diff --check` passed. No Python, rendering or packaging regressions were
  rerun because those files/behaviors did not change; prior validated evidence
  remains available in the parent directory.

Sandboxed Dolphin/KIO help probes initially aborted without desktop access;
native retries succeeded. The temporary desktop helper emitted a PyGObject
`register_object` deprecation warning, not a Wavez runtime diagnostic.

This checks installed desktop settings/resources and KDE's executable-opening
route, not physical pointer double-clicks, archive extraction UI or permission
checkbox interaction. Other file managers and their preferences were not tested.
The guide avoids assuming all file managers behave alike.

## Owner verification

Extract the package, keep both files together, and double-click the executable
in Dolphin. If its execute permission is missing, enable the documented checkbox
and retry. Check the terminal alternative and review Part I's Linux-only wording.
Parts II–III and previous example checks remain unchanged. Stop for owner review;
do not merge or begin separate packaging work.
