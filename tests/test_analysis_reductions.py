from decimal import Decimal,localcontext
import unittest
import numpy as np

from wavez_export.analysis import AnalysisError,Context
from wavez_export.analysis.reductions import statistics


class ReductionTests(unittest.TestCase):
    def values(self,result):return {k:v["value"] for k,v in result["statistics"].items()}

    def test_cancellation_and_source_precision(self):
        x=np.array([1e16,1.,-1e16],dtype="f8");before=x.tobytes()
        result=self.values(statistics(x))
        self.assertEqual(result["sum"],1.);self.assertEqual(result["mean"],1/3)
        with localcontext() as ctx:
            ctx.prec=60;y=[Decimal.from_float(float(v)) for v in x];mean=sum(y)/3
            expected=float((sum((v-mean)**2 for v in y)/3).sqrt())
        self.assertAlmostEqual(result["stddev"]/expected,1.,places=15)
        self.assertEqual(x.tobytes(),before)
        values=np.array([1.,1.+2**-40],dtype="f8")
        self.assertGreater(self.values(statistics(values))["max"],float(values.astype("f4").max()))

    def test_exact_integer_values_sums_and_quantile_endpoints(self):
        x=np.array([2**63-3,2**63-1],dtype="i8")
        result=self.values(statistics(x,metrics=["min","max","sum","quantile:0","quantile:1"]))
        self.assertEqual(result,dict(min=2**63-3,max=2**63-1,sum=2**64-4,**{"quantile:0":2**63-3,"quantile:1":2**63-1}))

    def test_invalid_and_empty_never_fabricate_a_zero_sum(self):
        for x in [np.array([]),np.array([np.nan,np.inf,-np.inf])]:
            result=statistics(x);values=self.values(result)
            self.assertEqual(values["count"],0);self.assertIsNone(values["sum"]);self.assertIsNone(values["mean"])
        self.assertEqual(result["support"]["nan_count"],1)
        zero=self.values(statistics(np.zeros(4)));self.assertEqual(zero["sum"],0);self.assertEqual(zero["stddev"],0)

    def test_hand_weighted_oracle_and_coverage(self):
        x=np.array([-2.,4.,10.,np.nan,100.]);w=np.array([1.,2.,1.,5.,np.nan])
        result=statistics(x,weights=w,metrics=["weighted_mean","weighted_stddev","weighted_sum","sum_weights","weighted_quantile:0.5"])
        values=self.values(result)
        self.assertEqual(values["weighted_mean"],4.);self.assertEqual(values["weighted_sum"],16.);self.assertEqual(values["sum_weights"],4.)
        self.assertAlmostEqual(values["weighted_stddev"],18**.5)
        self.assertEqual(values["weighted_quantile:0.5"],4.)
        self.assertEqual(result["support"]["paired_count"],3);self.assertEqual(result["support"]["invalid_weight_count"],1)

    def test_negative_zero_and_signed_algebraic_weight_policies(self):
        x=np.array([2.,4.]);w=np.array([1.,-1.])
        result=statistics(x,weights=w,metrics=["weighted_mean","algebraic_weighted_sum"])
        self.assertEqual(result["statistics"]["weighted_mean"]["reason"],"negative_weights")
        self.assertEqual(self.values(result)["algebraic_weighted_sum"],-2.)
        result=statistics(x,weights=np.zeros(2),metrics=["weighted_mean","weighted_stddev","sum_weights","weighted_sum"])
        self.assertEqual(result["statistics"]["weighted_mean"]["reason"],"zero_weight")
        self.assertEqual(self.values(result)["sum_weights"],0.)

    def test_quantile_conventions_and_zero_weight_outliers(self):
        x=np.array([4.,0.,10.,2.])
        result=self.values(statistics(x,metrics=["quantile:0.25","quantile:0.5","quantile:0.75"]))
        self.assertEqual(result,{"quantile:0.25":1.5,"quantile:0.5":3.,"quantile:0.75":5.5})
        result=self.values(statistics(x,weights=np.array([1.,0.,0.,3.]),metrics=["weighted_quantile:0","weighted_quantile:0.75","weighted_quantile:1"]))
        self.assertEqual(result,{"weighted_quantile:0":2.,"weighted_quantile:0.75":2.,"weighted_quantile:1":4.})

    def test_phase_category_and_id_arithmetic_is_explicitly_refused(self):
        for semantic in ["phase","categorical","identifier"]:
            with self.assertRaisesRegex(AnalysisError,"not linear"):statistics(np.array([0.,1.]),semantic=semantic)
            self.assertEqual(self.values(statistics(np.array([0.,1.]),semantic=semantic,metrics=["count"]))["count"],2)

    def test_overflow_is_unavailable_but_extrema_remain_available(self):
        result=statistics(np.array([1e308,1e308]));values=self.values(result)
        self.assertEqual(values["max"],1e308);self.assertIsNone(values["sum"])
        self.assertEqual(result["statistics"]["sum"]["reason"],"arithmetic_overflow")

    def test_budget_refusal_and_cancellation_release_allocations(self):
        context=Context(memory_bytes=1048576)
        with self.assertRaises(AnalysisError):statistics(np.ones(20000),metrics=["quantile:0.5"],context=context)
        self.assertEqual(context.used,0)
        calls=[0]
        def cancelled():calls[0]+=1;return calls[0]>3
        context=Context(cancelled=cancelled)
        with self.assertRaisesRegex(AnalysisError,"cancelled"):statistics(np.ones(20000),context=context)
        self.assertEqual(context.used,0)


if __name__=="__main__":unittest.main()
