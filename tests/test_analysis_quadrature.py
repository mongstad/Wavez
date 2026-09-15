import unittest
from types import SimpleNamespace
import numpy as np

from simscope_export.analysis import Context,AnalysisError
from simscope_export.analysis.quadrature import volume_integral,face_areas
from simscope_export.analysis.selectors import region


class QuadratureTests(unittest.TestCase):
    def setUp(self):
        self.geometry=dict(shape=[2,3,4],origin=[0.,0.,0.],spacing=[.5,2.,3.],centering="node")
        self.obj=dict(data_to_world=[2.,0,0,10,0,1,0,-3,0,0,1,5])
        self.all=region(dict(shape="box",lower=[-100,-100,-100],upper=[100,100,100]))

    def integral(self,values=None,**kw):
        return volume_integral(np.full((2,3,4),2.) if values is None else values,self.geometry,self.obj,self.all,**kw)

    def test_node_and_cell_hand_volumes(self):
        result=self.integral();self.assertEqual(result["value"],72.);self.assertEqual(result["support"]["effective_volume"],36.)
        self.assertEqual(result["support"]["selected_cells"],6)
        self.geometry["centering"]="cell"
        result=self.integral();self.assertEqual(result["value"],288.);self.assertEqual(result["support"]["selected_cells"],24)

    def test_center_inclusion_and_affine_determinant_once(self):
        self.obj["data_to_world"]=[-2.,.5,0,10,0,1,0,-3,0,0,1,5]
        # Local first x hexahedron column, two y cells; each world volume = 6.
        box=region(dict(shape="box",lower=[0.,0.,0.],upper=[.5,4.,3.]))
        result=volume_integral(np.full((2,3,4),2.),self.geometry,self.obj,box,space="data_local")
        self.assertEqual(result["value"],24.);self.assertEqual(result["support"]["effective_volume"],12.)

    def test_invalid_corner_makes_full_integral_unavailable_and_subtotal_explicit(self):
        values=np.full((2,3,4),2.);values[0,0,0]=np.nan
        result=self.integral(values,finite_subtotal=True)
        self.assertIsNone(result["value"]);self.assertEqual(result["reason"],"nonfinite_support")
        self.assertEqual(result["support"]["invalid_cells"],1)
        self.assertEqual(result["finite_subtotal"]["value"],60.)
        self.assertEqual(result["finite_subtotal"]["status"],"incomplete_support")

    def test_linear_field_integral_matches_independent_box_average(self):
        z,y,x=np.indices((2,3,4));values=x*.5+2*y*2+3*z*3+7
        # Mean over local box [0,1.5]x[0,4]x[0,3] is .75+4+4.5+7.
        self.assertEqual(self.integral(values.astype("f8"))["value"],16.25*36)

    def test_empty_and_overflow_refusal_with_source_preservation(self):
        self.geometry["shape"]=[1,3,4]
        result=self.integral(np.ones((1,3,4)));self.assertIsNone(result["value"]);self.assertEqual(result["reason"],"empty_support")
        self.geometry["shape"]=[2,3,4]
        values=np.full((2,3,4),1e308);before=values.tobytes()
        with self.assertRaises(AnalysisError):self.integral(values)
        self.assertEqual(values.tobytes(),before)

    def test_triangle_area_reflection_shear_and_degenerate_support(self):
        sample=SimpleNamespace(arrays=dict(position=np.array([[0,0,0],[1,0,0],[0,1,0]],dtype="f8"),triangles=np.array([[0,1,2],[0,0,1]],dtype="u4")))
        obj=dict(data_to_world=[-2.,.5,0,10,0,3,0,-3,0,0,1,5]);context=Context()
        np.testing.assert_array_equal(face_areas(obj,sample,np.array([0,1]),context),[3.,0.])
        self.assertEqual(context.used,0)

    def test_compensation_survives_quadrature_chunk_boundary(self):
        geometry=dict(shape=[1,1,4097],origin=[0.,0.,0.],spacing=[1.,1.,1.],centering="cell")
        obj=dict(data_to_world=[1.,0,0,0,0,1,0,0,0,0,1,0])
        values=np.zeros((1,1,4097));values[0,0,0]=1e16;values[0,0,1]=1.;values[0,0,-1]=-1e16
        whole=region(dict(shape="box",lower=[-1,-1,-1],upper=[5000,1,1]))
        self.assertEqual(volume_integral(values,geometry,obj,whole)["value"],1.)


if __name__=="__main__":unittest.main()
