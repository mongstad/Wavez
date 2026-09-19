# UX2 — Theme and primitive component library

The owner reviewed and accepted UX2 on 2026-09-13 at `5fae711`. The library remains opt-in and development-only. [UX1](UX1_DESIGN_SYSTEM.md) supplies the design specification; [UX2's report](UX2_REPORT.md) records the accepted implementation decisions and adjustments in its original review-time wording. No production viewer, panel, renderer, capture API, recipe or export consumer uses it yet. **UX3 is on hold until further notice from the owner.**

## Launch the laboratory

From the repository root with Godot 4.7.2 available:

```bash
godot --headless --path viewer --editor --import
godot --path viewer res://ui/lab/ui_laboratory.tscn
```

The scene opens without a capture. Four pages cover Controls, Numbers, Feedback and Tokens. Change scale using the header selector; resize and scroll each page. Tab/Shift-Tab moves focus, Space activates buttons, Enter commits numbers, and Escape restores a numeric draft. The example dialog has fixed actions and a scrolling body. All actions emit local demonstration intent; none open captures, write exports or start workers. The main scene and production menus are unchanged.

A fresh checkout requires Godot's normal asset import before running scripts. Environments without writable Godot user/config directories can set `XDG_DATA_HOME` and `XDG_CONFIG_HOME` to fresh local directories. The validator does this automatically.

## Theme and token ownership

- [simscope_tokens.gd](../viewer/ui/theme/simscope_tokens.gd) defines the typed token schema and accepted defaults. [simscope_tokens.tres](../viewer/ui/theme/simscope_tokens.tres) is its canonical instance; it deliberately contains no duplicate values.
- [simscope_theme.gd](../viewer/ui/theme/simscope_theme.gd) derives StyleBoxes, native control items and semantic type variations. [simscope_dark.tres](../viewer/ui/theme/simscope_dark.tres) is the loadable Theme entry point. Edit tokens/builder, not a serialized copy of generated styles. Consumers treat this shared resource as immutable; build a new instance for an isolated preview.
- [ui_scale.gd](../viewer/ui/theme/ui_scale.gd) applies scale **once** at an explicitly owned Window. Fonts, padding and component minimums remain logical units. Do not also multiply tokens or `Control.scale`. Laboratory SubViewports use their own logical size override, without modifying export viewport conventions.
- [SVG icons](../viewer/ui/icons/) use Godot's DPITexture importer, preserving SVG source in imported resources and re-rasterizing for the active viewport. The builder caches color-mapped icon resources. No OS symbol font or emoji supplies commands. [Godot DPITexture documentation](https://docs.godotengine.org/en/stable/classes/class_dpitexture.html) describes this per-viewport behavior; the API is marked experimental, so revalidate on an engine upgrade.
- The existing Godot fallback sans remains the body face. FontVariation's 0.5 emboldening supplies heading emphasis without another sans font. [DejaVu Sans Mono 2.37](../viewer/ui/fonts/DejaVuSansMono.ttf) is bundled for numeric roles, with its [original notices](../viewer/ui/fonts/LICENSE-DejaVu.txt). No system substitution is needed.

This follows Godot's [Theme inheritance and type variations](https://docs.godotengine.org/en/stable/classes/class_theme.html). Apply the Theme to a Control subtree. Pass it explicitly to an independent Window or popup. Do not install it in project settings or the production root in UX2. No widget owns a reader, renderer, worker, source hash, scientific selection or render snapshot. There are no per-frame component callbacks.

```gdscript
const Action = preload("res://ui/components/action_button.gd")
const Number = preload("res://ui/components/number_field.gd")

func build_example(parent: Control) -> void:
    parent.theme = preload("res://ui/theme/simscope_dark.tres")
    var action = Action.new()
    action.configure(&"example.apply", "Apply example", &"PrimaryButton")
    parent.add_child(action)
    action.invoked.connect(func(id): print("Intent: ", id))

    var field = Number.new()
    field.kind = Number.Kind.EXACT_INTEGER
    field.set_model(9007199254740993) # int64 throughout, never float
    parent.add_child(field)
    field.committed.connect(func(value): print("Validated draft: ", value))
```

## Shared roles and primitive contracts

| Area | Implementation / consumer contract |
|---|---|
| Actions | `action_button.gd`: stable action ID, label/accessibility name, semantic role, optional shortcut description, invoked signal. The nested native Button supports normal Godot Shortcut assignment. `set_available(false, reason)` requires a visible reason. Icon-only actions preserve the name and tooltip; 32×32 logical target |
| Button variations | `SecondaryButton`, `PrimaryButton`, `DestructiveButton`, `SelectedButton`, `CompactButton`, `IconAction`, `SectionHeader`. Compact actions set their custom minimum to the compact token; native StyleBox metrics supply 28 px |
| Text variations | `ApplicationTitle`, `PanelTitle`, `SectionTitle`, `PropertyLabel`, `SecondaryLabel`, `HelpLabel`, `StatusLabel`, `NumericValue`, `ErrorLabel` |
| Input variations | `NumericInput`, `InvalidInput`, `InvalidNumericInput`, `SearchInput`; native selection, caret, focus, read-only and error treatments |
| Numbers | `number_field.gd`: float64 or signed int64, model refresh, editable draft, explicit commit, cancellation, optional finite/range/caller validator. Signals carry values/intent; consumers still validate application constraints before changing their model |
| Layout | `property_row.gd`: 128 px label column, flexible editor, explicit unit/help. Stacks below 320 logical pixels. Does not format or convert values. `PropertyGroup`, `RaisedPanel`, `PopupSurface` centralize padding and surfaces |
| Disclosure | `disclosure.gd`: explicit section ID and body reference, silent `set_expanded`, expansion intent signal, focus recovery on collapse. No label-based sibling lookup |
| Choices | Native CheckBox/ButtonGroup provide boolean/radio controls. `enum_field.gd` binds stable option IDs, preserves identity across reorder/rename, and refreshes without selection intent. Unavailable selections have visible explanations |
| Approximate scalars | `scalar_slider.gd` and `visual_spin_box.gd`: bounded visual multipliers only. Slider refresh uses no-signal assignment and has a tabular readout. Do not use these for exact IDs or scientific thresholds |
| Feedback | `status_badge.gd` supplies compact icon/text status. `inline_message.gd` supplies info/success/warning/error text and optional acknowledgement. Error/recovery notices persist until the caller acknowledges them; dismissal never cancels an application job |
| Progress | `progress_status.gd` keeps percentages outside the two-tone bar. Unknown progress is explicit text with no fabricated percentage or decorative animation. Always use this composition when a percentage is needed: a single overlaid font color cannot meet contrast against both track and accent fill |
| Dialogs | `dialog_shell.gd`: explicit Theme and scale boundary, 90% size cap, fixed heading/actions, scrollable body, Escape/close and focus restoration. Action signals do not implement publication, overwrite or worker policies |
| Native controls | Buttons, checkbox/radio, line/text edits, option/menu buttons, spin boxes, sliders, tabs, panel containers, separators, scrollbars, Tree, ItemList, tooltips, popup menus, progress and dialog/window chrome share the foundation |

Composition examples are in [ui_laboratory.gd](../viewer/ui/lab/ui_laboratory.gd). Object/selection workspaces, transport, analysis forms, source-context binding, plots, result tables, path pickers and application settings remain future consumers under their own milestone gates. The primitive Tree/list examples do not implement those workflows.

## Exact numeric behavior

`set_model` is silent; it accepts a finite float64 or an actual int64 according to field kind. An unchanged commit returns without parsing, preserving the original bits (including negative zero). Enter submits a changed valid draft; focus loss leaves the draft pending; Escape restores the last committed text. Invalid drafts and their inline error remain editable. A validator can reject a value without modifying the committed model.

Signed integer parsing validates decimal syntax and lexical int64 bounds before conversion. It rejects decimals, exponents and overflow; it supports both extrema and IDs above 2^53. It never converts through float.

Scientific text uses [float64_text.gd](../viewer/ui/components/float64_text.gd): a bounded decimal rational parser with integer limbs and one IEEE-754 round-to-nearest/ties-to-even conversion. This is needed because the tested engine's `String.to_float` underflows valid small values and misrounds some mantissas. Source-decoded float64 values bypass text parsing on refresh. Formatting uses the engine's full-precision formatter plus an explicit negative-zero case. The independent Python oracle validates formatting back through the new parser.

The draft limit is 768 characters; oversized input, non-finite values, overflow and nonzero input rounded to zero are refused visibly. Finite subnormals are supported. This boundary applies only to the new presentation primitive; no production scientific parser or stored numeric format was changed.

## Metrics and proposed adjustments for review

The actual Godot fallback sans at 14 px has a 20 px font height; the 13 px mono face has a 17 px height, and all ten digits have 8 px advances. Native Button padding is computed from the font height: 6 px top/bottom gives exactly 32 px; 4 px gives 28 px compact. Numeric editors have a 32 px minimum and can grow. Labels wrap without shrinking. These metrics preserve the accepted height/font values rather than forcing fixed padding around a mismatched font.

| Finding | Evidence and UX2 treatment |
|---|---|
| Control boundary on active fills | `border.control` is 2.782:1 on hover and 2.389:1 on pressed. Hover/pressed outlines use existing `text.secondary`; rest remains `border.control`. Palette values are unchanged |
| Destructive pressed text | `state.error` is 4.224:1 on pressed. Pressed destructive labels use `text.primary`, retaining the error border and explicit destructive wording |
| Read-only values | Read-only scientific values remain meaningful content. They use secondary text rather than the disabled-value color; unavailable actions still use the disabled treatment and a visible explanation |
| Slider focus | Native HSlider has no focus StyleBox item. `focus_slider.gd` draws the shared ring on focus changes, without an idle callback; it preserves native keyboard behavior |
| Progress text | Accent-filled and dark unfilled portions cannot share one compliant overlaid text color. The numeric readout stays outside the bar |
| Focus clearance | Shared focus StyleBox expands 4 px (2 px ring plus 2 px gap); standard 8 px gaps and panel padding keep adjacent control focus visible. Focus on the scrolled-out portion of a widget is naturally clipped by its scroll viewport |
| Native motion / tooltips | UX2 uses immediate native hover/pressed/selection changes. The accepted 80/60 ms motion tokens are retained but not tweened. Native initial tooltip delay is 500 ms; adjacent-target 100 ms timing and global reduced-motion preferences remain later interaction work. This scope adjustment is part of the accepted UX2 baseline |

Colors are UI-only. Do not reuse them for scientific palettes, source support encodings, GPU mappings, geometry or exports. All 71 tested foreground/background combinations pass their specified 4.5:1 text or 3:1 indicator target; this is measured palette arithmetic plus actual themed control evidence, not a whole-product accessibility certification.

## Validation and limits

Run with the project's Python dependencies and a display:

```bash
python3 tools/validate_ux2.py --godot /path/to/godot --output-dir results/ux2-new-review
```

The output directory must be new. The runner imports resources, generates two tiny analytic fixtures and 300 independent float64 cases, exercises native input and all 16 size/scale combinations, verifies production snapshot/pixel isolation, and runs the existing HUD test. It hashes current source before and after validation and rejects changes, including added or removed files. It rejects script errors or warning logs even if Godot exits with zero. Captures and raw logs remain ignored. See the [retained evidence guide](evidence/ux2/README.md).

The historical UX2 comparison against `7037f5f` is separate from current-tree
validation: that commit belongs to the archived development history, not this
fresh repository. Pass `--source-baseline <local-commit>` to explicitly request
the historical comparison in a checkout containing that history. An unavailable
baseline fails with an actionable error; the default report records the
historical comparison as `NOT_REQUESTED`, never as a reproduced historical PASS.
Historical reports and hashes remain unchanged. Current validation needs neither
the old workspace nor its commits.

The 4K and scale matrix use actual Godot SubViewport controls, with separate native root/dialog scale tests. They are not physical 4K or mixed-monitor tests. The tested Forward+ backend uses llvmpipe software Vulkan in this execution environment. Screenshot inspection and programmatic key/pointer input are not a human usability, screen-reader or cross-platform acceptance session. Very small logical canvases deliberately scroll; they are stress cases, not a new production minimum-window promise.
