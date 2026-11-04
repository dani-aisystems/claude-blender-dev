extends SceneTree
## Debug: print bound hooks of the watch room (focus points, light count, parts).

func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	await process_frame
	var g = load("res://scripts/fp/game_fp.gd").new()
	root.add_child(g)
	g.start(1, "expert", false)
	await process_frame
	await process_frame
	var st = g.station
	for k in st.focus:
		print("FOCUS ", k, " ", st.focus[k])
	print("SPAWN ", st.spawn.origin)
	print("PARTS ", st.parts.keys())
	print("LAMPS ", st.lamps.keys())
	print("LIGHTS ", st.lights.keys())
	var n := 0
	for c in st.get_children():
		if c is StaticBody3D:
			n += 1
	print("INTERACTABLES ", n)
	print("PLAYER ", g.player.global_position)
	for i in 30:
		await process_frame
	var img: Image = g.radar_vp.get_texture().get_image()
	if img:
		img.save_png("/private/tmp/claude-501/-Users-daniel-Documents-Projects-OS-Tools---Software-Blender-Dev/ef3a7133-9044-4ff7-90a7-36a114ceca31/scratchpad/radar_dump.png")
		print("RADAR ", img.get_size(), " px(256,256)=", img.get_pixel(256, 256), " px(10,10)=", img.get_pixel(10, 10))
	quit()
