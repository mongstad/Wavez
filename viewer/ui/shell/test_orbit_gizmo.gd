extends SceneTree
## Render actual scientific-world geometry and the annotation in separate passes,
## comparing their pixel masks rather than two calls to unproject_position.
const GridView = preload("res://layers/grid_view.gd")
const Viewer = preload("res://main.gd")
var checks := 0
var failures: Array[String] = []
var output := ""
var pixels: Array = []
var diagnostics: Array = []
var native := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); push_error(label)
func settle() -> void:
 for i in 3: await process_frame
 if native: await create_timer(.04).timeout
func key(code: Key, pressed: bool) -> void:
 var e := InputEventKey.new(); e.physical_keycode = code; e.keycode = code; e.pressed = pressed
 Input.parse_input_event(e); Input.flush_buffered_events()
func vector_array(value: Vector3) -> Array:
 return [value.x,value.y,value.z]
func pose_array(value: Transform3D) -> Array:
 return [vector_array(value.basis.x),vector_array(value.basis.y),vector_array(value.basis.z),vector_array(value.origin)]
func snapshot(v) -> Dictionary:
 return {"pose":v.camera.transform,"target":v.camera_target,"radius":v.camera_distance,"yaw":v.yaw,"pitch":v.pitch,"orbit":v.orbit_enabled,"free":v.free_camera,"basis":v.camera_orbit_basis,"active":v.camera_orbit_basis_active,"basis_yaw":v.camera_orbit_basis_yaw,"basis_pitch":v.camera_orbit_basis_pitch}
func mask(image: Image, alpha: bool) -> Dictionary:
 var low := Vector2i(image.get_width(),image.get_height()); var high := Vector2i(-1,-1); var count := 0
 for y in image.get_height():
  for x in image.get_width():
   var c := image.get_pixel(x,y)
   if (c.a > .9 if alpha else c.r > .8 and c.b > .8 and c.g < .35):
    low = low.min(Vector2i(x,y)); high = high.max(Vector2i(x,y)); count += 1
 return {"low":low,"high":high,"count":count}
func rendered_landmark(v, e, label: String) -> void:
 if not native: return
 var guide = e.guide
 await settle()
 var overlay: Image = guide.annotation.get_texture().get_image()
 var expected := mask(overlay,true)
 # Same physical unit sphere in the scientific World3D, including the viewer
 # root transform. Its shader isolates visible pixels from scientific colors.
 var marker := MeshInstance3D.new(); marker.mesh = guide.sphere.mesh
 var shader := Shader.new(); shader.code = "shader_type spatial; render_mode unshaded, depth_test_disabled, cull_disabled, fog_disabled; void fragment(){ALBEDO=vec3(1.,0.,1.);ALPHA=1.;}"
 var material := ShaderMaterial.new(); material.shader=shader; material.render_priority=127;marker.material_override=material
 v.add_child(marker); marker.global_transform = guide.sphere.global_transform
 # Isolate the reference landmark from scientific compositing/postprocessing
 # colors, while keeping it in the real scientific World3D and camera. Restore
 # every layer for the ordinary screenshot and navigation sequence below.
 var fields: Array = []
 if v.current_instance.visible: fields.append(v.current_instance);v.current_instance.hide()
 for view in v.scene_layers.views.values():
  if view.visible: fields.append(view);view.hide()
  if view is GridView and view.quad.visible: fields.append(view.quad);view.quad.hide()
 var glow:bool=v.environment.glow_enabled;v.environment.glow_enabled=false
 guide.hide(); e.panel.hide(); await settle()
 root.get_texture().get_image().save_png(output.path_join(label.replace(" ","-")+"-landmark.png"))
 var actual := mask(root.get_texture().get_image(),false)
 check(expected.count > 15 and actual.count > 15,label+" visible sphere/landmark pixels")
 var error := maxi((actual.low-expected.low).abs().x,(actual.low-expected.low).abs().y)
 error = maxi(error,maxi((actual.high-expected.high).abs().x,(actual.high-expected.high).abs().y))
 check(error <= 2,label+" actual rendered landmark/gizmo bounds agree within 2 pixels")
 pixels.append({"label":label,"annotation_low":str(expected.low),"annotation_high":str(expected.high),"world_low":str(actual.low),"world_high":str(actual.high),"edge_error_px":error,"center":vector_array(e.center),"radius":e.radius,"camera":pose_array(v.camera.global_transform),"annotation_camera":pose_array(guide.annotation_camera.transform)})
 marker.queue_free();v.environment.glow_enabled=glow
 for field in fields: field.show()
 guide.show(); e.panel.show(); await settle()
 if label in ["mixed initial","small initial","large initial","mixed moved","mixed orthographic"]: root.get_texture().get_image().save_png(output.path_join(label.replace(" ","-")+".png"))
func continuous_pixels(v, e) -> void:
 if not native:return
 var g=e.guide
 var marker:=MeshInstance3D.new();marker.mesh=g.sphere.mesh
 var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded,depth_test_disabled,cull_disabled,fog_disabled;void fragment(){ALBEDO=vec3(1.,0.,1.);ALPHA=1.;}"
 var mat:=ShaderMaterial.new();mat.shader=shader;mat.render_priority=127;marker.material_override=mat
 v.add_child(marker);marker.global_transform=g.sphere.global_transform
 var hidden:Array=[]
 if v.current_instance.visible:hidden.append(v.current_instance);v.current_instance.hide()
 for view in v.scene_layers.views.values():
  if view.visible:hidden.append(view);view.hide()
  if view is GridView and view.quad.visible:hidden.append(view.quad);view.quad.hide()
 var glow:bool=v.environment.glow_enabled;v.environment.glow_enabled=false
 g.modulate.a=0.;e.panel.hide();v.set_process(true)
 # Each pair is sampled from one completed live frame while a physical-style
 # movement key is still held. No manual camera or guide update, force_draw,
 # or stopped-frame prediction is involved.
 for code in [KEY_A,KEY_D,KEY_W,KEY_S,KEY_Q,KEY_E]:
  key(code,true)
  for i in 2:
   await RenderingServer.frame_post_draw
   var annotation:=mask(g.annotation.get_texture().get_image(),true)
   var world:=mask(root.get_texture().get_image(),false)
   var error:=maxi((annotation.low-world.low).abs().x,(annotation.low-world.low).abs().y)
   error=maxi(error,maxi((annotation.high-world.high).abs().x,(annotation.high-world.high).abs().y))
   check(annotation.count>15 and world.count>15 and error<=2,"continuous actual pixels "+OS.get_keycode_string(code))
   pixels.append({"label":"continuous "+OS.get_keycode_string(code),"edge_error_px":error,"camera":pose_array(v.camera.global_transform),"annotation_camera":pose_array(g.annotation_camera.transform)})
  key(code,false)
 v.set_process(false);marker.queue_free();g.modulate.a=1.;e.panel.show();v.environment.glow_enabled=glow
 for item in hidden:item.show()
 await settle()

func scene(v, kind: String) -> void:
 v._open_capture(output.path_join(kind+".wvz")); v.playing=false; v._reset_camera()
 # Accepted main's extreme near/far ratio produces a degenerate float32
 # frustum at this scale. Keep this explicit test projection separate from
 # the unchanged production clipping policy; baseline failure is recorded.
 if kind == "large": v.camera.near=maxf(v.camera.near,v.camera_distance*.00001)
 await settle()
 check(v._shell_open_error.is_empty(),kind+" opened WVZ1")
 var scientific := {}
 for node in v.scene_layers.views.values(): scientific[node] = node.global_transform
 var prior := snapshot(v)
 v.shell.edit_orbit_center(); var e=v.shell.orbit_editor; await settle()
 var bounds: AABB=e.scene_bounds()
 var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output.path_join(kind+"-bounds.json")))
 var low:=Vector3(expected.low[0],expected.low[1],expected.low[2]);var high:=Vector3(expected.high[0],expected.high[1],expected.high[2])
 check(bounds.position.distance_to(low)<maxf(.00001,bounds.size.length()*.000001) and bounds.end.distance_to(high)<maxf(.00001,bounds.size.length()*.000001),kind+" bounds match independently transformed fixture geometry")
 check(e.radius*2 <= bounds.size.length()*.08001,kind+" default diameter <=8% world diagonal")
 check(e.guide.sphere.scale == Vector3.ONE*e.radius and e.guide.sphere.mesh.radius == 1.,kind+" physical sphere exactly one world radius")
 check(e.center.distance_to(v.camera.global_position-v.camera.global_basis.z*e.depth) < maxf(.00001,e.depth*.000001),kind+" predictable initial depth")
 diagnostics.append({"scene":kind,"bounds":{"min":vector_array(bounds.position),"max":vector_array(bounds.end)},"radius":e.radius,"depth":e.depth,"sphere_diameter_ratio":2*e.radius/bounds.size.length(),"center":vector_array(e.center)})
 await rendered_landmark(v,e,kind+" initial")
 var center:Vector3=e.center;var radius:float=e.radius;var depth:float=e.depth
 e.place_button.grab_focus(); e.place_button.pressed.emit()
 check(root.gui_get_focus_owner()==null,kind+" Place ahead releases focus")
 var pose:Transform3D=v.camera.transform
 key(KEY_W,true);v.scene_layers.tick(.03);key(KEY_W,false)
 check(v.camera.position!=pose.origin,kind+" Place ahead then W immediately moves")
 for code in [KEY_A,KEY_S,KEY_D,KEY_Q,KEY_E]:
  key(code,true);v.scene_layers.tick(.03);key(code,false)
  check(e.center==center and e.radius==radius and e.depth==depth,kind+" navigation preserves draft "+OS.get_keycode_string(code))
 # Concurrent RMB/W uses the production input path.
 var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_RIGHT;press.pressed=true;press.position=Vector2(400,250);v._unhandled_input(press)
 var motion:=InputEventMouseMotion.new();motion.position=Vector2(416,242);v._input(motion)
 key(KEY_W,true);v.scene_layers.tick(.02);key(KEY_W,false);press.pressed=false;v._input(press)
 for action in ["orbit_camera_left","orbit_camera_right"]:
  var held:=InputEventKey.new();held.pressed=true;held.physical_keycode=KEY_R if action.ends_with("left") else KEY_T
  var saved_binding:int=v.shell.shortcuts.active[action];v.shell.shortcuts.active[action]=v.shell.shortcuts.binding(held)
  v._start_manual_orbit(action,held);v._update_manual_orbit(.03);held.pressed=false;v._release_manual_orbit_key(held)
  v.shell.shortcuts.active[action]=saved_binding
 for invert in [false,true]:
  var saved:bool=v.shell.shortcuts.invert_y_axis;v.shell.shortcuts.invert_y_axis=invert
  v._orbit_camera_by_drag(Vector2(5,-3),.006);v.shell.shortcuts.invert_y_axis=saved
 var wheel:=InputEventMouseButton.new();wheel.factor=1.;v._zoom_camera(wheel,true)
 v.free_camera_speed_scale*=2;v.free_camera_speed_scale/=2
 check(e.center==center and e.radius==radius and e.depth==depth,kind+" RMB/orbit/tumble/zoom/speed preserve draft")
 await rendered_landmark(v,e,kind+" moved")
 v.camera.transform=pose
 await rendered_landmark(v,e,kind+" returned")
 if kind == "mixed":
  v.set_process(true)
  for code in [KEY_A,KEY_D,KEY_W,KEY_S,KEY_Q,KEY_E]:
   key(code,true);await settle();key(code,false)
   check(e.center==center and e.radius==radius,"live processing preserves draft "+OS.get_keycode_string(code))
  v.set_process(false)
  await rendered_landmark(v,e,"mixed live")
 v.camera.transform=pose
 # Independent inputs must never mutate the other dimensions.
 e.depth_input.text=str(depth*1.1);e.read_fields()
 check(e.center==center and e.radius==radius,kind+" depth edit only sets future placement depth")
 e.radius_input.text=str(radius*1.1);e.read_fields()
 check(e.center==center and is_equal_approx(e.depth,depth*1.1),kind+" radius edit independent")
 for axis in 3:
  var other:Vector3=e.center;e.coordinates[axis].text=str(other[axis]+radius*.1);e.read_fields()
  check(e.center[axis]!=other[axis],kind+" numeric coordinate edits axis "+str(axis))
 e.center=center;e.radius=radius;e.depth=depth;e.write_fields();e.refresh()
 v.camera.position += e.handle_basis.x*depth*.7
 v.camera.look_at(e.center,e.handle_basis.y)
 e.refresh()
 for axis in 3:
  var h:Dictionary=e.guide.handle(axis)
  check(not h.is_empty(),kind+" all three handles exposed from oblique view")
  if h.is_empty(): continue
  var start:Vector3=e.center
  press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=h.end;e._input(press)
  motion=InputEventMouseMotion.new();motion.position=h.end+h.direction*15;e._input(motion)
  press.pressed=false;e._input(press)
  check(e.center.distance_to(start+e.handle_basis[axis]*15*h.units)<maxf(.00001,radius*.0001),kind+" handle follows captured view axis "+str(axis))
  e.center=center;e.write_fields();e.refresh()
 e.dismiss();check(snapshot(v)==prior,kind+" Cancel restores entire pose and modes")
 v.shell.edit_orbit_center();e.center=center+v.camera.basis.x*radius*2.;center=e.center;e.radius=radius;e.write_fields()
 var apply_origin:Vector3=v.camera.global_position
 var orbit_distance:float=apply_origin.distance_to(center)
 e.commit()
 check(v.camera.global_position==apply_origin,kind+" Apply never teleports observer")
 check(is_equal_approx(v.camera_distance,orbit_distance) and not is_equal_approx(v.camera_distance,e.radius),kind+" observer distance independent of gizmo radius")
 check(v.camera.basis.z.dot((apply_origin-center).normalized())>.99999,kind+" Apply faces off-axis chosen center")
 var applied:Transform3D=v.camera.transform;var up:Vector3=applied.basis.y
 diagnostics.append({"scene":kind,"apply_origin":vector_array(apply_origin),"chosen_center":vector_array(center),"observer_orbit_distance":orbit_distance,"gizmo_radius":radius,"apply_position_delta":v.camera.global_position.distance_to(apply_origin)})
 for i in 120:
  v._advance_auto_orbit(TAU/(v.orbit_speed*120.))
  if i==0:check(v.camera.position.distance_to(applied.origin)>orbit_distance*.01,kind+" observer immediately travels instead of turning in place")
  var radial:Vector3=v.camera.position-center
  check(absf(radial.length()-orbit_distance)<maxf(.00001,orbit_distance*.00001),kind+" true orbit radius")
  check(absf(radial.dot(up))<maxf(.00001,orbit_distance*.00001),kind+" true orbit equator")
  check(radial.normalized().dot(v.camera.basis.z)>.99999,kind+" target in sight")
  if native and kind=="mixed" and i in [29,59,89,119]:
   await settle()
   root.get_texture().get_image().save_png(output.path_join("observer-orbit-%03d.png"%((i+1)*3)))
 check(v.camera.position.distance_to(applied.origin)<maxf(.00001,orbit_distance*.00001),kind+" full revolution returns pose")
 for i in 3:
  var before:=snapshot(v);v.shell.edit_orbit_center()
  check(e.radius==radius,kind+" reopening retains separate gizmo size")
  e.commit()
  check(snapshot(v)==before,kind+" repeated unchanged Apply exact")
  before=snapshot(v);v.shell.edit_orbit_center();e.dismiss();check(snapshot(v)==before,kind+" repeated Cancel exact")
 v._seek_time(0.0)
 var source_time:float=v.committed_sample.get("requested_time",0.0)
 v.playing=true;v.scene_layers.tick(.25);v.playing=false
 check(v.committed_sample.get("requested_time",0.0)>source_time and v.camera_target==center and v.camera_distance==orbit_distance,kind+" source time advances independently of chosen orbit")
 v.orbit_enabled=false
 for node in scientific:check(node.global_transform==scientific[node],kind+" scientific transform unchanged")
 if kind=="mixed":
  v._reset_camera();v.shell.edit_orbit_center();await settle()
  e.radius=1.;e.write_fields();e.refresh();var old_depth:float=e.depth;e.place_ahead()
  check(e.radius==1. and e.depth==old_depth,"radius=1 Place ahead retains scale/depth")
  await rendered_landmark(v,e,"mixed radius-one")
  await continuous_pixels(v,e)
  v.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;v.camera.size=20;await settle();await rendered_landmark(v,e,"mixed orthographic")
  v.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
  # Deliberate camera-inside navigation has an explicit cue, never fake scale.
  var outside:Transform3D=v.camera.transform
  v.camera.global_position=e.center;await settle()
  check(not e.guide.sphere.visible and e.notice.text.contains("inside"),"camera-inside cue preserves real radius")
  v.camera.transform=outside;await settle()
  # Isolate the PNG contract at an identical camera/scientific state.
  if native:
   var without:Image=v._save_image_viewport()
   e.radius*=1.3;e.write_fields();e.refresh();await settle()
   var with_draft:Image=v._save_image_viewport()
   check(without.get_data()==with_draft.get_data(),"viewport PNG excludes pending gizmo and panel pixels")
  e.dismiss();v._toggle_fullscreen();await settle();v.shell.edit_orbit_center();await settle()
  e.place_button.pressed.emit();key(KEY_W,true);v.scene_layers.tick(.02);key(KEY_W,false)
  check(e.visible and root.gui_get_focus_owner()==null,"fullscreen Place ahead/W")
  key(KEY_ESCAPE,true);key(KEY_ESCAPE,false)
  check(not e.visible and v.shell.immersive,"Escape cancels editor before fullscreen recovery")
  v.shell.exit_immersive();await settle()
func directional_apply(v) -> void:
 # Include look-at singularities and a target behind the starting view.
 for direction in [Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3(1,2,-3).normalized()]:
  v._reset_camera();v.shell.edit_orbit_center();var e=v.shell.orbit_editor
  var position:Vector3=v.camera.position
  e.center=position+v.camera.basis*direction*7.5;e.radius=.25;e.write_fields();e.commit()
  check(v.camera.position==position and v.camera.basis.is_finite(),"directional Apply preserves observer position")
  check(v.camera.basis.z.dot((position-e.center).normalized())>.99999,"directional Apply faces target without singularity")
  var before:=snapshot(v);v.shell.edit_orbit_center();e.radius=2.5;e.write_fields();e.commit()
  check(snapshot(v)==before,"changing only gizmo size does not alter observer orbit")
  v.shell.edit_orbit_center();e.dismiss();check(snapshot(v)==before,"Cancel restores directional observer orbit")
 v.orbit_enabled=false

func observer_zoom(v) -> void:
 v._reset_camera();v.shell.edit_orbit_center();var e=v.shell.orbit_editor
 # Deliberately closer than the whole-scene framing radius, with a tilted plane.
 e.center=v.camera.position+v.camera.basis*Vector3(1,2,-3).normalized()*v.camera.near*8.
 e.write_fields();e.commit()
 var target:Vector3=v.camera_target;var axis:Vector3=v.camera.basis.y
 var initial:float=v.camera_distance
 var wheel:=InputEventMouseButton.new();wheel.pressed=true;wheel.factor=1.
 for cycle in 3:
  wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;v._unhandled_input(wheel)
  check(v.camera_distance>initial,"observer wheel out increases radius")
  v._advance_auto_orbit(.1)
  wheel.button_index=MOUSE_BUTTON_WHEEL_UP;v._unhandled_input(wheel)
  check(is_equal_approx(v.camera_distance,initial),"observer wheel in returns below scene framing limit")
  v._advance_auto_orbit(.1)
  check(v.orbit_enabled and not e.applied_orbit.is_empty(),"wheel retains applied observer orbit")
  check(v.camera_target==target and v.camera.basis.y.dot(axis)>.99999,"wheel retains chosen target and tilted plane")
  check(v.camera.basis.z.dot((v.camera.position-target).normalized())>.99999,"zoomed orbit still faces center")
 wheel.factor=.25;wheel.button_index=MOUSE_BUTTON_WHEEL_UP;v._unhandled_input(wheel)
 check(is_equal_approx(v.camera_distance,initial*pow(.9,.25)),"observer fractional wheel scale")
 wheel.factor=1.
 for i in 40:v._unhandled_input(wheel);v._advance_auto_orbit(.01)
 check(is_equal_approx(v.camera_distance,v.camera.near*2.),"observer zoom stops at near-plane clearance")
 wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;v._unhandled_input(wheel)
 check(v.camera_distance>v.camera.near*2.,"observer zoom reverses at near limit")
 var marker:float=e.radius
 v.shell.edit_orbit_center();check(e.radius==marker,"zoom retains separate marker size on reopen");e.dismiss()
 v._take_manual_camera_control();v._steer_camera(Vector2(5,3))
 v._advance_auto_orbit(.01)
 check(e.applied_orbit.is_empty(),"manual steering still invalidates observer plane")
 v.orbit_enabled=false

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--gizmo-output="):output=arg.trim_prefix("--gizmo-output=")
 if output.is_empty():quit(1);return
 native=DisplayServer.get_name()!="headless"
 create_timer(210).timeout.connect(func():push_error("Gizmo timeout");quit(1))
 var v=Viewer.new();root.add_child(v);v.set_process(false)
 v.shell.edit_orbit_center()
 check(v.shell.orbit_editor.radius>0 and v.shell.orbit_editor.depth>0,"empty-scene finite positive fallback")
 v.shell.orbit_editor.center=v.camera.global_position;v.shell.orbit_editor.write_fields()
 var coincident_pose:Transform3D=v.camera.transform
 v.shell.orbit_editor.commit()
 check(v.shell.orbit_editor.visible and v.camera.transform==coincident_pose,"coincident center keeps editor open without teleport")
 v.shell.orbit_editor.dismiss()
 directional_apply(v)
 observer_zoom(v)
 for kind in ["particles","mesh","volume","mixed","small","large","lobes"]:await scene(v,kind)
 var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"pixels":pixels,"diagnostics":diagnostics},"\t"));f.close()
 v.queue_free();await settle();print("GIZMO: %d checks / %d failures"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
