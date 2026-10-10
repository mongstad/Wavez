# Optional FFmpeg onboarding revision — PR #339

Addresses the [FFmpeg owner feedback](https://github.com/mongstad/Wavez/pull/339#issuecomment-6102805480)
on the existing #95 branch. Candidate **v0.1.0.92** remains unchanged; owner
review is pending. Previous review evidence is preserved.

Part I now explains optional external FFmpeg installation for MP4, links the
official project/download pages, labels Debian/Ubuntu installation commands,
describes Fedora's codec-limited variant and points to current RPM Fusion guidance.
It checks versions and the specific `libx264` encoder, then explains PATH and
Custom/Browse/Apply in File Locations. Normal viewing and the examples need no FFmpeg.

## Source and link verification

- The [FFmpeg project](https://ffmpeg.org/) and
  [download page](https://ffmpeg.org/download.html) were read successfully.
  Upstream supplies source and links to distributor packages/builds.
- Ubuntu's [APT guide](https://ubuntu.com/server/docs/how-to/software/package-management/)
  documents update/install commands; its [FFmpeg package](https://packages.ubuntu.com/noble/ffmpeg)
  is in Universe. Debian's [FFmpeg package](https://packages.debian.org/trixie/ffmpeg)
  includes both ffmpeg and ffprobe. Installation was not executed on either distro.
- Fedora's [package page](https://packages.fedoraproject.org/pkgs/ffmpeg/ffmpeg-free/)
  explicitly describes codec limits. The [RPM Fusion multimedia page](https://rpmfusion.org/Howto/Multimedia)
  and Fedora Quick Docs recipe pages returned an anti-bot denial to the reader.
  The link is retained for users; no exact Fedora installation recipe is claimed
  verified or copied into the guide. Existing host FFmpeg is an RPM Fusion package.
- FFmpeg's [CLI documentation](https://ffmpeg.org/ffmpeg.html) confirms version
  and encoder-list commands. Wavez's [worker](../../../../viewer/video/render_worker.gd)
  explicitly selects `libx264`/`yuv420p`; its [preferences](../../../../viewer/ui/file_locations_preferences.gd)
  and [dialog](../../../../viewer/ui/shell/file_locations_dialog.gd) confirm discovery/UI wording.

## Focused validation

- [Documentation report](documentation.json): **34** local guide links/anchors,
  owner requirements and **2** shell-block syntax checks pass.
- Outside the new subsection, the guide is byte-identical to `89bb3c5`.
  All **4,087** other preexisting tracked files are byte-identical, including the
  four examples, technical documentation, prior prompt/launch revisions, packaging,
  runtime code, application identity and historical evidence.
- [Runtime report](runtime.json): installed Fedora 44 FFmpeg/ffprobe **8.1.3**
  both return version exit **0**, and encoder listing includes `libx264`.
  A two-frame, 16×16 PNG fixture encoded with the worker's MP4 options exits **0**
  with empty diagnostics. ffprobe confirms **H.264, yuv420p, 2 frames**.
- `git diff --check` passed. No packages were installed, code changed or packaging
  rebuilt. Python/viewer/export suites were not rerun for this documentation change;
  the encoder smoke is not a complete Wavez export workflow test.

## Owner verification

Read the subsection for your Linux distribution, run its version/encoder checks,
and verify File Locations selects your intended executable. If desired, export
a small MP4 through Wavez. Stop for owner review; packaging remains separate.
