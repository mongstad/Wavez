"""Blender-only luminous refinement for #162; creates a separate review scene.

The first prototype and unrelated scenes remain intact. Run in Blender 5.2+.
This script neither saves a project nor exports runtime assets.
"""

import math
import random

import bpy
import bmesh
from mathutils import Vector


SCENE_NAME = "Wavez Emblem - Contained Luminous Orb"
if bpy.data.scenes.get(SCENE_NAME):
    raise RuntimeError("Inspect the existing luminous candidate before refining it")
scene = bpy.data.scenes.new(SCENE_NAME)
scene["issue"] = "https://github.com/mongstad/Wavez/issues/162"
scene["review_state"] = "Luminous refinement; awaiting owner visual approval"
scene["reference_sha256"] = "4398a96d6aaf89733417d5c6c204c1d0238751bee07ad5250a63bcce1ef21aa3"
asset = bpy.data.collections.new("Wavez Luminous Asset")
studio = bpy.data.collections.new("Wavez Luminous Review Studio")
scene.collection.children.link(asset)
scene.collection.children.link(studio)
root = bpy.data.objects.new("Wavez_Luminous_Emblem", None)
asset.objects.link(root)


def emission_material(name, strength):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = nodes.get("Principled BSDF")
    colors = nodes.new("ShaderNodeVertexColor")
    colors.layer_name = "Color"
    shader.inputs["Roughness"].default_value = 0.42
    shader.inputs["Metallic"].default_value = 0.0
    shader.inputs["Emission Strength"].default_value = strength
    links.new(colors.outputs["Color"], shader.inputs["Base Color"])
    links.new(colors.outputs["Color"], shader.inputs["Emission Color"])
    return mat


line_mat = emission_material("Wavez Luminous / cobalt violet currents", 3.0)
hero_mat = emission_material("Wavez Luminous / energy crest", 35.0)
net_mat = emission_material("Wavez Luminous / fine energy network", 2.5)
core_mat = bpy.data.materials.new("Wavez Luminous / abyss blue body")
core_mat.use_nodes = True
core_shader = core_mat.node_tree.nodes.get("Principled BSDF")
core_shader.inputs["Base Color"].default_value = (0.0003,0.00065,0.003,1)
core_shader.inputs["Roughness"].default_value = 0.7
core_shader.inputs["Metallic"].default_value = 0.0


def color(x, z, energy=1.0, pearl=0.0):
    # The upper hemisphere stays blue; violet concentrates on the lower right.
    t = max(0.0,min(1.0,(x-0.48*z+0.65)/1.55))
    stops = [(0,(0.005,0.42,1.0)),(0.43,(0.002,0.11,1.0)),
             (0.67,(0.014,0.014,1.0)),(1,(0.115,0.010,1.0))]
    for a,b in zip(stops,stops[1:]):
        if a[0] <= t <= b[0]:
            f=(t-a[0])/(b[0]-a[0])
            rgb=[a[1][j]*(1-f)+b[1][j]*f for j in range(3)]
            return tuple((v*(1-pearl)+pearl)*energy for v in rgb)+(1.0,)


class Strands:
    def __init__(self):
        self.vertices, self.faces, self.colors = [],[],[]

    def add(self, points, width, energy=1.0, pearl=0.0, sides=2, fade=False, depth=False):
        points=[Vector(p) for p in points]
        start=len(self.vertices)
        for i,p in enumerate(points):
            tangent=(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized()
            side=tangent.cross(p.normalized()).normalized()
            normal=side.cross(tangent).normalized()
            endpoint=min(1.0,0.2+12*min(i,len(points)-1-i)/max(1,len(points)-1))
            intensity=energy*(0.12+0.88*math.sin(math.pi*i/(len(points)-1))**0.45) if fade else energy
            if depth:
                intensity *= 0.22+0.78*max(0,-p.normalized().y)**0.7
                intensity *= 0.75+0.25*math.sin(4*p.x+2*p.z)**2
            for j in range(sides):
                angle=2*math.pi*j/sides
                offset=side*(1 if j==0 else -1) if sides==2 else normal*math.cos(angle)+side*math.sin(angle)
                self.vertices.append(tuple(p+width*endpoint*offset))
                self.colors.append(color(p.x,p.z,intensity,pearl))
            if i:
                for j in range(1 if sides==2 else sides):
                    a=start+(i-1)*sides+j
                    b=start+(i-1)*sides+(j+1)%sides
                    c=start+i*sides+(j+1)%sides
                    d=start+i*sides+j
                    self.faces.append((d,c,b,a) if sides==2 else (a,b,c,d))

    def object(self,name,mat):
        mesh=bpy.data.meshes.new(name)
        mesh.from_pydata(self.vertices,[],self.faces)
        mesh.update()
        attribute=mesh.color_attributes.new(name="Color",type="FLOAT_COLOR",domain="POINT")
        for c,rgba in zip(attribute.data,self.colors): c.color=rgba
        for face in mesh.polygons: face.use_smooth=True
        obj=bpy.data.objects.new(name,mesh)
        asset.objects.link(obj)
        obj.parent=root
        mesh.materials.append(mat)
        return obj


TRACE_PIXELS=[(256,595),(300,592),(360,640),(420,693),(460,699),
              (520,670),(580,603),(640,525),(700,471),(760,458),
              (820,495),(880,576),(940,635),(985,634)]
trace=[((x-626)/375,(576-y)/375) for x,y in TRACE_PIXELS]
phase=[(x,math.asin(z/math.sqrt(1-x*x))) for x,z in trace]
phase=[(-1,phase[0][1])]+phase+[(1,phase[-1][1])]


def primary_phase(x):
    for i,(a,b) in enumerate(zip(phase,phase[1:])):
        if a[0]<=x<=b[0]:
            prev,nxt=phase[max(0,i-1)],phase[min(len(phase)-1,i+2)]
            h=b[0]-a[0]
            u=(x-a[0])/h
            m0=(b[1]-prev[1])/(b[0]-prev[0])
            m1=(nxt[1]-a[1])/(nxt[0]-a[0])
            return (2*u**3-3*u*u+1)*a[1]+(u**3-2*u*u+u)*h*m0+(-2*u**3+3*u*u)*b[1]+(u**3-u*u)*h*m1
    return phase[-1][1]


def point(t,phi,radius=1.0,swirl=True):
    x=-math.cos(t)
    bend=(0.85*math.exp(-((x+0.81)/0.16)**2)
          -0.75*math.exp(-((x+0.48)/0.22)**2)
          +0.66*math.exp(-((x+0.02)/0.38)**2))
    twist=0.72*math.sin(phi)*bend if swirl else 0.0
    angle=primary_phase(x)+phi+twist
    return Vector((radius*x,-radius*math.sin(t)*math.cos(angle),radius*math.sin(t)*math.sin(angle)))


# Opaque, near-black physical body: no specular studio patches behind the waves.
verts=[(-0.987,0,0)]
faces=[]
rings,segments=24,48
for i in range(1,rings):
    t=math.pi*i/rings
    for j in range(segments):
        phi=2*math.pi*j/segments
        verts.append((-0.987*math.cos(t),-0.987*math.sin(t)*math.cos(phi),0.987*math.sin(t)*math.sin(phi)))
verts.append((0.987,0,0))
for j in range(segments): faces.append((0,1+j,1+(j+1)%segments))
for i in range(rings-2):
    for j in range(segments):
        faces.append((1+i*segments+j,1+(i+1)*segments+j,1+(i+1)*segments+(j+1)%segments,1+i*segments+(j+1)%segments))
for j in range(segments): faces.append((len(verts)-1,1+(rings-2)*segments+(j+1)%segments,1+(rings-2)*segments+j))
mesh=bpy.data.meshes.new("Wavez Luminous Body")
mesh.from_pydata(verts,[],faces)
mesh.update()
core=bpy.data.objects.new("Wavez_Luminous_Body",mesh)
asset.objects.link(core)
core.parent=root
mesh.materials.append(core_mat)
for face in mesh.polygons: face.use_smooth=True

# Flowing 3D ribbons have extra winding away from the traced hero wave. A
# nonuniform phase distribution creates bright bands and intervening dark gaps.
ribbons=Strands()
for j in range(76):
    phi=2*math.pi*j/76
    phi+=0.055*math.sin(3*phi)
    strength=0.32+0.20*(0.5+0.5*math.cos(3*phi))
    ribbons.add([point(math.pi*i/224,phi) for i in range(225)],0.0015,strength,depth=True)
# An interlaced counter-flow passes above the left trough and under the right
# crest. This produces distinct layered wave families instead of uniform wires.
for j in range(19):
    offset=(j-9)*0.018
    points=[]
    for i in range(225):
        t=math.pi*i/224
        x=-math.cos(t)
        amplitude=-0.06+0.22*math.sin(math.pi*(x+0.4))-0.33*math.exp(-((x-0.6)/0.30)**2)
        phase_angle=math.asin(amplitude)+offset
        points.append((1.002*x,-1.002*math.sin(t)*math.cos(phase_angle),1.002*math.sin(t)*math.sin(phase_angle)))
    ribbons.add(points,0.0017,0.32+0.75*math.exp(-((j-9)/4)**2),depth=True)
ribbons.object("Wavez_Luminous_Swirling_Layers",line_mat)

# A broad, radiant energy band built from nested filaments rather than a single
# wire. Its warm-white core is bracketed by cyan/blue/violet filaments.
crest=Strands()
hero_samples=[point(math.pi*i/224,0,1.009,False) for i in range(225)]
crest.add(hero_samples,0.0052,1.0,0.48,sides=4)
for offset in [-0.125,-0.09,-0.06,-0.038,-0.020,0.020,0.038,0.06,0.09,0.125]:
    energy=0.52*math.exp(-abs(offset)*13)
    crest.add([point(math.pi*i/224,offset,1.007,False) for i in range(225)],
              0.0022,energy,0.025,sides=2)
# The thin central carrier crosses the S wave as in the approved reference.
carrier=[]
for i in range(161):
    x=-1+2*i/160
    z=-0.048*math.sqrt(max(0,1-x*x))
    y=-math.sqrt(max(0,1-x*x-z*z))
    carrier.append((x,-0.011+y,z))
crest.add(carrier,0.0012,0.20,0.05,sides=2)
# Multiple close rims create a luminous shell with restrained depth.
for delta,energy,width in [(0,0.9,0.0038),(-0.018,0.25,0.0018),(0.018,0.22,0.0014)]:
    crest.add([(math.sqrt(1-delta*delta)*math.cos(2*math.pi*i/192),delta,
                math.sqrt(1-delta*delta)*math.sin(2*math.pi*i/192)) for i in range(193)],
              width,energy,0.12,sides=3)
# All energy geometry stays on or immediately around the orb. Any future
# animation must convey flow internally; no side-wave tails or protrusions.
crest_obj=crest.object("Wavez_Luminous_Energy_Band",hero_mat)
crest_obj["hero_centerline"]= [float(c) for p in hero_samples for c in p]

# Soft, colored energy between the filaments gives the central band body.
# Vertex alpha fades it to transparent at the edges; no opaque dark strip.
veil_mat=emission_material("Wavez Luminous / translucent energy mantle",9.0)
veil_mat.surface_render_method='BLENDED'
veil_nodes=veil_mat.node_tree.nodes
veil_mat.node_tree.links.new(next(n for n in veil_nodes if n.bl_idname=='ShaderNodeVertexColor').outputs['Alpha'],veil_nodes.get('Principled BSDF').inputs['Alpha'])
vertices,faces,colors=[],[],[]
across=16
along=224
for i in range(along+1):
    t=0.008+(math.pi-0.016)*i/along
    for j in range(across+1):
        offset=-0.20+0.40*j/across
        p=point(t,offset,1.004,False)
        envelope=math.exp(-(offset/0.08)**2)
        rgb=color(p.x,p.z,0.35,0)
        vertices.append(tuple(p))
        colors.append((*rgb[:3],0.55*envelope))
        if i and j:
            a=(i-1)*(across+1)+j-1
            b=(i-1)*(across+1)+j
            c=i*(across+1)+j
            d=i*(across+1)+j-1
            faces.append((d,c,b,a))
mesh=bpy.data.meshes.new('Wavez Luminous Energy Mantle')
mesh.from_pydata(vertices,[],faces)
mesh.update()
attr=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
for item,rgba in zip(attr.data,colors): item.color=rgba
for polygon in mesh.polygons: polygon.use_smooth=True
veil=bpy.data.objects.new('Wavez_Luminous_Energy_Mantle',mesh)
asset.objects.link(veil)
veil.parent=root
mesh.materials.append(veil_mat)

# Secondary network: small dark-area connections and a few static energy nodes,
# never a particle effect. It gives scale/depth without competing with the crest.
network=Strands()
bm=bmesh.new()
bmesh.ops.create_icosphere(bm,subdivisions=4,radius=0.998)

def network_patch(p):
    return (p.x < -0.14 and p.z > 0.15) or (p.x > -0.12 and p.z < -0.26)

for edge in bm.edges:
    a,b=[v.co.copy() for v in edge.verts]
    if network_patch((a+b)*0.5):
        network.add([a,(a+b).normalized()*0.998,b],0.00065,0.09)
rng=random.Random(162)
nodes=[v.co.copy().normalized()*1.002 for v in bm.verts if network_patch(v.co)]
bm.free()
for p in rng.sample(nodes,min(100,len(nodes))):
    tangent=Vector((0,1,0)).cross(p).normalized()
    up=p.cross(tangent).normalized()
    length=rng.uniform(0.0013,0.0035)
    for axis in [tangent,up]:
        network.add([p-axis*length,p,p+axis*length],0.0008,rng.uniform(0.7,2.2),0.12,sides=2)
network.object("Wavez_Luminous_Depth_Network",net_mat)

camera_data=bpy.data.cameras.new("Wavez Luminous Camera")
camera=bpy.data.objects.new("Wavez Luminous Camera",camera_data)
studio.objects.link(camera)
camera.location=(0,-6,0)
camera.rotation_euler=(-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO'
camera_data.ortho_scale=3.5
scene.camera=camera
world=bpy.data.worlds.new("Wavez Luminous / dark review world")
world.use_nodes=True
world.node_tree.nodes.get('Background').inputs[0].default_value=(0.001,0.0015,0.004,1)
world.node_tree.nodes.get('Background').inputs[1].default_value=0.25
scene.world=world
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x,scene.render.resolution_y=1400,1000
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard'
scene.view_settings.look='None'
scene.view_settings.exposure=-0.85
scene.view_settings.gamma=1
scene.eevee.taa_render_samples=96

# Blender 5.2 compositor sockets are version-queried through the live API.
# Bloom is authoring presentation, not geometry or a claim of GLB/Godot parity.
tree=bpy.data.node_groups.new('Wavez Luminous Refined Compositor','CompositorNodeTree')
glare=tree.nodes.new('CompositorNodeGlare')
glare.name='Wavez Bloom'
glare.inputs['Type'].default_value='Fog Glow'
glare.inputs['Quality'].default_value='High'
glare.inputs['Threshold'].default_value=0.6
glare.inputs['Strength'].default_value=1.8
glare.inputs['Size'].default_value=0.38
glare.inputs['Saturation'].default_value=1.1
layers=tree.nodes.new('CompositorNodeRLayers')
layers.scene=scene
tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
output=tree.nodes.new('NodeGroupOutput')
tree.links.new(layers.outputs['Image'],glare.inputs['Image'])
halo=tree.nodes.new('CompositorNodeGlare')
halo.name='Wavez Atmospheric Halo'
halo.inputs['Type'].default_value='Fog Glow'
halo.inputs['Quality'].default_value='High'
halo.inputs['Threshold'].default_value=1.4
halo.inputs['Strength'].default_value=0.7
halo.inputs['Size'].default_value=0.65
tree.links.new(glare.outputs['Image'],halo.inputs['Image'])
tree.links.new(halo.outputs['Image'],output.inputs['Image'])
scene.compositing_node_group=tree
scene.use_nodes=True
scene['bloom_is_review_presentation']=True

bpy.context.window.scene=scene
if bpy.context.screen:
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.overlay.show_overlays=False
            area.spaces.active.shading.type='MATERIAL'
result={'scene':scene.name,'asset_objects':[o.name for o in asset.objects],
        'saved':False,'exported':False,'bloom':'two-scale Fog Glow','emission_strengths':[3,35,2.5,9]}
