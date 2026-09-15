from pathlib import Path
import tempfile
import unittest

from simscope_export.analysis import Context,AnalysisError
from simscope_export.analysis.result_store import ResultCache
from simscope_export.analysis.plot_preview import preview,series


class PlotTests(unittest.TestCase):
    def test_bounded_extrema_missing_and_exact_integer_differences(self):
        with tempfile.TemporaryDirectory() as directory:
            cache=ResultCache(Path(directory)/"owner"/"results");context=Context()
            key=dict(selection_key="selected",channel="value",component="",statistic="value",member_key="id:9007199254740993")
            with cache.begin({},expected_rows=10000,context=context) as writer:
                for i in range(10000):
                    value=2**53+i if i!=5001 else 2**53+20000
                    writer.append(key|dict(time=str(i*.25),sample_index=str(i),value=str(value) if i%100 else "",units="m",clock="native",time_status="exact",value_status="source" if i%100 else "unavailable",source_dtype="i8"))
                ref=writer.finish()
            available=series(cache,ref,context);self.assertEqual(len(available["series"]),1)
            data=preview(cache,ref,key,context,bins=8)
            self.assertEqual(len(data["bins"]),8);self.assertEqual(data["missing"],100)
            self.assertEqual(data["y_range"],[str(2**53+1),str(2**53+20000)])
            self.assertTrue(any(cell.get("max",[None,None])[1]==str(2**53+20000) for cell in data["bins"]))
            self.assertEqual(len(data["bins"][0]["min"]),5)
            self.assertGreater(data["bins"][0]["last"][4],data["bins"][0]["first"][4])
            self.assertEqual(context.used,0)

    def test_all_missing_constant_and_mixed_clock_refusal(self):
        with tempfile.TemporaryDirectory() as directory:
            cache=ResultCache(Path(directory)/"owner"/"results");context=Context()
            key=dict(selection_key="s",channel="x",component="",statistic="mean",member_key="")
            for values,clocks in [(["",""] ,["a","a"]),(["2","2"],["a","a"]),(["2","2"],["a","b"])]:
                with cache.begin({},expected_rows=2,context=context) as writer:
                    for i,value in enumerate(values):writer.append(key|dict(value=value,time=str(i),units="u",clock=clocks[i],time_status="exact",value_status="source" if value else "unavailable"))
                    ref=writer.finish()
                if clocks[0]!=clocks[1]:
                    with self.assertRaisesRegex(AnalysisError,"mix clocks"):preview(cache,ref,key,context)
                else:
                    data=preview(cache,ref,key,context)
                    self.assertEqual(data["finite"],0 if not values[0] else 2)
                    self.assertEqual(data["y_range"],None if not values[0] else ["2","2"])


if __name__=="__main__":unittest.main()
