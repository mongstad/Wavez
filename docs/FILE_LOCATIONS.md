# File Locations preferences

Candidate build 43 adds **Edit → Preferences → File Locations** beside the
existing Keyboard Shortcuts editor. All four location choices are saved together
in `user://preferences.cfg`; Cancel discards a draft, Apply saves it, and Reset
Defaults restores the behavior below. Keyboard Shortcuts and file-picker
Favorites/Recent keep their existing separate settings and interactions.

| Setting | Default | Custom behavior |
| --- | --- | --- |
| FFmpeg | Auto-detect from the current process PATH when MP4 export starts | Browse for an absolute executable. Wavez checks `ffmpeg -version` when saving and again before export. A broken custom path does not fall back to PATH. |
| Video exports | No preset folder; choose an MP4 path per export | New Video Export dialogs propose a filename in this folder. The Save dialog remains native and an explicit output path wins. |
| Image exports | Native folder picker on the first image save in a session; the chosen folder is reused only for that session | Save Image writes directly to this directory in every session, including through its keyboard shortcut. It does not turn a session-only folder choice into a permanent preference. |
| Log files | Godot `user://logs` | New interactive sessions create logs in this directory. The running session keeps its original log file. |

Directory choices must be absolute and writable. Apply creates a missing chosen
directory when possible; video and image exports check their destination again
when used. An unavailable configured image directory stops that capture with a
File Locations instruction; it does not silently choose a different folder.
The MP4 request stops before rendering when FFmpeg is unavailable and
points to File Locations. Normal FFmpeg availability produces no status sentence
in Video Export. The render worker, encoding arguments and scientific payload are
unchanged. FFmpeg remains an external installation.

## Owner check

1. Open **Edit → Preferences → File Locations** without a capture. Check the
   compact rows, native Browse pickers and current Auto-detect path or Not found.
2. Browse for FFmpeg in a path containing spaces, Apply, restart, and confirm
   Custom and its path persist. Switch to Auto-detect, Apply and restart; the
   mode should persist without saving the discovered absolute path.
3. Configure video, image and log directories, Apply and restart. Video Export
   should propose the video directory while preserving a manually chosen output.
   Save Image should write directly to the configured image directory without
   opening a picker. A new session log should appear in the configured log directory.
   Clear Image exports, then Save Image again: the native picker should appear;
   its chosen folder should be reused for this session without changing Preferences.
4. Remove or make the custom executable or destination folder unavailable and
   try the relevant export. Check the actionable error, change the path in File
   Locations, and retry. A missing FFmpeg must not start MP4 rendering.
5. Open **Edit → Preferences → Keyboard Shortcuts** and verify its existing
   editing, Apply and Cancel behavior.
