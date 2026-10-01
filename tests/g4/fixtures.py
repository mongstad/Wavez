from pathlib import Path
import numpy as np
from wavez_export import SceneCapture

HIGH_ID = 9007199254740993


def scene(path, compression="none"):
    """F01/F05/F06: independent clocks, exact IDs and an affine f8 field."""
    objects = [dict(id="p", kind="particles", units="m", identity="persistent_i8"),
               dict(id="field", kind="volume", units="kg/m^3",
                    data_to_world=[2,0,0,10, 0,1,0,-3, 0,0,1,5]),
               dict(id="mesh", kind="mesh", units="m", identity="stable_topology")]
    z, y, x = np.indices((2, 3, 4))
    field = (x*.5+2*y*2+3*z*3+7).astype("f8")
    ids_at = {0: [7, HIGH_ID], .5: [HIGH_ID, 7, 2**63-1],
              1.5: [HIGH_ID, 2**63-1], 3: [2**63-1]}
    with SceneCapture(path, objects=objects, compression=compression,
                      metadata={"time_unit":"s", "position_unit":"m"}) as writer:
        for time in [0, .5, 1, 1.5, 2, 3, 4, 6]:
            if time in ids_at:
                ids = np.array(ids_at[time], dtype="i8")
                base = np.array([int(v)%101 for v in ids], dtype="f8")
                positions = np.column_stack((base+2*time, base*0+time, base*0))
                writer.add_particles("p", time, positions, ids=ids,
                                     value=base+time+1e-12,
                                     velocity=np.tile([2.,1.,0.], (len(ids),1)),
                                     particle_type=(ids%3).astype("u4"))
            if time in (0, 1, 4):
                writer.add_volume("field", time, {"value":field+time, "constant":np.full(field.shape,2.,dtype="f8")},
                                  origin=[0,0,0], spacing=[.5,2,3], centering="node")
            if time in (0, 2, 4, 6):
                # A→B→A tests non-resurrection of a face epoch.
                triangle = [[0,2,1]] if time == 2 else [[0,1,2]]
                writer.add_mesh("mesh", time, np.array([[0,0,time],[1,0,time],[0,1,time]],dtype="f8"),
                                triangle, vertex_channels={"vertex_id":np.array([7,HIGH_ID,2**63-1],dtype="i8"),
                                                           "value":np.array([2.,4.,8.])},
                                face_channels={"face_value":np.array([11.])})
    return Path(path)


def traveling_pulse(path, *, time_scale=1, time_offset=0):
    """F08 direct field pulse and explicitly sampled tracers on separate clocks."""
    grid_times=[0,.25,1,2.5,4];particle_times=[0,.5,1.5,3]
    objects=[dict(id='p',kind='particles',identity='persistent_i8',units='m'),dict(id='field',kind='volume',units='K')]
    with SceneCapture(path,objects=objects,metadata=dict(time_unit='s',position_unit='m',channel_metadata=dict(field=dict(value=dict(units='K'))))) as writer:
        for time in sorted(set(grid_times+particle_times)):
            if time in particle_times:
                x=np.linspace(-.5,1.5,41)+time;positions=np.column_stack((x,np.zeros(41),np.zeros(41)))
                writer.add_particles('p',time*time_scale+time_offset,positions,ids=np.arange(41,dtype='i8'),value=np.exp(-((x-time)/.25)**2),weight=np.full(41,2.))
            if time in grid_times:
                x=np.arange(21)*.25;profile=np.exp(-((x-time)/.25)**2)
                writer.add_volume('field',time*time_scale+time_offset,dict(value=np.tile(profile,(2,2,1))),origin=[0,0,0],spacing=[.25,1,1],centering='node')
    return Path(path)
