from types import SimpleNamespace
import unittest

from wavez_export.analysis import AnalysisError
from wavez_export.analysis.channel_semantics import declaration,physical_mass_policy,position_unit,quotient_unit


class ChannelSemanticsTests(unittest.TestCase):
    def setUp(self):
        self.source=SimpleNamespace(metadata=dict(time_unit="s"),objects={"p":dict(kind="particles",units="m"),"v":dict(kind="volume",units="kg/m^3")})

    def test_volume_value_units_do_not_become_coordinate_units(self):
        self.assertEqual(position_unit(self.source,"p"),"m")
        self.assertEqual(position_unit(self.source,"v"),"unknown")
        self.assertEqual(declaration(self.source,"p",dict(channel="velocity",component="magnitude"))["units"],"unknown")
        self.assertEqual(quotient_unit("m","s"),"(m)/(s)")

    def test_phase_and_categories_cannot_be_relabeled_for_linear_arithmetic(self):
        for name in ("phase","particle_type","particle_id"):
            with self.assertRaises(AnalysisError):declaration(self.source,"p",dict(channel=name,override=dict(semantic="continuous")))

    def test_plain_mass_name_does_not_establish_physical_mass(self):
        channel=declaration(self.source,"p",dict(channel="mass"))
        with self.assertRaisesRegex(AnalysisError,"tracer density"):physical_mass_policy(channel,"particles","m")
        request=dict(channel="mass",override=dict(units="kg",quantity="actual_particle_mass",physical=dict(mass_unit="kg",scale=1.)))
        channel=declaration(self.source,"p",request)
        self.assertEqual(physical_mass_policy(channel,"particles","m")["units"],"kg")
        self.assertEqual(channel["override"],request["override"])
        self.assertNotIn("channel_metadata",self.source.metadata)

    def test_density_integral_needs_matching_explicit_units_and_scale(self):
        self.source.metadata["channel_metadata"]={"v":{"rho":dict(units="kg/m^3",quantity="mass_density",physical=dict(mass_unit="kg",length_unit="m",scale=1.))}}
        channel=declaration(self.source,"v",dict(channel="rho"))
        self.assertEqual(physical_mass_policy(channel,"volume","m")["scale"],1.)
        for units in ("unknown","mm"):
            with self.assertRaisesRegex(AnalysisError,"no implicit conversion"):physical_mass_policy(channel,"volume",units)
        with self.assertRaises(AnalysisError):physical_mass_policy(channel,"particles","m")

    def test_position_transform_policy_does_not_transform_velocity_basis(self):
        with self.assertRaisesRegex(AnalysisError,"supplied basis"):declaration(self.source,"p",dict(channel="velocity",coordinates="viewer_world"))
        position=declaration(self.source,"p",dict(channel="position",component=0,coordinates="viewer_world"))
        self.assertEqual(position["units"],"m")


if __name__=="__main__":unittest.main()
