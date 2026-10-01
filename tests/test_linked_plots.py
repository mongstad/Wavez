from decimal import Decimal
import unittest
from tests import test_comparisons as fixtures
from wavez_export.analysis.linked_plots import run
from wavez_export.analysis import AnalysisError


class LinkedTests(unittest.TestCase):
    setUp=fixtures.ComparisonTests.setUp
    tearDown=fixtures.ComparisonTests.tearDown
    data=fixtures.ComparisonTests.data
    def test_separate_clocks_and_exact_integer_preview_coordinates(self):
        a=self.data(self.source,"left",[0,1],[2**53,2**53+2]);b=self.data(self.other,"right",[10,11],[2**53+1,2**53+3]);b["time"]["offset"]=10
        output=run(self.cache,dict(bindings=[dict(label="Run A",binding=a),dict(label="Run B",binding=b)],bins=8),self.source.context)
        first,second=output["plots"]
        self.assertEqual(list(map(Decimal,first["x_range"])),[0,1])
        self.assertNotEqual(first["clock"],second["clock"])
        self.assertEqual(Decimal(first["y_range"][1])-Decimal(first["y_range"][0]),3)
        self.assertAlmostEqual(second["bins"][0]["first"][4],1/3)
        self.assertEqual(first["count"],2);self.assertEqual(second["count"],2)

    def test_shared_axis_requires_explicit_units_and_reference(self):
        a=self.data(self.source,"left",[0,1],[1,2]);b=self.data(self.other,"right",[0,1],[2,3]);b["time"]["reference"]="another origin"
        with self.assertRaisesRegex(AnalysisError,"unit/reference"):
            run(self.cache,dict(bindings=[dict(label="A",binding=a),dict(label="B",binding=b)]),self.source.context)

    def test_missing_locations_map_to_global_time_bounds(self):
        a=self.data(self.source,"left",[0,1],["",2]);b=self.data(self.other,"right",[10,11],[2,3])
        output=run(self.cache,dict(bindings=[dict(label="A",binding=a),dict(label="B",binding=b)],bins=10),self.source.context)
        self.assertAlmostEqual(output["plots"][0]["bins"][0]["missing_x"],.05/11)
