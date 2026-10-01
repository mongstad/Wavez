"""Author the issue #162 visual candidate in Blender, without exporting or saving.

Run inside Blender using its Python console or the MCP execute tool. This creates
a separate scene and refuses to overwrite an existing candidate. The original
scene and its objects remain intact. Geometry is authored here, never at runtime.
"""

import math

import bpy
from mathutils import Vector


SCENE_NAME = "Wavez Emblem - Approval Candidate"
if bpy.data.scenes.get(SCENE_NAME):
    raise RuntimeError("The candidate already exists; inspect it before refining.")

scene = bpy.data.scenes.new(SCENE_NAME)
scene["issue"] = "https://github.com/mongstad/Wavez/issues/162"
scene["review_state"] = "Proposed 3D asset; awaiting owner visual approval"
scene["reference"] = "Wavez_Square_Logo_No_Slogan_No_Border_Dark.png"
scene["reference_sha256"] = "4398a96d6aaf89733417d5c6c204c1d0238751bee07ad5250a63bcce1ef21aa3"
asset = bpy.data.collections.new("Wavez Emblem Asset")
studio = bpy.data.collections.new("Wavez Review Studio (not for export)")
scene.collection.children.link(asset)
scene.collection.children.link(studio)
root = bpy.data.objects.new("Wavez_Emblem", None)
asset.objects.link(root)


def material(name, emission=0.0, base=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value = 0.42
    shader.inputs["Metallic"].default_value = 0.15
    if base:
        shader.inputs["Base Color"].default_value = (*base, 1.0)
    else:
        colors = mat.node_tree.nodes.new("ShaderNodeVertexColor")
        colors.layer_name = "Color"
        mat.node_tree.links.new(colors.outputs["Color"], shader.inputs["Base Color"])
        mat.node_tree.links.new(colors.outputs["Color"], shader.inputs["Emission Color"])
        shader.inputs["Emission Strength"].default_value = emission
    return mat


core_mat = material("Wavez / midnight core", base=(0.0018, 0.0045, 0.014))
line_mat = material("Wavez / cyan violet tracery", emission=1.0)
hero_mat = material("Wavez / pearl wave and rim", emission=1.5)


def palette(x, intensity=1.0, pearl=0.0):
    stops = [(-1.0, (0.018, 0.56, 0.95)), (-0.25, (0.015, 0.30, 0.95)),
             (0.25, (0.105, 0.095, 0.95)), (1.0, (0.49, 0.045, 0.94))]
    x = min(1.0, max(-1.0, x))
    lo, hi = stops[0], stops[-1]
    for a, b in zip(stops, stops[1:]):
        if a[0] <= x <= b[0]:
            lo, hi = a, b
            break
    f = (x - lo[0]) / (hi[0] - lo[0])
    rgb = [lo[1][i] * (1-f) + hi[1][i] * f for i in range(3)]
    return tuple((c * (1-pearl) + pearl) * intensity for c in rgb) + (1.0,)


class TubeMesh:
    def __init__(self):
        self.verts, self.faces, self.colors = [], [], []

    def strand(self, points, width, intensity=1.0, pearl=0.0, sides=2):
        points = [Vector(p) for p in points]
        start = len(self.verts)
        for i, p in enumerate(points):
            tangent = (points[min(i+1, len(points)-1)] - points[max(0, i-1)]).normalized()
            normal = p.normalized()
            side = tangent.cross(normal).normalized()
            normal = side.cross(tangent).normalized()
            # Taper at the common poles to avoid bright knots.
            taper = min(1.0, 0.30 + 8.0 * math.sqrt(max(0.0, 1.0-p.x*p.x)))
            for j in range(sides):
                a = 2 * math.pi * j / sides
                offset = side * (1 if j == 0 else -1) if sides == 2 else normal * math.cos(a) + side * math.sin(a)
                v = p + width * taper * offset
                self.verts.append(tuple(v))
                self.colors.append(palette(p.x-0.65*p.z, intensity, pearl))
            if i:
                for j in range(1 if sides == 2 else sides):
                    a = start + (i-1)*sides + j
                    b = start + (i-1)*sides + (j+1)%sides
                    c = start + i*sides + (j+1)%sides
                    d = start + i*sides + j
                    self.faces.append((d, c, b, a) if sides == 2 else (a, b, c, d))

    def finish(self, name, mat):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.verts, [], self.faces)
        mesh.update()
        colors = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
        for value, rgba in zip(colors.data, self.colors):
            value.color = rgba
        for polygon in mesh.polygons:
            polygon.use_smooth = True
        obj = bpy.data.objects.new(name, mesh)
        asset.objects.link(obj)
        obj.parent = root
        mesh.materials.append(mat)
        return obj


# White-wave centerline landmarks sampled from the approved 1254px reference.
# Pixel origin at top-left; circle center (626,576), radius approximately 375px.
TRACE_PIXELS = [(256,595),(300,592),(360,640),(420,693),(460,699),
                (520,670),(580,603),(640,525),(700,471),(760,458),
                (820,495),(880,576),(940,635),(985,634)]
TRACE = [((x-626)/375, (576-y)/375) for x,y in TRACE_PIXELS]
PHASE = [(x, math.asin(z/math.sqrt(1-x*x))) for x,z in TRACE]
PHASE = [(-1.0,PHASE[0][1])] + PHASE + [(1.0,PHASE[-1][1])]


def wave_phase(x):
    # Cubic Hermite interpolation preserves the sampled asymmetric wave.
    for i in range(len(PHASE)-1):
        a,b = PHASE[i],PHASE[i+1]
        if a[0] <= x <= b[0]:
            prev,nxt = PHASE[max(0,i-1)],PHASE[min(len(PHASE)-1,i+2)]
            h = b[0]-a[0]
            u = (x-a[0])/h
            m0 = (b[1]-prev[1])/(b[0]-prev[0])
            m1 = (nxt[1]-a[1])/(nxt[0]-a[0])
            return (2*u**3-3*u*u+1)*a[1] + (u**3-2*u*u+u)*h*m0 + (-2*u**3+3*u*u)*b[1] + (u**3-u*u)*h*m1
    return PHASE[-1][1]


def sphere_point(t, phi, radius=1.0):
    x = -math.cos(t)
    warp = wave_phase(x)
    a = phi + warp
    return (radius*x, -radius*math.sin(t)*math.cos(a), radius*math.sin(t)*math.sin(a))


# Smooth dark volume gives the linework genuine occlusion and spatial depth.
verts, faces = [(-0.984,0,0)], []
rings, segments = 20, 40
for i in range(1,rings):
    for j in range(segments):
        verts.append(sphere_point(math.pi*i/rings, 2*math.pi*j/segments, 0.984))
verts.append((0.984,0,0))
for j in range(segments):
    faces.append((0,1+j,1+(j+1)%segments))
for i in range(rings-2):
    for j in range(segments):
        faces.append((1+i*segments+j, 1+(i+1)*segments+j,
                      1+(i+1)*segments+(j+1)%segments, 1+i*segments+(j+1)%segments))
for j in range(segments):
    faces.append((len(verts)-1,1+(rings-2)*segments+(j+1)%segments,1+(rings-2)*segments+j))
mesh = bpy.data.meshes.new("Wavez / dark sphere")
mesh.from_pydata(verts, [], faces)
mesh.update()
core = bpy.data.objects.new("Wavez_Core", mesh)
asset.objects.link(core)
core.parent = root
mesh.materials.append(core_mat)
for polygon in mesh.polygons:
    polygon.use_smooth = True

tracery = TubeMesh()
for j in range(48):
    phi = 2*math.pi*j/48
    strength = 0.66 if math.cos(phi) > 0 else 0.32
    tracery.strand([sphere_point(math.pi*i/80, phi) for i in range(81)],
                   0.0018, strength)
# Sparse crossing diagonals echo the reference's fine triangular net. They are
# subordinate to the 48 continuous wave ribbons, particularly at icon scale.
for i in range(1, 13):
    for j in range(24):
        t0,t1 = math.pi*i/14,math.pi*(i+1)/14
        p0 = 2*math.pi*j/24
        p1 = p0 + (1 if (i+j)%2 else -1)*2*math.pi/24
        tracery.strand([sphere_point(t0+(t1-t0)*k/4,p0+(p1-p0)*k/4) for k in range(5)],
                       0.0007, 0.15)
tracery.finish("Wavez_Spherical_Tracery", line_mat)

hero = TubeMesh()
for offset in [-0.072, -0.036, 0.0, 0.036, 0.072]:
    hero.strand([sphere_point(math.pi*i/112, offset, 1.007) for i in range(113)],
                0.008 if offset == 0 else 0.0022,
                0.95 if offset == 0 else 0.70,
                0.78 if offset == 0 else 0.10, sides=3)
hero.strand([(math.cos(2*math.pi*i/160), 0, math.sin(2*math.pi*i/160)) for i in range(161)],
            0.005, 0.90, 0.33, sides=3)
# Short, tapering wave shoulders retain the reference's horizontal silhouette.
for sign in [-1,1]:
    for strand in range(5):
        points=[]
        for i in range(41):
            u=i/40
            x=sign*(1.0+0.64*u)
            z=(0.13-0.048*strand)*math.sin(math.pi*u)**2
            points.append((x,-0.002*strand,z))
        hero.strand(points,0.0032 if strand==0 else 0.0014,
                    0.55 if strand==0 else 0.24,0.30 if strand==0 else 0,sides=3)
hero.finish("Wavez_Hero_Wave_And_Rim", hero_mat)

camera_data = bpy.data.cameras.new("Wavez Review Camera")
camera = bpy.data.objects.new("Wavez Review Camera", camera_data)
studio.objects.link(camera)
camera.location = (0, -6, 0)
camera.rotation_euler = (Vector((0,0,0)) - camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 3.60
scene.camera = camera

for name, location, energy, color, size in [
    ("Wavez Key", (-3,-4,4), 180, (0.25,0.65,1.0), 4),
    ("Wavez Violet Rim", (3,0,2), 120, (0.5,0.2,1.0), 3),
]:
    data = bpy.data.lights.new(name, 'AREA')
    data.energy, data.color, data.shape, data.size = energy, color, 'DISK', size
    light = bpy.data.objects.new(name, data)
    studio.objects.link(light)
    light.location = location
    light.rotation_euler = (-light.location).to_track_quat('-Z','Y').to_euler()

world = bpy.data.worlds.new("Wavez Review Dark World")
world.use_nodes = True
world.node_tree.nodes.get("Background").inputs[0].default_value = (0.006,0.008,0.017,1)
world.node_tree.nodes.get("Background").inputs[1].default_value = 0.3
scene.world = world
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = 1260,840
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.film_transparent = False
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1

bpy.context.window.scene = scene
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        area.spaces.active.region_3d.view_perspective = 'CAMERA'
        area.spaces.active.overlay.show_overlays = False
        area.spaces.active.shading.type = 'MATERIAL'

result = {'scene': scene.name, 'asset_objects': [o.name for o in asset.objects],
          'mesh_count': 3, 'materials': [core_mat.name, line_mat.name, hero_mat.name],
          'original_scene_preserved': bpy.data.scenes.get('Scene') is not None,
          'saved': False, 'exported': False}
