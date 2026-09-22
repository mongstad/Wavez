# PR #73 Advanced refinement

At the owner's explicit request, one **Advanced** expander now directly contains
Size by, Brightness by, Recorded history [T], Exposure, Gamma and Bloom. The Trails
and Advanced Post-processing expanders are removed. There are no nested groups.
This explicit refinement supersedes the earlier design prohibition on an Advanced
label for these controls only; no wider #68 redesign is included.

The existing Size/Brightness disclosure key controls the combined expander.
Retired Trails/Post-processing disclosure keys remain inert recipe data, preserving
round trips. Scientific values, control keys and callbacks are unchanged.

Compatibility shell: **512 checks PASS**, including direct parentage of all six
controls, exactly one expander, startup behavior, existing scientific/state round
trips, actual export and menu routes. Source hashes unchanged. Godot import and
whitespace checks passed. Forward+ was not rerun for this grouping-only correction.

Owner check: expand Advanced and use each option, including Recorded history [T].
Confirm the former Trails and Post-processing expanders are absent. Pending review.
