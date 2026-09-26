# Capture format policy

The current branch supports **SIMSCP4**, normally **`.ssc`**, through
`SceneCapture` / `SceneReader` across viewer, analysis, examples and tools.
Package **3.0.0** marks the clean break from SIMSCP3. Older captures are refused by
magic/version; changing a suffix does not upgrade a capture. Writer, native reader,
Python analysis, fixtures and current documentation change together. There is no
legacy parser, fallback or migration layer in the runtime. No conversion tool is
required or supplied by #102. A separate one-time conversion utility may be
considered later if retained historical captures justify it.

See the [wire contract](../G3_FORMAT.md), [API](../SIMSCOPE_API.md),
[format investigation](SSC_ACCELERATION.md) and
[capture fidelity inventory](SSC_CAPTURE_PARAMETERS.md). Historical reports and
evidence remain unchanged and describe their original contracts.

Source values, explicit identity, corruption refusal and bounded allocation remain
part of the scientific contract. Shared `storage.py`, `codec.py`,
`capture_index.gd` and `typed_decode.gd` serve only the current capture contract.
SSC version 4, scene inspection v2, G4 inspection v3 and render jobs v1/v2 are
separate versioned contracts. Existing recipes tied to old capture identities need
recreation for newly exported captures; recipes are not relabeled automatically.
External research simulations must update their integrations to the current API;
they impose no runtime compatibility requirement on SimScope.
