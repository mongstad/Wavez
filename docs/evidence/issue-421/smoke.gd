extends SceneTree
var viewer
func _initialize():
 call_deferred("run")
func run():
 viewer=load("res://main.gd").new()
 root.add_child(viewer)
 viewer.scene_prebuffer_enabled=false
 viewer._open_capture("/tmp/wavez-421/shell/scene.wvz")
 viewer.playing=false
 for i in 20: await process_frame
 var popup=viewer.shell.menus.Tools.get_popup()
 var labels=[]
 for i in popup.item_count:
  labels.append(popup.get_item_text(i))
 assert(not labels.has("Spatial spectrum"))
 assert(not labels.has("Spectral band map"))
 var img=viewer._save_image_viewport()
 assert(img!=null and img.get_width()>0)
 assert(img.save_png("/tmp/wavez-421/image-export.png")==OK)
 var f=FileAccess.open("/tmp/wavez-421/smoke.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"menus":labels,"spectral_controls_absent":true,"image_export":true,"image_width":img.get_width(),"image_height":img.get_height()}));f.close()
 viewer.queue_free()
 for i in 3: await process_frame
 quit(0)
