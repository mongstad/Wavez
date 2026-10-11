# Prepared timeline

The main playback track has one teal prepared band: the intersection of resident
CPU preparations for every currently required visible layer. Field-only coverage
remains available to diagnostics; it is never painted on the main track.
Dark gaps need preparation. The native playhead shows committed position, and
there is no elapsed-progress fill.

Particles and meshes require their prepared adjacent sample pairs. Fields use
their held selected-channel sample. Static objects require their one reusable
sample throughout the union clock; dynamic objects contribute no requirement
before their first sample. Source stamps/generations, configuration, visibility,
and preview budgets must match the controllers' current keys. Publication is
read-only: it does not request, pin, prepare or upload data. Changes in resident
keys or scene requirements refresh coverage without the old 200 ms throttle;
unchanged snapshots avoid rescanning source sample tables.

A full-length band requires the terminal sample/pair as well as the interior
intervals. If the exact terminal preparation is missing, the endpoint stays
uncolored by one logical pixel. This distinguishes an interval approaching the
end from readiness at the end itself.

A positive prepared interval narrower than three logical pixels retains its
actual duration on the track. A detached teal diamond above its midpoint indicates
**a very short interval is present**. The diamond's width does not represent time
and does not bridge gaps. It scales with the UI and uses Dark/Light theme ink.
The playhead stays above the band; short coverage can be noticed even beside it
on a minutes- or hours-long capture.

Prepared CPU data can still require main-thread GPU staging. Existing startup
runway gates, frame cost and production throughput also affect playback. The band
is a resident-data contract, not a guarantee of uninterrupted frame rate.
Preparation algorithms, RAM allocation, worker scheduling, scientific data,
rendering and transport timing are unchanged by #378. Scheduling/performance work
belongs to #377.

## Validation and owner review

See [#378 evidence](evidence/issue-378/README.md) for real mixed-capture intervals,
controlled particle underflow, the exact gate reason, focused tests, rendered
Dark/Light cues, package results and limitations. Historical evidence retains the
semantics and review state that existed when it was produced.

Before acceptance:

1. Open a real mixed particle/field capture and let it prepare while paused. The
   band must stop at the full scene's limiting resident interval, even when fields
   alone are ready to the end. Inspect Performance details for the limiting layer.
2. Play at 1× and scrub to a gap. During particle buffering the bar must not claim
   readiness for the missing target pair; releasing preparation must recover with
   the normal gates and committed clock.
3. Toggle required layer visibility and change a field channel or particle mapping.
   Old coverage must disappear, then return only as matching preparations arrive.
4. On a long particle or mesh capture, inspect the diamond beside the playhead at
   ordinary and 4K UI scales in Dark and Light. Confirm it reads as presence rather
   than extra duration, with the playhead still prominent.
5. Repeat opening, seeking and playback in the Linux standalone candidate. Check
   Help → About shows candidate v0.1.0.100 before acceptance.
