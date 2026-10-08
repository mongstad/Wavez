# WAVEZ Scene Format policy

The sole current scene format is **WAVEZ Scene Format** (`.wvz`, `WVZ1`).
`wavez_export.SceneCapture` writes it; Python `SceneReader`, scientific analysis,
the native viewer, video export and current tools read it. Public file entry
points require a `.wvz` path and validate the exact WVZ1 bytes. The 16-byte
little-endian prefix is `<8sII>` with magic `b'WVZ1\0\0\0\0'`, unsigned version
1 and metadata length; metadata JSON version is 1. Records use `FRM1` and
`COMMIT1\0`. See the [wire contract](WVZ1_FORMAT.md) and [Python API](../WAVEZ_API.md).

The alpha-stage migration is a clean break. Old `.ssc` data, SIMSCP4 signatures,
old source pins and retired SimScope serialized kinds are refused. Renaming a
file does not convert it. There is no dual reader/writer, compatibility alias,
automatic migration or `.ssc` converter. Regenerate scenes from their original
simulations with the current exporter. The Python package version is 4.0.0;
application build and inspection/job schema versions are independent axes.

Scientific values, topology, precision, timestamps, statistics, checksums,
compression, append handling and allocation guards retain their established
semantics. Interactive playback checks structure, descriptors and commits but
does not recompute payload SHA; [explicit whole-scene verification](PLAYBACK_INTEGRITY.md)
and Python analysis use strict payload checks.

Historical [branding](BRANDING_MIGRATION.md) and [format investigation](SSC_ACCELERATION.md)
reports accurately describe the formats they tested. They do not define the
current WAVEZ runtime contract.
