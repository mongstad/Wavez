"""Verify all source inputs of a retained result dependency graph before reuse."""
from .contracts import AnalysisError,MIB
from .source import SourceSnapshot
from .diagnostics import Input
from .member_assets import asset_stamp
from .result_store import encoded


def verify_inputs(parent,cache,references,*,members=False):
    """Sequential source handles, one bounded manifest workspace at a time.

    A cached comparison/period may have several underlying captures/CSVs. Its
    primary source alone cannot establish that those inputs remain unchanged.
    """
    context=parent.context;seen_sources=set();seen_csv=set()
    for _,manifest in cache.dependencies(references,context):
        ref=manifest.get('source')
        if not isinstance(ref,dict) or not {'path','format','uuid','sha256','committed_bytes','complete_records'}<=ref.keys():raise AnalysisError('invalid_result','Scientific result lacks a pinned source identity')
        key=encoded(ref)
        if key not in seen_sources:
            seen_sources.add(key)
            if ref==parent.identity():parent.verify()
            else:
                with SourceSnapshot(ref['path'],committed_bytes=ref['committed_bytes'],sha256=ref['sha256'],context=context,memo=parent.memo) as source:
                    if source.identity()!=ref:raise AnalysisError('source_changed','A transitive scientific source binding differs')
        csv=manifest.get('diagnostic_source')
        if csv is not None:
            if not isinstance(csv,dict) or set(csv)!={'path','sha256','bytes'}:raise AnalysisError('invalid_result','Malformed diagnostic provenance')
            key=encoded(csv)
            if key not in seen_csv:
                seen_csv.add(key)
                with Input(csv['path'],context) as data:
                    if data.sha256!=csv['sha256'] or str(data.stamp[2])!=csv['bytes']:raise AnalysisError('source_changed','A transitive diagnostic input differs from its verified result')
    if members:
        refs=cache.member_references(references,context)
        if refs and parent.assets is None:raise AnalysisError('invalid_asset','Full result provenance requires its exact member assets')
        for ref in refs:
            path,_shape,size=parent.assets.path(ref);before=asset_stamp(path)
            with context.allocation(size*3+MIB):
                values=parent.assets.read(ref,context);del values
            if asset_stamp(path)!=before:raise AnalysisError('invalid_asset','Member provenance changed while verifying')
            context.verified_source(path,before)
