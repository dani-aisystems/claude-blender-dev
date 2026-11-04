extends Node
## Visual QA captures for the first-person game. Runs the real game (bot plays the sim), places a
## capture camera at named viewpoints that mirror blender/review_views.py and REFERENCE_SPEC.md,
## and writes 1920x1080 PNGs to <workspace>/renders/last_light/.
##   --capture=NAME --shots=menu,40@player,60@fp_desk,90@focus_radio,120@plan,end [--bot=expert] [--speed=4]
## Prints PERF lines (fps at 1x speed) and CAPTURE_RESULT {json}.

const F := 20.0

var main: Node
var out_dir := ""
var results: Array = []
var perf: Array = []
var cam: Camera3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	out_dir = ProjectSettings.globalize_path("res://").path_join("../../../../renders/last_light").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


static func eye(bfrom: float, dist: float, bto: float, tdist: float, zf := 1.65, zt := 1.0) -> Array:
	var a := Geo.dir(deg_to_rad(bfrom)) * dist
	var b := Geo.dir(deg_to_rad(bto)) * tdist
	return [Vector3(a.x, F + zf, a.y), Vector3(b.x, F + zt, b.y)]


func view(name_: String) -> Array:
	match name_:
		"fp_desk": return eye(180, 0.25, 20, 3.0, 1.62, 1.05) + [72.0, false]
		"fp_power": return eye(80, 0.6, -75, 3.0, 1.65, 1.2) + [72.0, false]
		"fp_console": return eye(-110, 0.5, 78, 3.0, 1.65, 0.95) + [72.0, false]
		"fp_gen": return eye(30, 0.8, -140, 3.0, 1.65, 0.9) + [72.0, false]
		"fp_stair": return eye(0, 1.0, 180, 3.0, 1.65, 1.0) + [72.0, false]
		"fp_window": return eye(180, 0.8, 0, 12.0, 1.65, 0.0) + [60.0, false]
		"plan": return [Vector3(0, F + 12.5, 0.001), Vector3(0, F, 0), 30.0, true]
		"iso": return [Vector3(-6.5, F + 8.5, 7.0), Vector3(0.2, F + 0.6, -0.4), 40.0, true]
		"ext": return [Vector3(26, 14, 40), Vector3(0, 17, 0), 42.0, false]
		"ext_far": return [Vector3(-60, 30, -150), Vector3(0, 14, 0), 40.0, false]
	return []


func _run() -> void:
	var args: Dictionary = GameState.user_args
	var name_: String = args.get("capture", "fp")
	var shots: PackedStringArray = String(args.get("shots", "menu,40@player,60@fp_desk")).split(",")
	var speed := float(args.get("speed", "4"))
	Engine.max_physics_steps_per_frame = 24
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	await _frames(60)
	for s in shots:
		if s == "menu":
			await _frames(90)
			_save(name_ + "_menu")
			continue
		if main.game == null:
			main.start_game(args.get("bot", "expert"), args.get("mode", "story") == "story")
			await _frames(10)
		var g = main.game
		if s == "end":
			Engine.time_scale = speed * 2.0
			while (g.sim.result == KeeperSim.Result.RUNNING and not g.story_mode) or (g.story_mode and not g.director.finished):
				await _frames(10)
			Engine.time_scale = 1.0
			await _frames(400)
			_save(name_ + "_end")
			continue
		var vname := "player"
		if "@" in s:
			vname = s.get_slice("@", 1)
			s = s.get_slice("@", 0)
		var target := float(s)
		Engine.time_scale = speed
		while g.sim.t < target - 1.0 and g.sim.result == KeeperSim.Result.RUNNING and not (g.story_mode and g.director.finished):
			await _frames(1)
		Engine.time_scale = 1.0
		_place(g, vname)
		var fps: Array = []
		for i in 90:
			await _frames(1)
			if i > 30:
				fps.append(Engine.get_frames_per_second())
		GameState.prof.clear()
		for i2 in 60:
			await _frames(1)
		var pr := {}
		for k in GameState.prof:
			pr[k] = snappedf(GameState.prof[k] / 60.0 / 1000.0, 0.01)
		print("PROF ms/frame ", pr)
		var dc := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		perf.append({"shot": s + "@" + vname, "fps": fps.max(), "fps_min": fps.min(), "draw_calls": dc, "primitives": prims})
		var vrid := get_viewport().get_viewport_rid()
		print("RENDER gpu_ms=%.1f cpu_ms=%.1f" % [RenderingServer.viewport_get_measured_render_time_gpu(vrid), RenderingServer.viewport_get_measured_render_time_cpu(vrid)])
		print("PERF %s@%s fps=%s draw_calls=%d primitives=%d process_ms=%.1f physics_ms=%.1f vp=%s" % [s, vname, fps[-1], dc, prims,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			get_viewport().get_visible_rect().size])
		_save("%s_t%03d_%s" % [name_, int(target), vname])
		_restore(g)
	print("CAPTURE_RESULT ", JSON.stringify({"files": results, "perf": perf}))
	get_tree().quit(0)


func _place(g, vname: String) -> void:
	if vname == "player":
		return
	if vname.begins_with("focus_"):
		if cam:
			cam.current = false
		g.player.camera.current = true
		g.player.enter_focus(vname.substr(6))
		print("FOCUS ", g.player.focused)
		return
	var v := view(vname)
	if v.is_empty():
		return
	if cam == null:
		cam = Camera3D.new()
		cam.near = 0.03
		cam.far = 2000.0
		add_child(cam)
	cam.global_position = v[0]
	cam.look_at(v[1], Vector3.UP if absf((v[1] - v[0]).normalized().y) < 0.99 else Vector3.FORWARD)
	cam.fov = v[2]
	cam.current = true
	_cutaway(g, v[3])


func _restore(g) -> void:
	_cutaway(g, false)
	if cam:
		cam.current = false
	if g.player:
		if g.player.focused != "":
			g.player.leave_focus()
		g.player.camera.current = true


func _cutaway(g, on: bool) -> void:
	for root in [g.station, g.outside]:
		for n in root.find_children("*", "MeshInstance3D", true, false):
			var nm := String(n.name)
			if nm.begins_with("SM_RoomCeiling") or nm.begins_with("SM_Lantern") or nm.begins_with("SM_Room_SteelRust") or nm.begins_with("SM_RoomPipes") or nm.begins_with("SM_Tower") or nm.begins_with("SM_Gallery") or nm.begins_with("PT_optic") or nm.begins_with("GLS_lantern"):
				n.visible = not on


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(file_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img.get_width() != 1920:
		img.resize(1920, int(1920.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	var path := out_dir.path_join(file_name + ".png")
	img.save_png(path)
	results.append(path)
	print("CAPTURED ", path)
