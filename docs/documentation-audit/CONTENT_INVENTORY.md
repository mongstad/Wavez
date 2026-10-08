# Documentation content inventory

Baseline: `ca220d30163d4a76efd652933c8c963a564c315d` (accepted build 76).
This inventory was written before any retirement. All 248 tracked Markdown files
were read for headings, content, format/status references and incoming links; all
1,747 documentation/evidence files were read for hashes and dependency mapping.
The [complete CSV](inventory.csv) includes every artifact, its size/SHA256, incoming
text/link references, rationale and proposed action. Text mentions in frozen logs
are provenance, not current navigational links. Basenames are matched only when
unambiguous; explicit relative Markdown links are resolved from their document.

Only six obsolete root checkpoint/roadmap documents are deleted. All existing
evidence binaries/logs/JSON remain. Link repairs do not rewrite their run outcomes.
See [decisions and contract preservation](README.md) for the manual candidate review.

| Baseline path | Content/purpose | Classification | Incoming references | Authoritative replacement | Action |
| --- | --- | --- | ---: | --- | --- |
| `AGENTS.md` | Wavez development | current contract / guide | 7 (CSV) | `AGENTS.md` | keep |
| `CONTRIBUTING.md` | Development checkpoints | current contract / guide | 6 (CSV) | `CONTRIBUTING.md` | keep |
| `G2_STORAGE.md` | G2 storage: G2b complete — 2026-09-10 | obsolete checkpoint / roadmap | 7 (CSV) | `docs/WVZ1_FORMAT.md; docs/CAPTURE_FORMAT_AND_API.md` | delete |
| `G3_FORMAT.md` | WAVEZ Scene Format (WVZ1) wire contract | current contract / guide | 18 (CSV) | `docs/WVZ1_FORMAT.md` | rename |
| `G3_GUIDE.md` | G3 quick guide | current contract / guide | 14 (CSV) | `docs/SCENE_CAPTURE_GUIDE.md` | rename |
| `G3_REPORT.md` | G3 implementation and measured acceptance — 2026-09-11 | obsolete checkpoint / roadmap | 10 (CSV) | `docs/WVZ1_FORMAT.md; docs/EVIDENCE_INDEX.md` | delete |
| `G3_TIMELINE_FIX.md` | G3 maintenance: live Physical-time slider | obsolete checkpoint / roadmap | 2 (CSV) | `docs/CAPTURE_FORMAT_AND_API.md; viewer/layers/test_scene_timeline.gd` | delete |
| `G4_DESIGN.md` | G4 — selections and temporal analysis | current contract / guide | 11 (CSV) | `docs/SCIENTIFIC_ANALYSIS.md` | rename |
| `G4_REPORT.md` | G4 implementation record | obsolete checkpoint / roadmap | 10 (CSV) | `docs/G4_ACCEPTANCE.md; docs/ANALYSIS_GUIDE.md; docs/ANALYSIS_SCHEMAS.md` | delete |
| `INSPECTION_STATE.md` | Native scene inspection | current contract / guide | 14 (CSV) | `INSPECTION_STATE.md` | update |
| `PLAYBACK_PERFORMANCE.md` | Real-capture playback performance — 2026-09-10 | obsolete checkpoint / roadmap | 4 (CSV) | `docs/ROLLING_PLAYBACK_CACHE.md; docs/PARTICLE_CACHE_CAPACITY.md; docs/MESH_PREPARATION_BUDGET.md` | delete |
| `PROVENANCE.md` | Provenance and repository reset | legal / attribution / provenance | 4 (CSV) | `PROVENANCE.md` | keep |
| `QUICKSTART.md` | Quickstart | current contract / guide | 10 (CSV) | `QUICKSTART.md` | update |
| `README.md` | WAVEZ | current contract / guide | 12 (CSV) | `README.md` | update |
| `SIMSCOPE_ACCEPTANCE_MATRIX.md` | SIMSCOPE Next — Acceptance Matrix | current contract / guide | 12 (CSV) | `docs/SCIENTIFIC_ACCEPTANCE.md` | rename |
| `SIMSCOPE_NEXT_DESIGN.md` | SIMSCOPE Next — Design and Delivery Plan | obsolete checkpoint / roadmap | 8 (CSV) | `docs/CURRENT_STATUS.md; docs/SCIENTIFIC_ANALYSIS.md; docs/SCIENTIFIC_ACCEPTANCE.md; AGENTS.md` | delete |
| `THIRD_PARTY_LICENSES.md` | Third-party licenses and dependency notices | legal / attribution / provenance | 9 (CSV) | `THIRD_PARTY_LICENSES.md` | keep |
| `TRADEMARKS.md` | Trademarks and branding | legal / attribution / provenance | 8 (CSV) | `TRADEMARKS.md` | keep |
| `UX_IMPLEMENTATION_PLAN.md` | Wavez UX Implementation Plan | current contract / guide | 9 (CSV) | `docs/UX_WORKFLOW.md` | rename |
| `VIDEO_EXPORT.md` | Wavez deterministic video export | current contract / guide | 20 (CSV) | `docs/VIDEO_EXPORT.md` | rename |
| `WAVEZ_API.md` | Wavez Python API | current contract / guide | 12 (CSV) | `WAVEZ_API.md` | update |
| `docs/ABOUT_DOCUMENTATION_NAVIGATION.md` | About documentation navigation — #171 | mixed guide / implementation record | 1 (CSV) | `docs/ABOUT_DOCUMENTATION_NAVIGATION.md` | keep |
| `docs/ABOUT_SIMSCOPE.md` | About SimScope — issue #96 | mixed guide / implementation record | 2 (CSV) | `docs/ABOUT_SIMSCOPE.md` | update |
| `docs/AUTO_ORBIT.md` | Auto Orbit and Free Camera (#234) | mixed guide / implementation record | 4 (CSV) | `docs/AUTO_ORBIT.md` | keep |
| `docs/BACKGROUND_EXPORT_VALIDATION.md` | VIDEO-001 — background GPU export validation | historical / mixed review record | 3 (CSV) | `docs/BACKGROUND_EXPORT_VALIDATION.md` | keep |
| `docs/BRANDING_MIGRATION.md` | WAVEZ branding migration — issue #155 | mixed guide / implementation record | 6 (CSV) | `docs/BRANDING_MIGRATION.md` | keep |
| `docs/CAMERA_RESET.md` | Reset Camera on the current scene (#211) | mixed guide / implementation record | 1 (CSV) | `docs/CAMERA_RESET.md` | keep |
| `docs/CAMERA_TUMBLE_VALIDATION.md` | UI-003 — continuous camera tumble validation | historical / mixed review record | 3 (CSV) | `docs/CAMERA_TUMBLE_VALIDATION.md` | keep |
| `docs/CAPTURE_FORMAT_AND_API.md` | Capture format and API | current contract / guide | 12 (CSV) | `docs/CAPTURE_FORMAT_AND_API.md` | update |
| `docs/CAPTURE_FORMAT_POLICY.md` | WAVEZ Scene Format policy | current contract / guide | 21 (CSV) | `docs/CAPTURE_FORMAT_POLICY.md` | update |
| `docs/CINEMATIC_BACKGROUND.md` | Screen-fixed cinematic background | mixed guide / implementation record | 5 (CSV) | `docs/CINEMATIC_BACKGROUND.md` | keep |
| `docs/CURRENT_STATUS.md` | Current status | current contract / guide | 28 (CSV) | `docs/CURRENT_STATUS.md` | update |
| `docs/CUSTOM_ORBIT.md` | Custom orbit setup | mixed guide / implementation record | 1 (CSV) | `docs/CUSTOM_ORBIT.md` | keep |
| `docs/DIALOG_COHERENCE.md` | File and Tools dialog coherence — issue #161 | mixed guide / implementation record | 3 (CSV) | `docs/DIALOG_COHERENCE.md` | keep |
| `docs/DIALOG_HIERARCHY.md` | Dialog title and section hierarchy | mixed guide / implementation record | 5 (CSV) | `docs/DIALOG_HIERARCHY.md` | keep |
| `docs/DYNAMIC_FIELD_PREPARATION.md` | Dynamic field preparation — issue #111 | historical / mixed review record | 4 (CSV) | `docs/DYNAMIC_FIELD_PREPARATION.md` | keep |
| `docs/EDITABLE_VALUE_FOCUS.md` | Editable value focus | mixed guide / implementation record | 5 (CSV) | `docs/EDITABLE_VALUE_FOCUS.md` | keep |
| `docs/EVIDENCE_INDEX.md` | Retained evidence | current contract / guide | 16 (CSV) | `docs/EVIDENCE_INDEX.md` | update |
| `docs/EXIT_MENU.md` | File → Exit (#153) | mixed guide / implementation record | 1 (CSV) | `docs/EXIT_MENU.md` | keep |
| `docs/EXIT_WITH_ACTIVE_JOBS.md` | Exiting with active jobs | mixed guide / implementation record | 5 (CSV) | `docs/EXIT_WITH_ACTIVE_JOBS.md` | keep |
| `docs/EXPERIMENT_LESSONS.md` | Experiment lessons | current contract / guide | 5 (CSV) | `docs/EXPERIMENT_LESSONS.md` | keep |
| `docs/FIELD_PREPARATION_BUDGET.md` | Field preparation memory budget | historical / mixed review record | 2 (CSV) | `docs/FIELD_PREPARATION_BUDGET.md` | keep |
| `docs/FILE_DIALOGS.md` | Scene and video file dialogs | mixed guide / implementation record | 3 (CSV) | `docs/FILE_DIALOGS.md` | update |
| `docs/FILE_LOCATIONS.md` | File Locations preferences | mixed guide / implementation record | 2 (CSV) | `docs/FILE_LOCATIONS.md` | keep |
| `docs/FOCUS_NAVIGATION.md` | Keyboard focus navigation | mixed guide / implementation record | 6 (CSV) | `docs/FOCUS_NAVIGATION.md` | keep |
| `docs/FORMAT_IDENTITY_PROPOSAL.md` | WAVEZ Scene Format clean-break proposal — issue #182 | historical / mixed review record | 2 (CSV) | `docs/FORMAT_IDENTITY_PROPOSAL.md` | keep |
| `docs/FREE_CAMERA_SPEED.md` | Free Camera movement speed (#200, #256) | mixed guide / implementation record | 3 (CSV) | `docs/FREE_CAMERA_SPEED.md` | keep |
| `docs/FULLSCREEN_RESTORE_VALIDATION.md` | Fullscreen return mode — issue #86 | mixed guide / implementation record | 3 (CSV) | `docs/FULLSCREEN_RESTORE_VALIDATION.md` | keep |
| `docs/G4_ACCEPTANCE.md` | G4 acceptance ledger | historical evidence | 13 (CSV) | `docs/G4_ACCEPTANCE.md` | update |
| `docs/G4_GUIDE.md` | Selections and temporal analysis | current contract / guide | 14 (CSV) | `docs/ANALYSIS_GUIDE.md` | rename |
| `docs/G4_SCHEMAS.md` | G4 internal interchange | current contract / guide | 13 (CSV) | `docs/ANALYSIS_SCHEMAS.md` | rename |
| `docs/IMAGE_EXPORT.md` | Save Image | current contract / guide | 1 (CSV) | `docs/IMAGE_EXPORT.md` | keep |
| `docs/JOBS_LAYOUT.md` | Jobs row clearance — issue #251 | mixed guide / implementation record | 1 (CSV) | `docs/JOBS_LAYOUT.md` | keep |
| `docs/KEYBOARD_SHORTCUTS.md` | Keyboard Shortcuts | mixed guide / implementation record | 5 (CSV) | `docs/KEYBOARD_SHORTCUTS.md` | keep |
| `docs/LAYER_LEGENDS.md` | Independent layer legends — issue #37 | mixed guide / implementation record | 2 (CSV) | `docs/LAYER_LEGENDS.md` | keep |
| `docs/LEGEND_CARD_REVIEW.md` | Particle legend card — PR #92 review refinement | historical / mixed review record | 2 (CSV) | `docs/LEGEND_CARD_REVIEW.md` | keep |
| `docs/LEGEND_CONTENT_LAYOUT.md` | Legend content and compact layout — issue #115 | mixed guide / implementation record | 2 (CSV) | `docs/LEGEND_CONTENT_LAYOUT.md` | keep |
| `docs/LEGEND_DEFAULTS.md` | Hidden legend defaults — issue #105 | mixed guide / implementation record | 0 (CSV) | `docs/LEGEND_DEFAULTS.md` | keep |
| `docs/LEGEND_INITIAL_LAYOUT_VALIDATION.md` | Legend first-open positioning — PR #91 review follow-up | historical / mixed review record | 1 (CSV) | `docs/LEGEND_INITIAL_LAYOUT_VALIDATION.md` | keep |
| `docs/LEGEND_PLACEMENT_VALIDATION.md` | Legend placement — PR #91 review refinement | historical / mixed review record | 1 (CSV) | `docs/LEGEND_PLACEMENT_VALIDATION.md` | keep |
| `docs/LEGEND_VISIBILITY_VALIDATION.md` | Independent legend visibility — issue #85 | mixed guide / implementation record | 2 (CSV) | `docs/LEGEND_VISIBILITY_VALIDATION.md` | keep |
| `docs/LMB_Y_INVERSION.md` | LMB vertical-axis preference | mixed guide / implementation record | 7 (CSV) | `docs/LMB_Y_INVERSION.md` | keep |
| `docs/LOAD_ERROR_RECOVERY.md` | Failed capture-load recovery — issue #104 | mixed guide / implementation record | 2 (CSV) | `docs/LOAD_ERROR_RECOVERY.md` | keep |
| `docs/LOAD_ERROR_STATUS_RECOVERY.md` | Successful-open error recovery | mixed guide / implementation record | 4 (CSV) | `docs/LOAD_ERROR_STATUS_RECOVERY.md` | keep |
| `docs/MAINTENANCE_REPORT.md` | Post-G4 maintenance record | mixed guide / implementation record | 5 (CSV) | `docs/MAINTENANCE_REPORT.md` | keep |
| `docs/MANUAL_CAMERA_ORBIT.md` | Free-look steering and manual camera orbit (#258) | mixed guide / implementation record | 7 (CSV) | `docs/MANUAL_CAMERA_ORBIT.md` | keep |
| `docs/MESH_PLAYBACK_MAINTENANCE_REPORT.md` | PERF-003 mesh playback maintenance record | mixed guide / implementation record | 10 (CSV) | `docs/MESH_PLAYBACK_MAINTENANCE_REPORT.md` | keep |
| `docs/MESH_PREPARATION_BUDGET.md` | Adaptive mesh preparation | mixed guide / implementation record | 5 (CSV) | `docs/MESH_PREPARATION_BUDGET.md` | keep |
| `docs/MIXED_PLAYBACK_BUFFERING.md` | Mixed playback and temporary buffering at 2× | mixed guide / implementation record | 4 (CSV) | `docs/MIXED_PLAYBACK_BUFFERING.md` | keep |
| `docs/NUMERICAL_VALIDATION_GUIDE.md` | Numerical validation guide | current contract / guide | 4 (CSV) | `docs/NUMERICAL_VALIDATION_GUIDE.md` | keep |
| `docs/ORBIT_CENTER.md` | Edit the existing orbit center and radius (#120) | historical / mixed review record | 3 (CSV) | `docs/ORBIT_CENTER.md` | keep |
| `docs/PACKAGED_VIDEO_EXPORT.md` | Video export from Linux release builds | mixed guide / implementation record | 4 (CSV) | `docs/PACKAGED_VIDEO_EXPORT.md` | keep |
| `docs/PANEL_DISCLOSURE_VALIDATION.md` | Simulation-panel launch defaults — issue #84 | mixed guide / implementation record | 3 (CSV) | `docs/PANEL_DISCLOSURE_VALIDATION.md` | keep |
| `docs/PARALLEL_FIELD_PREPARATION.md` | Bounded parallel field preparation — issue #109 | mixed guide / implementation record | 3 (CSV) | `docs/PARALLEL_FIELD_PREPARATION.md` | keep |
| `docs/PARTICLE_CACHE_CAPACITY.md` | Particle cache capacity — issue #229 | mixed guide / implementation record | 4 (CSV) | `docs/PARTICLE_CACHE_CAPACITY.md` | keep |
| `docs/PAUSED_PREPARATION.md` | Paused opening and automatic preparation — issue #204 | mixed guide / implementation record | 2 (CSV) | `docs/PAUSED_PREPARATION.md` | keep |
| `docs/PAUSED_RENDERING.md` | Paused rendering — issue #118 | historical / mixed review record | 3 (CSV) | `docs/PAUSED_RENDERING.md` | keep |
| `docs/PERFORMANCE_DIALOG.md` | Performance dialog | mixed guide / implementation record | 5 (CSV) | `docs/PERFORMANCE_DIALOG.md` | keep |
| `docs/PERFORMANCE_MAINTENANCE_REPORT.md` | PERF-001 / PERF-002 maintenance review | historical / mixed review record | 11 (CSV) | `docs/PERFORMANCE_MAINTENANCE_REPORT.md` | keep |
| `docs/PLAYBACK_INTEGRITY.md` | Playback validation and explicit integrity verification | historical / mixed review record | 10 (CSV) | `docs/PLAYBACK_INTEGRITY.md` | keep |
| `docs/PLAYBACK_RUNWAY_REVIEW.md` | PR #130 adaptive-runway follow-up | mixed guide / implementation record | 1 (CSV) | `docs/PLAYBACK_RUNWAY_REVIEW.md` | keep |
| `docs/PROBE_MARKER_VALIDATION.md` | UI-004 — independent source-probe marker visibility | mixed guide / implementation record | 3 (CSV) | `docs/PROBE_MARKER_VALIDATION.md` | keep |
| `docs/PROBE_MARKER_VISIBILITY.md` | Source-probe marker visibility | mixed guide / implementation record | 5 (CSV) | `docs/PROBE_MARKER_VISIBILITY.md` | keep |
| `docs/QUICK_SETUP_REMOVAL.md` | Quick setup removal — #160 | mixed guide / implementation record | 1 (CSV) | `docs/QUICK_SETUP_REMOVAL.md` | keep |
| `docs/REPOSITORY_BOUNDARY.md` | Wavez repository boundary | current contract / guide | 7 (CSV) | `docs/REPOSITORY_BOUNDARY.md` | keep |
| `docs/ROLLING_PLAYBACK_CACHE.md` | Rolling playback cache and prepared timeline — #106 | historical / mixed review record | 3 (CSV) | `docs/ROLLING_PLAYBACK_CACHE.md` | keep |
| `docs/ROUNDED_SURFACES.md` | Square outer surfaces and About close control | mixed guide / implementation record | 3 (CSV) | `docs/ROUNDED_SURFACES.md` | keep |
| `docs/SESSION_LOGGING.md` | Session troubleshooting logs | mixed guide / implementation record | 2 (CSV) | `docs/SESSION_LOGGING.md` | keep |
| `docs/SIMULATION_INTEGRATION_GUIDE.md` | Simulation integration guide | current contract / guide | 15 (CSV) | `docs/SIMULATION_INTEGRATION_GUIDE.md` | update |
| `docs/SSC_ACCELERATION.md` | SSC generation and preparation investigation — issue #102 | historical / mixed review record | 5 (CSV) | `docs/SSC_ACCELERATION.md` | update |
| `docs/SSC_ADAPTIVE_CACHE.md` | Adaptive playback cache — issue #102 / PR #103 | mixed guide / implementation record | 5 (CSV) | `docs/SSC_ADAPTIVE_CACHE.md` | update |
| `docs/SSC_CAPTURE_PARAMETERS.md` | SSC capture fidelity and parameter inventory — #102 | mixed guide / implementation record | 6 (CSV) | `docs/SSC_CAPTURE_PARAMETERS.md` | update |
| `docs/SSC_CHANNEL_SWITCH_STABILITY.md` | PR #101 channel-switch stability triage | mixed guide / implementation record | 3 (CSV) | `docs/SSC_CHANNEL_SWITCH_STABILITY.md` | update |
| `docs/SSC_CONTINUOUS_PLAYBACK.md` | Continuous SSC playback — issue #100 / PR #101 | historical / mixed review record | 4 (CSV) | `docs/SSC_CONTINUOUS_PLAYBACK.md` | update |
| `docs/SSC_LAZY_LOADING.md` | Lazy SSC startup — issue #100 / PR #101 | mixed guide / implementation record | 5 (CSV) | `docs/SSC_LAZY_LOADING.md` | update |
| `docs/SSC_LOAD_PERFORMANCE.md` | SSC loading and preparation profile | mixed guide / implementation record | 3 (CSV) | `docs/SSC_LOAD_PERFORMANCE.md` | update |
| `docs/SSC_METADATA_BUDGET.md` | Reader metadata capacity | mixed guide / implementation record | 5 (CSV) | `docs/SSC_METADATA_BUDGET.md` | update |
| `docs/START_HERE.md` | Start here | current contract / guide | 6 (CSV) | `docs/START_HERE.md` | update |
| `docs/STATUS_PLAYBACK_STATE.md` | Unified playback/preparation status — #114 | mixed guide / implementation record | 2 (CSV) | `docs/STATUS_PLAYBACK_STATE.md` | keep |
| `docs/TIMELINE_ENDPOINTS.md` | Timeline endpoint alignment — #136 | mixed guide / implementation record | 1 (CSV) | `docs/TIMELINE_ENDPOINTS.md` | keep |
| `docs/TOOLS_FUNCTIONAL_AUDIT.md` | Current Tools functional audit — issue #224 | historical / mixed review record | 2 (CSV) | `docs/TOOLS_FUNCTIONAL_AUDIT.md` | keep |
| `docs/UX1_DESIGN_SYSTEM.md` | Wavez design system — Midnight Scientific | mixed guide / implementation record | 13 (CSV) | `docs/UX1_DESIGN_SYSTEM.md` | update |
| `docs/UX1_REGRESSION_WORKFLOWS.md` | UX1 — Regression-sensitive workflows | mixed guide / implementation record | 10 (CSV) | `docs/UX1_REGRESSION_WORKFLOWS.md` | update |
| `docs/UX1_REPORT.md` | UX1 — Audit & Design System Specification milestone report | historical / mixed review record | 9 (CSV) | `docs/UX1_REPORT.md` | update |
| `docs/UX1_UI_AUDIT.md` | UX1 — Current UI and coupling audit | historical / mixed review record | 8 (CSV) | `docs/UX1_UI_AUDIT.md` | keep |
| `docs/UX2_REPORT.md` | UX2 — Theme Foundation & Component Library milestone report | historical / mixed review record | 7 (CSV) | `docs/UX2_REPORT.md` | update |
| `docs/UX2_THEME_LIBRARY.md` | UX2 — Theme and primitive component library | mixed guide / implementation record | 11 (CSV) | `docs/UX2_THEME_LIBRARY.md` | keep |
| `docs/UX3_FULLSCREEN.md` | UX3-FULLSCREEN-001 — Immersive fullscreen | mixed guide / implementation record | 8 (CSV) | `docs/UX3_FULLSCREEN.md` | update |
| `docs/UX3_MEDIA_TRANSPORT.md` | Media-style playback timing — issue #49 | mixed guide / implementation record | 9 (CSV) | `docs/UX3_MEDIA_TRANSPORT.md` | keep |
| `docs/UX3_REPORT.md` | UX3 — Main Viewer Shell: integration report | historical / mixed review record | 13 (CSV) | `docs/UX3_REPORT.md` | keep |
| `docs/UX3_SHELL.md` | UX3 shell — issue #41 | historical / mixed review record | 8 (CSV) | `docs/UX3_SHELL.md` | update |
| `docs/UX3_STATUS.md` | UX3 persistent status and Jobs — issue #43 | mixed guide / implementation record | 11 (CSV) | `docs/UX3_STATUS.md` | update |
| `docs/UX3_TRANSIENT_STATUS.md` | Transient seek status delay — issue #53 | mixed guide / implementation record | 5 (CSV) | `docs/UX3_TRANSIENT_STATUS.md` | keep |
| `docs/UX3_TRANSPORT.md` | UX3 persistent transport — issue #42 | mixed guide / implementation record | 8 (CSV) | `docs/UX3_TRANSPORT.md` | update |
| `docs/UX3_UI_OWNERSHIP.md` | Production UI ownership — issue #59 | mixed guide / implementation record | 6 (CSV) | `docs/UX3_UI_OWNERSHIP.md` | keep |
| `docs/UX4_DESIGN.md` | UX4 menu and panel contract — issue #66 | mixed guide / implementation record | 8 (CSV) | `docs/UX4_DESIGN.md` | update |
| `docs/UX4_MENUS.md` | UX4 command menus — issue #67 | mixed guide / implementation record | 7 (CSV) | `docs/UX4_MENUS.md` | keep |
| `docs/UX4_PANEL.md` | UX4 simulation panel — issue #68 | mixed guide / implementation record | 5 (CSV) | `docs/UX4_PANEL.md` | keep |
| `docs/UX4_TOOLS.md` | UX4 focused scientific tools — issue #69 | mixed guide / implementation record | 4 (CSV) | `docs/UX4_TOOLS.md` | keep |
| `docs/UX5_CLEANUP.md` | Residual violet UI cleanup — #147 | mixed guide / implementation record | 8 (CSV) | `docs/UX5_CLEANUP.md` | keep |
| `docs/UX5_STYLE_SLICE.md` | Violet visual-system review slice — #143 | historical / mixed review record | 6 (CSV) | `docs/UX5_STYLE_SLICE.md` | keep |
| `docs/UX_CONTROL_MAP.md` | Current-to-proposed control map — issue #14 | mixed guide / implementation record | 11 (CSV) | `docs/UX_CONTROL_MAP.md` | keep |
| `docs/UX_IA_REVIEW.md` | Issue #14 — walkthrough and review evidence | historical / mixed review record | 10 (CSV) | `docs/UX_IA_REVIEW.md` | keep |
| `docs/UX_INFORMATION_ARCHITECTURE.md` | Viewer information architecture — issue #14 | mixed guide / implementation record | 13 (CSV) | `docs/UX_INFORMATION_ARCHITECTURE.md` | update |
| `docs/UX_STYLE_VALIDATION.md` | Midnight Scientific reconciliation and validation — issue #8 | historical / mixed review record | 4 (CSV) | `docs/UX_STYLE_VALIDATION.md` | keep |
| `docs/UX_VISUAL_LANGUAGE.md` | Viewer visual language — issue #40 | mixed guide / implementation record | 11 (CSV) | `docs/UX_VISUAL_LANGUAGE.md` | keep |
| `docs/VERSIONING.md` | Wavez application version and build policy | current contract / guide | 5 (CSV) | `docs/VERSIONING.md` | keep |
| `docs/VERSIONING_VALIDATION.md` | Application version identity — issue #131 | historical / mixed review record | 2 (CSV) | `docs/VERSIONING_VALIDATION.md` | keep |
| `docs/VIDEO_ACTIONS_VALIDATION.md` | Video export actions — issue #65 | mixed guide / implementation record | 1 (CSV) | `docs/VIDEO_ACTIONS_VALIDATION.md` | keep |
| `docs/VIDEO_CANCEL_CONFIRMATION.md` | Video cancellation confirmation — #97 | mixed guide / implementation record | 2 (CSV) | `docs/VIDEO_CANCEL_CONFIRMATION.md` | keep |
| `docs/VIDEO_ETA.md` | Video Export ETA — issue #285 | mixed guide / implementation record | 4 (CSV) | `docs/VIDEO_ETA.md` | keep |
| `docs/VIDEO_EXPORT_LOCKS.md` | VIDEO-UX-005 — export settings and active-job actions | mixed guide / implementation record | 2 (CSV) | `docs/VIDEO_EXPORT_LOCKS.md` | keep |
| `docs/VIDEO_PROGRESS_VALIDATION.md` | Video progress details — issue #52 | mixed guide / implementation record | 1 (CSV) | `docs/VIDEO_PROGRESS_VALIDATION.md` | keep |
| `docs/VIDEO_REGRESSION.md` | VIDEO-REGRESSION-001 — current development export baseline | mixed guide / implementation record | 2 (CSV) | `docs/VIDEO_REGRESSION.md` | keep |
| `docs/VIDEO_STARTUP_116.md` | 116 / PR #122 — owner-review startup blocker | historical / mixed review record | 3 (CSV) | `docs/VIDEO_STARTUP_116.md` | keep |
| `docs/VIDEO_VIEWPORT_EXPORT.md` | Viewport-only video composition — issue #198 | mixed guide / implementation record | 3 (CSV) | `docs/VIDEO_VIEWPORT_EXPORT.md` | keep |
| `docs/VIEWPORT_CURSOR.md` | Viewport cursor visibility (#261 and #263) | mixed guide / implementation record | 4 (CSV) | `docs/VIEWPORT_CURSOR.md` | keep |
| `docs/VIEW_PRESETS.md` | Portable view presets — #138 | mixed guide / implementation record | 4 (CSV) | `docs/VIEW_PRESETS.md` | keep |
| `docs/VOLUME_COLOR_NORMALIZATION.md` | Volume color normalization and frozen ranges | mixed guide / implementation record | 6 (CSV) | `docs/VOLUME_COLOR_NORMALIZATION.md` | keep |
| `docs/VOLUME_DEFAULTS_VALIDATION.md` | VOLUME-004 — real-capture volume-defaults review | historical / mixed review record | 4 (CSV) | `docs/VOLUME_DEFAULTS_VALIDATION.md` | keep |
| `docs/VOLUME_DISPLAY_PRESETS.md` | Volume display starting points — VOLUME-001 | mixed guide / implementation record | 8 (CSV) | `docs/VOLUME_DISPLAY_PRESETS.md` | keep |
| `docs/VOLUME_LEGEND_OPACITY.md` | Volume opacity in legend overlays | mixed guide / implementation record | 5 (CSV) | `docs/VOLUME_LEGEND_OPACITY.md` | keep |
| `docs/VOLUME_OPACITY_MAPPING.md` | Independent volume opacity mapping | mixed guide / implementation record | 7 (CSV) | `docs/VOLUME_OPACITY_MAPPING.md` | keep |
| `docs/WAVEZ_HANDBOOK.md` | Wavez handbook | current contract / guide | 9 (CSV) | `docs/WAVEZ_HANDBOOK.md` | update |
| `docs/WAVEZ_METADATA_BUDGET.md` | WVZ1 reader metadata capacity | current contract / guide | 6 (CSV) | `docs/WAVEZ_METADATA_BUDGET.md` | keep |
| `docs/WAVEZ_VIEW_PRESETS.md` | Portable WAVEZ view presets | current contract / guide | 4 (CSV) | `docs/WAVEZ_VIEW_PRESETS.md` | keep |
| `docs/WINDOW_EDGE_REVEAL.md` | Pinned edge reveal and Fullscreen | mixed guide / implementation record | 7 (CSV) | `docs/WINDOW_EDGE_REVEAL.md` | keep |
| `docs/WVZ1_IMPLEMENTATION_VALIDATION.md` | WVZ1 implementation validation — issue #215 | historical / mixed review record | 3 (CSV) | `docs/WVZ1_IMPLEMENTATION_VALIDATION.md` | keep |
| `docs/evidence/issue-124/README.md` | Issue #124 — Warn before exiting with active jobs | historical evidence | 2 (CSV) | `docs/evidence/issue-124/README.md` | keep |
| `docs/evidence/issue-14/wireframes.md` | Static wireframes — issue #14 | historical evidence | 4 (CSV) | `docs/evidence/issue-14/wireframes.md` | keep |
| `docs/evidence/issue-143/round2/README.md` | Round 2 representative slice — pending owner visual review | historical evidence | 3 (CSV) | `docs/evidence/issue-143/round2/README.md` | keep |
| `docs/evidence/issue-143/round3/README.md` | Round 2 review corrections — pending owner review | historical evidence | 3 (CSV) | `docs/evidence/issue-143/round3/README.md` | keep |
| `docs/evidence/issue-143/round4/README.md` | Round 4 — shared dropdown/popup consistency, pending owner visual review | historical evidence | 3 (CSV) | `docs/evidence/issue-143/round4/README.md` | keep |
| `docs/evidence/issue-146/README.md` | Issue #146 — Visibility-aware Tab focus | historical evidence | 2 (CSV) | `docs/evidence/issue-146/README.md` | keep |
| `docs/evidence/issue-147/README.md` | Issue #147 review evidence | historical evidence | 1 (CSV) | `docs/evidence/issue-147/README.md` | keep |
| `docs/evidence/issue-156/README.md` | Issue #156 — Playback clock typography | historical evidence | 2 (CSV) | `docs/evidence/issue-156/README.md` | keep |
| `docs/evidence/issue-158/README.md` | Issue #158 — continuous native resize | historical evidence | 2 (CSV) | `docs/evidence/issue-158/README.md` | keep |
| `docs/evidence/issue-175/README.md` | Issue #175 validation — pending owner review | historical evidence | 4 (CSV) | `docs/evidence/issue-175/README.md` | update |
| `docs/evidence/issue-175/apply-review/README.md` | Apply button review change — issue #175 / PR #177 | historical evidence | 2 (CSV) | `docs/evidence/issue-175/apply-review/README.md` | keep |
| `docs/evidence/issue-175/dialog-review/README.md` | Close button and keep-open Apply — issue #175 / PR #177 | historical evidence | 1 (CSV) | `docs/evidence/issue-175/dialog-review/README.md` | keep |
| `docs/evidence/issue-176/README.md` | Issue #176 — rounded outer surfaces, pending owner review | historical evidence | 0 (CSV) | `docs/evidence/issue-176/README.md` | keep |
| `docs/evidence/issue-176/revision-1/README.md` | Issue #176 — owner-requested revision | historical evidence | 1 (CSV) | `docs/evidence/issue-176/revision-1/README.md` | keep |
| `docs/evidence/issue-178/README.md` | Issue #178 — calmer empty viewport | historical evidence | 0 (CSV) | `docs/evidence/issue-178/README.md` | keep |
| `docs/evidence/issue-178/removal-review/README.md` | Issue #178 — complete decorative starfield removal | historical evidence | 1 (CSV) | `docs/evidence/issue-178/removal-review/README.md` | keep |
| `docs/evidence/issue-179/README.md` | Issue #179 — Help → About | historical evidence | 1 (CSV) | `docs/evidence/issue-179/README.md` | keep |
| `docs/evidence/issue-180/README.md` | Issue #180 — shell label removal, pending owner review | historical evidence | 2 (CSV) | `docs/evidence/issue-180/README.md` | keep |
| `docs/evidence/issue-181/README.md` | Issue #181: native scene file picker | historical evidence | 2 (CSV) | `docs/evidence/issue-181/README.md` | keep |
| `docs/evidence/issue-187/README.md` | Issue #187 — progressive mesh wheel zoom | historical evidence | 2 (CSV) | `docs/evidence/issue-187/README.md` | keep |
| `docs/evidence/issue-190/README.md` | Issue #190 — manual camera orbit review | historical evidence | 2 (CSV) | `docs/evidence/issue-190/README.md` | keep |
| `docs/evidence/issue-190/revision-1/README.md` | Issue #190 — horizontal camera orbit revision | historical evidence | 1 (CSV) | `docs/evidence/issue-190/revision-1/README.md` | keep |
| `docs/evidence/issue-190/revision-2/README.md` | Issue #190 — view-relative camera orbit revision 2 | historical evidence | 2 (CSV) | `docs/evidence/issue-190/revision-2/README.md` | keep |
| `docs/evidence/issue-191/README.md` | Issue #191 — adaptive mesh preparation review | historical evidence | 2 (CSV) | `docs/evidence/issue-191/README.md` | keep |
| `docs/evidence/issue-193/README.md` | Issue #193 — Mesh cache, timeline and timer investigation | historical evidence | 2 (CSV) | `docs/evidence/issue-193/README.md` | keep |
| `docs/evidence/issue-195/README.md` | Issue #195 — sustained CPU mesh preparation | historical evidence | 2 (CSV) | `docs/evidence/issue-195/README.md` | keep |
| `docs/evidence/issue-195/transport.md` | Native transport observations | historical evidence | 1 (CSV) | `docs/evidence/issue-195/transport.md` | keep |
| `docs/evidence/issue-201/README.md` | Issue #201 — navigation defaults and shortcut audit | historical evidence | 1 (CSV) | `docs/evidence/issue-201/README.md` | keep |
| `docs/evidence/issue-201/revision-1/README.md` | Issue #201 — owner review revision 1 | historical evidence | 1 (CSV) | `docs/evidence/issue-201/revision-1/README.md` | keep |
| `docs/evidence/issue-202/README.md` | Issue #202 — mesh-only panel focus | historical evidence | 1 (CSV) | `docs/evidence/issue-202/README.md` | keep |
| `docs/evidence/issue-205/README.md` | Issue #205 — screen-fixed Cinematic background | historical evidence | 1 (CSV) | `docs/evidence/issue-205/README.md` | keep |
| `docs/evidence/issue-210/README.md` | Issue #210 — initial Simulation category | historical evidence | 2 (CSV) | `docs/evidence/issue-210/README.md` | keep |
| `docs/evidence/issue-214/README.md` | Issue #214 — LMB vertical inversion | historical evidence | 3 (CSV) | `docs/evidence/issue-214/README.md` | keep |
| `docs/evidence/issue-219/README.md` | Issue #219 Jobs overview review evidence | historical evidence | 2 (CSV) | `docs/evidence/issue-219/README.md` | keep |
| `docs/evidence/issue-219/revision-1/README.md` | Issue #219 owner-review revision 1 | historical evidence | 1 (CSV) | `docs/evidence/issue-219/revision-1/README.md` | keep |
| `docs/evidence/issue-219/revision-2/README.md` | Issue #219 owner-review revision 2 | historical evidence | 0 (CSV) | `docs/evidence/issue-219/revision-2/README.md` | keep |
| `docs/evidence/issue-222/README.md` | Issue #222: Performance configuration rows | historical evidence | 0 (CSV) | `docs/evidence/issue-222/README.md` | keep |
| `docs/evidence/issue-222/revision-2/README.md` | Issue #222 review: compact form and internal mesh telemetry | historical evidence | 0 (CSV) | `docs/evidence/issue-222/revision-2/README.md` | keep |
| `docs/evidence/issue-222/revision-3/README.md` | Issue #222 review: focus-outline clearance | historical evidence | 1 (CSV) | `docs/evidence/issue-222/revision-3/README.md` | keep |
| `docs/evidence/issue-226/README.md` | Issue #226 File Locations review evidence | historical evidence | 1 (CSV) | `docs/evidence/issue-226/README.md` | keep |
| `docs/evidence/issue-229/README.md` | Issue #229 review evidence | historical evidence | 1 (CSV) | `docs/evidence/issue-229/README.md` | keep |
| `docs/evidence/issue-232/README.md` | Issue #232 — mixed playback investigation | historical evidence | 2 (CSV) | `docs/evidence/issue-232/README.md` | keep |
| `docs/evidence/issue-237/README.md` | Issue #237 Jobs window review evidence | historical evidence | 2 (CSV) | `docs/evidence/issue-237/README.md` | keep |
| `docs/evidence/issue-248/README.md` | Issue #248 Video Export dialog review evidence | historical evidence | 2 (CSV) | `docs/evidence/issue-248/README.md` | keep |
| `docs/evidence/issue-248/revision-2/README.md` | Issue #248 owner follow-up evidence | historical evidence | 1 (CSV) | `docs/evidence/issue-248/revision-2/README.md` | keep |
| `docs/evidence/issue-251/README.md` | Issue #251 Jobs first-row clearance | historical evidence | 1 (CSV) | `docs/evidence/issue-251/README.md` | keep |
| `docs/evidence/issue-251/revision-2/README.md` | Issue #251 owner review correction: first Open… focus ring | historical evidence | 1 (CSV) | `docs/evidence/issue-251/revision-2/README.md` | keep |
| `docs/evidence/issue-253/README.md` | Issue #253 Save Image evidence | historical evidence | 0 (CSV) | `docs/evidence/issue-253/README.md` | keep |
| `docs/evidence/issue-253/review-followup.md` | PR #260 fullscreen review follow-up | historical evidence | 0 (CSV) | `docs/evidence/issue-253/review-followup.md` | keep |
| `docs/evidence/issue-253/second-review-followup.md` | PR #260: idle fullscreen capture and invocation parity | historical evidence | 0 (CSV) | `docs/evidence/issue-253/second-review-followup.md` | keep |
| `docs/evidence/issue-255/README.md` | Issue #255: Keyboard Shortcuts without tooltips | historical evidence | 2 (CSV) | `docs/evidence/issue-255/README.md` | keep |
| `docs/evidence/issue-258/README.md` | Issue #258 — free-look steering and target-relative orbit | historical evidence | 1 (CSV) | `docs/evidence/issue-258/README.md` | keep |
| `docs/evidence/issue-259/README.md` | Issue #259: grouped Keyboard Shortcuts | historical evidence | 1 (CSV) | `docs/evidence/issue-259/README.md` | keep |
| `docs/evidence/issue-261/README.md` | Issue #261 — viewport cursor inactivity | historical evidence | 1 (CSV) | `docs/evidence/issue-261/README.md` | keep |
| `docs/evidence/issue-263/README.md` | Issue #263 — RMB free-look cursor visibility | historical evidence | 1 (CSV) | `docs/evidence/issue-263/README.md` | keep |
| `docs/evidence/issue-271/README.md` | Issue #271: shared dialog hierarchy accents | historical evidence | 1 (CSV) | `docs/evidence/issue-271/README.md` | keep |
| `docs/evidence/issue-271/revision-2/README.md` | Issue #271: stronger hierarchy accents | historical evidence | 0 (CSV) | `docs/evidence/issue-271/revision-2/README.md` | keep |
| `docs/evidence/issue-271/revision-3/README.md` | Issue #271: resting pinned-icon color trial | historical evidence | 1 (CSV) | `docs/evidence/issue-271/revision-3/README.md` | keep |
| `docs/evidence/issue-275/README.md` | Issue #275 — Tooltip-free playback clocks | historical evidence | 2 (CSV) | `docs/evidence/issue-275/README.md` | keep |
| `docs/evidence/issue-277/README.md` | Issue #277 — Stable elapsed clock focus | historical evidence | 2 (CSV) | `docs/evidence/issue-277/README.md` | keep |
| `docs/evidence/issue-281/README.md` | Volume legend opacity — issue #281 | historical evidence | 3 (CSV) | `docs/evidence/issue-281/README.md` | keep |
| `docs/evidence/issue-283/README.md` | Video Export MP4 filter and output path — issue #283 | historical evidence | 3 (CSV) | `docs/evidence/issue-283/README.md` | keep |
| `docs/evidence/issue-284/README.md` | Tooltip-free panel pins — issue #284 | historical evidence | 3 (CSV) | `docs/evidence/issue-284/README.md` | keep |
| `docs/evidence/issue-285/README.md` | Video Export ETA evidence — issue #285 | historical evidence | 3 (CSV) | `docs/evidence/issue-285/README.md` | keep |
| `docs/evidence/issue-288/README.md` | Violet filled pins — issue #288 | historical evidence | 2 (CSV) | `docs/evidence/issue-288/README.md` | keep |
| `docs/evidence/issue-288/hover-revision/README.md` | Constant violet pin ink — owner review revision | historical evidence | 3 (CSV) | `docs/evidence/issue-288/hover-revision/README.md` | keep |
| `docs/evidence/issue-291/README.md` | Issue #291 — Editable value focus | historical evidence | 3 (CSV) | `docs/evidence/issue-291/README.md` | keep |
| `docs/evidence/issue-295/README.md` | Issue #295 — Load-error recovery evidence | historical evidence | 3 (CSV) | `docs/evidence/issue-295/README.md` | keep |
| `docs/evidence/issue-32/README.md` | Issue #32 — Source-probe marker visibility | historical evidence | 3 (CSV) | `docs/evidence/issue-32/README.md` | keep |
| `docs/evidence/issue-40/README.md` | Issue #40 — revised visual review | historical evidence | 6 (CSV) | `docs/evidence/issue-40/README.md` | keep |
| `docs/evidence/issue-41/README.md` | Issue #41 native shell evidence | historical evidence | 2 (CSV) | `docs/evidence/issue-41/README.md` | keep |
| `docs/evidence/issue-41/review-1/README.md` | PR #45 owner-review revision — 2026-09-20 | historical evidence | 3 (CSV) | `docs/evidence/issue-41/review-1/README.md` | keep |
| `docs/evidence/issue-42/README.md` | Issue #42 native transport evidence | historical evidence | 2 (CSV) | `docs/evidence/issue-42/README.md` | keep |
| `docs/evidence/issue-42/precision/README.md` | Owner-review refinement: passive time precision | historical evidence | 2 (CSV) | `docs/evidence/issue-42/precision/README.md` | keep |
| `docs/evidence/issue-43/README.md` | Issue #43 review evidence | historical evidence | 2 (CSV) | `docs/evidence/issue-43/README.md` | keep |
| `docs/evidence/issue-43/review-1/README.md` | PR #48 owner-review revision | historical evidence | 2 (CSV) | `docs/evidence/issue-43/review-1/README.md` | keep |
| `docs/evidence/issue-44/README.md` | Issue #44 — final UX3 integration evidence | historical evidence | 3 (CSV) | `docs/evidence/issue-44/README.md` | keep |
| `docs/evidence/issue-46/README.md` | Issue #46 — immersive fullscreen review evidence | historical evidence | 3 (CSV) | `docs/evidence/issue-46/README.md` | keep |
| `docs/evidence/issue-49/README.md` | Issue #49 review evidence | historical evidence | 2 (CSV) | `docs/evidence/issue-49/README.md` | keep |
| `docs/evidence/issue-49/adaptive-time/README.md` | Adaptive duration formatting | historical evidence | 1 (CSV) | `docs/evidence/issue-49/adaptive-time/README.md` | keep |
| `docs/evidence/issue-49/alignment/README.md` | Playback panel alignment refinement | historical evidence | 1 (CSV) | `docs/evidence/issue-49/alignment/README.md` | keep |
| `docs/evidence/issue-49/buffering-layout/README.md` | Requested-time layout stability | historical evidence | 1 (CSV) | `docs/evidence/issue-49/buffering-layout/README.md` | keep |
| `docs/evidence/issue-49/buffering-pause/README.md` | Active Pause during buffering | historical evidence | 1 (CSV) | `docs/evidence/issue-49/buffering-pause/README.md` | keep |
| `docs/evidence/issue-49/single-playback/README.md` | PR #51 owner refinement: one playback clock | historical evidence | 2 (CSV) | `docs/evidence/issue-49/single-playback/README.md` | keep |
| `docs/evidence/issue-53/README.md` | Issue #53 native review evidence | historical evidence | 2 (CSV) | `docs/evidence/issue-53/README.md` | keep |
| `docs/evidence/issue-55/README.md` | Issue #55 — current production UI in video overlays | historical evidence | 4 (CSV) | `docs/evidence/issue-55/README.md` | update |
| `docs/evidence/issue-59/README.md` | Issue #59 — retired UI cleanup evidence | historical evidence | 1 (CSV) | `docs/evidence/issue-59/README.md` | keep |
| `docs/evidence/issue-67/README.md` | Issue #67 review evidence | historical evidence | 3 (CSV) | `docs/evidence/issue-67/README.md` | keep |
| `docs/evidence/issue-67/advanced-refinement/README.md` | PR #73 Advanced refinement | historical evidence | 2 (CSV) | `docs/evidence/issue-67/advanced-refinement/README.md` | keep |
| `docs/evidence/issue-67/metadata-review/README.md` | PR #73 metadata correction | historical evidence | 3 (CSV) | `docs/evidence/issue-67/metadata-review/README.md` | keep |
| `docs/evidence/issue-67/particle-filters/README.md` | PR #73 Particle Filters placement | historical evidence | 2 (CSV) | `docs/evidence/issue-67/particle-filters/README.md` | keep |
| `docs/evidence/issue-67/tools-startup/README.md` | PR #73 Tools startup correction | historical evidence | 2 (CSV) | `docs/evidence/issue-67/tools-startup/README.md` | keep |
| `docs/evidence/issue-68/README.md` | Issue #68 review evidence | historical evidence | 3 (CSV) | `docs/evidence/issue-68/README.md` | keep |
| `docs/evidence/issue-69/README.md` | Issue #69 review evidence | historical evidence | 2 (CSV) | `docs/evidence/issue-69/README.md` | keep |
| `docs/evidence/issue-93/README.md` | Issue #93 — packaged video export | historical evidence | 3 (CSV) | `docs/evidence/issue-93/README.md` | keep |
| `docs/evidence/ux1/README.md` | UX1 evidence — 2026-09-13 | historical evidence | 4 (CSV) | `docs/evidence/ux1/README.md` | keep |
| `docs/evidence/ux2/README.md` | UX2 evidence — 2026-09-13 | historical evidence | 5 (CSV) | `docs/evidence/ux2/README.md` | keep |
| `viewer/README.md` | Wavez viewer | current contract / guide | 5 (CSV) | `viewer/README.md` | update |
| `viewer/ui/about/README.md` | About resources | legal / attribution / provenance | 8 (CSV) | `viewer/ui/about/README.md` | keep |
| `viewer/ui/fonts/README.md` | Numeric font | legal / attribution / provenance | 4 (CSV) | `viewer/ui/fonts/README.md` | keep |
