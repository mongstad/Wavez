# Desktop-neutral Linux launch revision — PR #339

Addresses the [latest owner editorial feedback](https://github.com/mongstad/Wavez/pull/339#issuecomment-6102711394)
on the existing #95 branch. Candidate **v0.1.0.92** remains unchanged; owner
review is pending. Earlier evidence remains a historical record.

The guide now uses the reader's preferred Linux file manager to open/run
`WAVEZ.x86_64`, with `WAVEZ.pck` kept beside it. It describes single-click,
double-click and confirmation prompts without assuming identical desktop UI.
Execution permission can be enabled in file properties where available;
`chmod +x WAVEZ.x86_64` and terminal launch remain reliable alternatives.
Dolphin-specific labels and controls are removed from the guide.

## Validation

- [Documentation report](documentation.json): all **34** local guide links and
  anchors resolve; graphical-first ordering, desktop-neutral wording, Linux-only
  scope and the existing executable/PCK instructions pass inspection.
- Parts II–III are byte-identical to review commit
  `2635801906f635cb3ed4d6a7acae0d09e1e99efe`. All **4,081** other preexisting
  tracked files are also byte-identical, including the four examples, technical
  documentation, validation tools, application version and earlier evidence.
- Packaging remains unchanged with `binary_format/embed_pck=false`.
  No package rebuild or embedded-PCK export was performed.
- `git diff --check` passed.

This is an editorial revision. Python, renderer and package suites were not rerun;
their prior results remain in the [initial evidence](../README.md) and
[first revision](../revision-1/README.md). Broader file-manager UI and physical
pointer interactions remain untested. No common permission-control label is claimed.

## Owner verification

Extract the Linux package, keep both files together, and open/run the executable
with your preferred file manager. Check the guide's explanation of your opening
gesture and permission controls, then try the terminal alternative. Stop for
owner review; packaging work remains separate.
