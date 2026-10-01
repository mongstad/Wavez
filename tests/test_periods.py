import unittest
import numpy as np

from wavez_export.analysis import AnalysisError,Context
from wavez_export.analysis.periods import analyze,autocorrelation,peaks


class PeriodTests(unittest.TestCase):
    def options(self,method="peak_spacing",**extra):return dict(method=method,detrend="mean",lag_range=[.5,2],min_separation=.3,prominence=.5,uniform=True)|extra

    def test_observed_period_and_acf_match_independent_direct_sums(self):
        t=np.arange(0,8,.01);y=np.sin(2*np.pi*t)
        for method in ("peak_spacing","autocorrelation"):
            result=analyze(t,y,arguments=self.options(method));segment=result["segments"][0]
            self.assertEqual(segment["status"],"exploratory_candidate",segment["reason"])
            self.assertAlmostEqual(segment["candidate"],1,places=12)
            self.assertGreaterEqual(segment["observed_cycles"],3)
            self.assertTrue(np.array_equal(t[segment["peak_indices"]],np.arange(.25,8,1)))
        data=np.array([2.,-1.,3.,0.,-4.,2.,1.])
        actual=autocorrelation(data,Context())
        for lag in range(len(data)):
            a=data[:len(data)-lag];b=data[lag:]
            expected=sum(float(x*y) for x,y in zip(a,b))/(sum(float(x*x) for x in a)*sum(float(x*x) for x in b))**.5
            self.assertAlmostEqual(actual[lag],expected,places=12)

    def test_contour_prominence_and_observed_plateau_policy(self):
        t=np.arange(9,dtype=float);values=np.array([0,2,1,3,3,0,1,0,0],dtype=float)
        indices,prominence=peaks(t,values,.1,0,Context())
        self.assertEqual(indices.tolist(),[1,3,6]);self.assertEqual(prominence.tolist(),[1.,3.,1.])
        indices,_=peaks(t,values,.1,1.5,Context());self.assertEqual(indices.tolist(),[3])

    def test_short_flat_chirped_and_noise_do_not_claim_precise_period(self):
        cases=[(np.arange(0,2,.01),lambda t:np.sin(2*np.pi*t)),
               (np.arange(0,8,.01),lambda t:np.ones(len(t))),
               (np.arange(0,12,.01),lambda t:np.sin(2*np.pi*(t+.08*t*t))),
               (np.arange(0,12,.01),lambda t:np.random.default_rng(782).normal(size=len(t)))]
        for t,fn in cases:
            for method in ("peak_spacing","autocorrelation"):
                result=analyze(t,fn(t),arguments=self.options(method))
                self.assertTrue(all(s["candidate"] is None for s in result["segments"]))

    def test_nonuniform_peak_times_and_explicit_hold_resampling(self):
        t=np.cumsum(np.resize([.012,.008],1000));y=np.sin(2*np.pi*t)
        result=analyze(t,y,arguments=self.options("autocorrelation"))
        self.assertEqual(result["segments"][0]["reason"],"nonuniform_sampling")
        result=analyze(t,y,arguments=self.options("peak_spacing"))
        self.assertIsNotNone(result["segments"][0]["candidate"])
        result=analyze(t,y,arguments=self.options("autocorrelation",uniform=False,hold_cadence=.01))
        segment=result["segments"][0];self.assertIn("resampling",segment)
        self.assertTrue(np.all(segment["resampled_times"]>=t[segment["resampled_rows"]]))
        self.assertLessEqual(segment["resampled_times"][-1],t[-1])
        with self.assertRaisesRegex(AnalysisError,"uniform declaration"):analyze(t,y,arguments=self.options("autocorrelation",uniform=False))

    def test_gaps_missing_segments_and_detrending_remain_explicit(self):
        t=np.arange(0,12,.01);y=np.sin(2*np.pi*t)+.7*t;valid=np.ones(len(t),bool);valid[500:600]=False
        breaks=np.zeros(len(t),bool);breaks[950]=True
        result=analyze(t,y,valid,breaks,arguments=self.options(detrend="linear"))
        self.assertEqual(len(result["segments"]),3);self.assertEqual(result["missing_count"],100)
        self.assertEqual([(s["start_index"],s["end_index"]) for s in result["segments"]],[(0,499),(600,949),(950,1199)])
        self.assertIsNone(result["segments"][-1]["candidate"])
        for segment in result["segments"]:
            if segment["candidate"] is not None:self.assertAlmostEqual(segment["candidate"],1,delta=.02)

    def test_memory_deadline_and_axis_refusals(self):
        t=np.arange(1000,dtype=float)
        with self.assertRaisesRegex(AnalysisError,"memory budget"):analyze(t,np.sin(t),arguments=self.options(),context=Context(memory_bytes=1048576))
        with self.assertRaisesRegex(AnalysisError,"increasing"):analyze(t[::-1],np.sin(t),arguments=self.options())
        with self.assertRaises(AnalysisError):analyze(t,np.sin(t),arguments=self.options(),context=Context(cancelled=lambda:True))


if __name__=="__main__":unittest.main()
