"""Explicit read-only diagnostic CSV mappings and independent recorded clocks."""
import csv
from decimal import Decimal
import hashlib
import math
from pathlib import Path
import re
import stat

from .contracts import AnalysisError,MIB,float_token,integer,request_float
from .source import _stamp
from .native_analysis import numeric
from .result_store import encoded,DEFAULT_RESULT_BYTES
from . import selectors as S
from .channel_semantics import unit

POLICY="g4-explicit-diagnostic-csv-1"
ROW_BYTES=16384
NUMBER=re.compile(r"[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?")


def parse_number(text,dtype,line,column):
    value=text.strip()
    if not value:return None,"missing_cell"
    if dtype=="i8":
        if not re.fullmatch(r"[+-]?[0-9]+",value):raise AnalysisError("malformed_csv",f"Line {line}, column {column}: expected an integer")
        if len(value.lstrip("+-").lstrip("0"))>19:raise AnalysisError("malformed_csv",f"Line {line}, column {column}: integer outside int64")
        result=int(value.lstrip("+-").lstrip("0") or "0")*(-1 if value.startswith("-") else 1)
        if not -(2**63)<=result<2**63:raise AnalysisError("malformed_csv",f"Line {line}, column {column}: integer outside int64")
        return result,None
    if value.lower() in ("nan","+nan","-nan","inf","+inf","-inf","infinity","+infinity","-infinity"):
        return float(value),"nonfinite_source"
    if not NUMBER.fullmatch(value):raise AnalysisError("malformed_csv",f"Line {line}, column {column}: expected a float64 value")
    result=float(value)
    if not math.isfinite(result) or result==0 and Decimal(value)!=0:
        raise AnalysisError("malformed_csv",f"Line {line}, column {column}: value outside float64 magnitude range")
    return result,None


class Input:
    def __init__(self,path,context):
        if not isinstance(path,str) or len(path)>4096 or not Path(path).is_absolute():raise AnalysisError("invalid_csv","Select an absolute diagnostic file")
        self.path=Path(path);self.context=context
        if not stat.S_ISREG(self.path.stat().st_mode):raise AnalysisError("invalid_csv","Diagnostic input must be a regular file")
        self.file=self.path.open("rb")
        self.charge=0
        try:
            self.stamp=_stamp(self.path,self.file)
            if self.stamp[2]>1024*MIB:raise AnalysisError("input_limit","Diagnostic input exceeds the 1 GiB streamed-file limit")
            self.charge=context.acquire(8*MIB);digest=hashlib.sha256()
            while True:
                context.check();block=self.file.read(MIB)
                if not block:break
                digest.update(block);context.read_bytes+=len(block)
            self.sha256=digest.hexdigest();self.verify()
        except Exception:self.close();raise

    def verify(self):
        self.context.check()
        if _stamp(self.path,self.file)!=self.stamp:raise AnalysisError("source_changed","Diagnostic CSV changed during import; no append or replacement accepted")
        self.context.verified_source(self.path,self.stamp,(self.sha256,self.stamp[2]))

    def close(self):
        self.file.close()
        if self.charge:self.context.release(self.charge);self.charge=0

    def __enter__(self):return self
    def __exit__(self,*_):self.close()

    def rows(self,mapping):
        self.verify();self.file.seek(0);physical=0;row_bytes=0
        def lines():
            nonlocal physical,row_bytes
            while True:
                self.context.check();raw=self.file.readline(ROW_BYTES+1)
                if not raw:break
                self.context.read_bytes+=len(raw)
                physical+=1;row_bytes+=len(raw)
                if row_bytes>ROW_BYTES:raise AnalysisError("malformed_csv",f"CSV logical row ending at line {physical} exceeds 16 KiB")
                try:yield raw.decode("utf-8-sig" if physical==1 else "utf-8")
                except UnicodeError as exc:raise AnalysisError("malformed_csv",f"Line {physical}: expected UTF-8 text") from exc
        reader=csv.reader(lines(),delimiter=mapping["delimiter"],strict=True)
        try:
            header=next(reader,None);row_bytes=0
            if not header or len(header)>256 or len(set(header))!=len(header) or any(not v or len(v)>128 for v in header):
                raise AnalysisError("malformed_csv","Header needs 1–256 unique named columns of at most 128 characters")
            columns=[mapping["time_column"]]+[c["column"] for c in mapping["values"]]
            if any(name not in header for name in columns):raise AnalysisError("invalid_csv","Mapped column is absent from CSV header")
            previous_line=reader.line_num;index=0;skipped=0
            for row in reader:
                start_line=previous_line+1;previous_line=reader.line_num;row_bytes=0
                if not row and mapping["blank_lines"]=="skip":skipped+=1;continue
                if len(row)!=len(header):raise AnalysisError("malformed_csv",f"Lines {start_line}–{reader.line_num}: column count differs from header")
                if index>=mapping["row_limit"]:raise AnalysisError("input_limit","Diagnostic row limit exceeded; no partial import")
                values=dict(zip(header,row));time,reason=parse_number(values[mapping["time_column"]],"f8",start_line,mapping["time_column"])
                typed=[parse_number(values[c["column"]],c["dtype"],start_line,c["column"]) for c in mapping["values"]]
                yield dict(index=index,line=start_line,end_line=reader.line_num,time=time,time_reason=reason,raw_time=values[mapping["time_column"]],
                           typed=typed,raw_values={c["column"]:values[c["column"]] for c in mapping["values"]},skipped_blank_lines=skipped)
                index+=1
            self.skipped_blank_lines=skipped
        except csv.Error as exc:raise AnalysisError("malformed_csv",f"Line {reader.line_num}: {exc}") from exc
        self.verify()


def mapping(arguments):
    S.keys(arguments,["path","key","name","time_column","time_units","values","delimiter","blank_lines","row_limit","max_gap","missing_intervals","time_offset","offset_origin","result_bytes"],
           ["path","key","time_column","time_units","values","delimiter"])
    key=arguments["key"]
    if not isinstance(key,str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,80}",key):raise AnalysisError("invalid_csv","A source-scoped diagnostic key is required")
    delimiter=arguments["delimiter"]
    if delimiter not in (",",";","\t","|"):raise AnalysisError("invalid_csv","Choose an explicit supported delimiter")
    time_column=arguments["time_column"]
    if not isinstance(time_column,str) or not 1<=len(time_column)<=128:raise AnalysisError("invalid_csv","Select a time column")
    values=arguments["values"]
    if not isinstance(values,list) or not 1<=len(values)<=16:raise AnalysisError("invalid_csv","Map 1–16 value columns")
    result=[]
    for value in values:
        S.keys(value,["column","units","dtype","semantic"],["column","units","dtype"])
        if not isinstance(value["column"],str) or not 1<=len(value["column"])<=128 or value["dtype"] not in ("i8","f8"):raise AnalysisError("invalid_csv","Named column and explicit i8/f8 dtype required")
        semantic=value.get("semantic","continuous")
        if semantic not in ("continuous","signed","phase","categorical","identifier"):raise AnalysisError("invalid_csv","Unknown diagnostic channel semantics")
        result.append(dict(value,units=unit(value["units"]),semantic=semantic))
    if len({v["column"] for v in result})!=len(result):raise AnalysisError("invalid_csv","Value columns must be unique")
    gap=request_float(arguments["max_gap"]) if "max_gap" in arguments else None
    if gap is not None and gap<=0:raise AnalysisError("invalid_csv","Maximum connected gap must be positive")
    intervals=arguments.get("missing_intervals",[])
    if not isinstance(intervals,list) or len(intervals)>256:raise AnalysisError("invalid_csv","At most 256 declared missing intervals")
    parsed=[]
    for interval in intervals:
        pair=interval
        if not isinstance(pair,list) or len(pair)!=2:raise AnalysisError("invalid_csv","Missing intervals are [start,end] in raw time")
        a,b=request_float(pair[0]),request_float(pair[1])
        if a>=b:raise AnalysisError("invalid_csv","Missing interval must have increasing endpoints")
        parsed.append([float_token(a),float_token(b)])
    offset=request_float(arguments.get("time_offset",0))
    origin=arguments.get("offset_origin","none")
    if not isinstance(origin,str) or len(origin)>256 or offset and origin in ("","none"):raise AnalysisError("invalid_csv","A manual time offset requires its declared origin")
    blank=arguments.get("blank_lines","reject")
    if blank not in ("reject","skip"):raise AnalysisError("invalid_csv","Blank line policy must be reject or explicit skip")
    if not isinstance(arguments.get("name",key),str) or len(arguments.get("name",key))>128:raise AnalysisError("invalid_csv","Diagnostic name must be at most 128 characters")
    return dict(key=key,name=arguments.get("name",key),time_column=time_column,time_units=unit(arguments["time_units"]),values=result,delimiter=delimiter,
                blank_lines=blank,row_limit=integer(arguments.get("row_limit",1_000_000),"CSV row limit",1,10_000_000),max_gap=float_token(gap) if gap else None,missing_intervals=parsed,
                time_offset=float_token(offset),offset_origin=origin)


def run(source,arguments,cache,*,provenance=None):
    spec=mapping(arguments);context=source.context
    with Input(arguments["path"],context) as input:
        count=0;previous=-math.inf;valid_axis=True
        for row in input.rows(spec):
            value=row["time"]
            if value is None or not math.isfinite(value) or value<=previous:valid_axis=False
            if value is not None:previous=value
            count+=1
        if not valid_axis and request_float(spec["time_offset"])!=0:raise AnalysisError("index_only","Manual physical time alignment requires a valid CSV time axis")
        clock="csv:"+input.sha256+":"+hashlib.sha256(encoded(spec)).hexdigest()
        manifest=dict(algorithm=POLICY,source=source.identity(),diagnostic_source=dict(path=str(input.path),sha256=input.sha256,bytes=str(input.stamp[2])),mapping=spec,
                      binding="explicit currently opened capture/run; independent diagnostic clock",clocks={clock:dict(axis="native_time" if valid_axis else "record_index",time_units=spec["time_units"])},
                      provenance=provenance or {},skipped_blank_lines=input.skipped_blank_lines,missing_policy="missing cells and declared intervals unavailable; no fill",value_origin="supplied diagnostic CSV; distinct from viewer-derived channels")
        result_key=hashlib.sha256(encoded(manifest)).hexdigest();previous=None
        with cache.begin(manifest,expected_rows=count*len(spec["values"]),expected_support=count,byte_limit=arguments.get("result_bytes",DEFAULT_RESULT_BYTES),context=context) as writer:
            for row in input.rows(spec):
                context.progress("diagnostic_import",row["index"],count)
                time=row["time"];token=float_token(time) if time is not None else dict(text="",f64_le_hex="")
                usable_time=time is not None and math.isfinite(time)
                interval=next((pair for pair in spec["missing_intervals"] if usable_time and request_float(pair[0])<=time<=request_float(pair[1])),None)
                gap=bool(usable_time and previous is not None and spec["max_gap"] and time-previous>request_float(spec["max_gap"]))
                support_key="s"+str(row["index"])
                writer.append(dict(key=support_key,csv_line=row["line"],csv_end_line=row["end_line"],csv_data_row=row["index"],raw_time=row["raw_time"],raw_values=row["raw_values"],gap_from_previous=gap,declared_missing_interval=interval),kind="support")
                for column,(value,reason) in zip(spec["values"],row["typed"]):
                    aligned=time-request_float(spec["time_offset"]) if usable_time else None
                    if aligned is not None and not math.isfinite(aligned):raise AnalysisError("arithmetic_overflow","Declared time alignment overflows float64")
                    base=dict(result_id=result_key,selection_key=spec["key"],selection_revision="1",source_key=input.sha256,object="diagnostic:"+spec["key"],association="diagnostic_row",member_key="",source_row=str(row["line"]),clock=clock,
                              sample_index=str(row["index"]),sequence=str(row["index"]),time=token["text"],time_f64_le_hex=token["f64_le_hex"],aligned_time=format(aligned,".17g") if aligned is not None else "",channel=column["column"],component="",statistic="supplied_diagnostic",source_dtype=column["dtype"],units=column["units"],
                              time_status="exact" if valid_axis else "index_only",position_status="not_applicable",support_key=support_key)
                    writer.append(base|numeric(None if interval else value,reason="declared_missing_interval" if interval else reason))
                if usable_time:previous=time
            input.verify();source.verify()
            reference=writer.finish()
        return dict(result=reference,row_count=writer.counts["rows"],support_count=count,algorithm=POLICY,axis="native_time" if valid_axis else "record_index",clock=clock)
