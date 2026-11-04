extends Node
## Visual QA captures and benchmarks for the first-person game. Runs the real game (bot plays the sim),
## places a capture camera at named viewpoints that mirror blender/review_views.py and REFERENCE_SPEC.md,
## and writes 1920x1080 PNGs to <workspace>/renders/last_light/.
##   --capture=NAME --shots=menu,40@player,60@fp_desk,60@fp_desk!dark,90@focus_radio,120@plan,end
##       [--bot=expert] [--speed=4] [--quality=0|1|2] [--mode=story|watch]
##   Shot = [T@]VIEW[!STATE...]. T = sim seconds. STATE (forced for that shot, restored afterwards):
##     dark (room-lights breaker off), flash (lightning at a fixed bearing, captured at its peak),
##     gen_off (generator stopped), dawn (dawn sky)
##   --nohud hides the HUD / dialogue layers for room views (kept for "player" and "focus_*" shots).
##   --quality applies a preset to the whole run WITHOUT writing user://settings.cfg (presets only
##   take effect on scene load, so it cannot change per shot).
##   --bench [--bench_secs=60] [--bench_shots=fp_desk,fp_window,fp_gen]: worst case (storm 1.0, lightning
##     every 3 s, generator running, all breakers on, one ship) at 1x speed; writes NAME_bench.json with
##     median / p95 frame time, GPU time, draw calls, primitives and memory per shot.
## Prints PERF lines (fps at 1x speed), PROF lines and CAPTURE_RESULT {json}.
## NOTE: frame timings are only trustworthy when the window is frontmost (macOS throttles otherwise).

const F := 20.0
const FLASH_BEARING := 20.0

var main: Node
var out_dir := ""
var results: Array = []
var perf: Array = []
var cam: Camera3D
var _restore_state: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	out_dir = ProjectSettings.globalize_path("res://").path_join("../../../../renders/last_light").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var args: Dictionary = GameState.user_args
	if args.has("quality"):
		Settings.v["quality"] = clampi(int(args["quality"]), 0, 2)     # in memory only: no settings file write
	if args.has("render_res"):
		Settings.v["render_res"] = clampi(int(args["render_res"]), 0, 1)
	Settings.apply_render_scale()
	Settings.apply_quality_globals()
	_run.call_deferred()


static func eye(bfrom: float, dist: float, bto: float, tdist: float, zf := 1.65, zt := 1.0) -> Array:
	var a := Geo.dir(deg_to_rad(bfrom)) * dist
	var b := Geo.dir(deg_to_rad(bto)) * tdist
	return [Vector3(a.x, F + zf, a.y), Vector3(b.x, F + zt, b.y)]


## [eye, target, fov, cutaway, near]. Bearings: 0 = north (sea windows), clockwise. See REFERENCE_SPEC.md.
func view(name_: String) -> Array:
	match name_:
		"fp_desk": return eye(180, 0.25, 20, 3.0, 1.62, 1.05) + [72.0, false, 0.03]
		"fp_power": return eye(80, 0.6, -75, 3.0, 1.65, 1.2) + [72.0, false, 0.03]
		"fp_console": return eye(-110, 0.5, 78, 3.0, 1.65, 0.95) + [72.0, false, 0.03]
		"fp_gen": return eye(30, 0.8, -140, 3.0, 1.65, 0.9) + [72.0, false, 0.03]
		"fp_stair": return eye(0, 1.0, 180, 3.0, 1.65, 1.0) + [72.0, false, 0.03]
		"fp_window": return eye(180, 0.8, 0, 12.0, 1.65, 0.0) + [60.0, false, 0.03]
		# --- Stage 0 additions: ceiling + close-ups of the hero pieces ---
		"fp_ceiling": return eye(200, 0.7, 30, 1.9, 1.6, 3.05) + [80.0, false, 0.03]     # beams, lamps, lineshaft
		"cu_lamp": return eye(62, 2.0, 62, 3.25, 1.85, 2.05) + [55.0, false, 0.03]       # wall lamp 1 + its shadows
		"cu_optic": return eye(20, 1.3, 45, 2.78, 1.5, 1.25) + [55.0, false, 0.03]       # optic drive housing
		"cu_console": return eye(78, 1.75, 78, 2.9, 1.6, 0.95) + [50.0, false, 0.03]     # light console
		"cu_power": return eye(-80, 1.4, -80, 3.0, 1.6, 1.2) + [62.0, false, 0.03]       # charger / distribution / cells
		"cu_window": return eye(0, 1.4, 0, 3.42, 1.65, 1.75) + [55.0, false, 0.03]       # bay 0 glass
		"cu_door": return eye(180, 0.2, 180, 2.0, 1.65, 1.1) + [55.0, false, 0.03]      # stair door (knock scene)
		# --- Cabin repair (Iteration A): one matched close-up per defect in Daniel's screenshot brief ---
		"cu_gauges": return eye(80, 2.15, 82, 2.85, 1.42, 1.17) + [34.0, false, 0.02]    # console hood dials (IMG_3117)
		"cu_selectors": return eye(84, 1.95, 86, 2.6, 1.42, 0.9) + [36.0, false, 0.02]   # mode / intensity knobs
		"cu_battery": return eye(-55, 2.05, -55, 2.92, 1.62, 1.52) + [42.0, false, 0.02] # charger dials (IMG_3121)
		"cu_photo": return eye(-105, 2.35, -105, 3.2, 1.78, 1.85) + [30.0, false, 0.02]  # keepers' photo (IMG_3122)
		"cu_logbook": return eye(-12, 1.75, -13, 2.5, 1.5, 0.79) + [42.0, false, 0.02]   # open station log (IMG_3119)
		"cu_radio": return eye(-4, 1.75, -6, 2.75, 1.38, 0.95) + [50.0, false, 0.02]     # transceiver + mic (IMG_3118)
		"cu_shelf": return eye(140, 1.1, 140, 3.0, 1.55, 0.78) + [58.0, false, 0.02]     # storage rack (IMG_3116)
		"cu_gen": return eye(-140, 0.7, -140, 3.0, 1.6, 0.8) + [62.0, false, 0.02]       # generator cage (IMG_3123)
		# plan: the near plane clips everything above F+2.65 (beams, pipes, ceiling) for a clean top view
		"plan": return [Vector3(0, F + 12.5, 0.001), Vector3(0, F, 0), 30.0, true, 12.5 - 2.65]
		"iso": return [Vector3(-6.5, F + 8.5, 7.0), Vector3(0.2, F + 0.6, -0.4), 40.0, true, 0.03]
		"ext": return [Vector3(26, 14, 40), Vector3(0, 17, 0), 42.0, false, 0.03]
		"ext_far": return [Vector3(-60, 30, -150), Vector3(0, 14, 0), 40.0, false, 0.03]
	return []


func _run() -> void:
	var args: Dictionary = GameState.user_args
	var name_: String = args.get("capture", "fp")
	if args.has("bench"):
		await _bench(name_, args)
		return
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
		await _ensure_game(args)
		var g = main.game
		if s == "end":
			Engine.time_scale = speed * 2.0
			while (g.sim.result == KeeperSim.Result.RUNNING and not g.story_mode) or (g.story_mode and not g.director.finished):
				await _frames(10)
			Engine.time_scale = 1.0
			await _frames(400)
			_save(name_ + "_end")
			continue
		var states: PackedStringArray = s.split("!")
		s = states[0]
		states.remove_at(0)
		var vname := "player"
		if "@" in s:
			vname = s.get_slice("@", 1)
			s = s.get_slice("@", 0)
		elif not s.is_valid_float():
			vname = s                   # e.g. "focus_radio" with no time = capture now
			s = str(int(g.sim.t))
		var target := float(s)
		Engine.time_scale = speed
		while g.sim.t < target - 1.0 and g.sim.result == KeeperSim.Result.RUNNING and not (g.story_mode and g.director.finished):
			await _frames(1)
		Engine.time_scale = 1.0
		_place(g, vname)
		for st in states:
			_force(g, st)
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
		var tag := vname + ("!" + "!".join(states) if not states.is_empty() else "")
		perf.append({"shot": s + "@" + tag, "fps": fps.max(), "fps_min": fps.min(), "draw_calls": dc, "primitives": prims})
		var vrid := get_viewport().get_viewport_rid()
		print("RENDER gpu_ms=%.1f cpu_ms=%.1f" % [RenderingServer.viewport_get_measured_render_time_gpu(vrid), RenderingServer.viewport_get_measured_render_time_cpu(vrid)])
		print("PERF %s@%s fps=%s draw_calls=%d primitives=%d process_ms=%.1f physics_ms=%.1f vp=%s" % [s, tag, fps[-1], dc, prims,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			get_viewport().get_visible_rect().size])
		if "flash" in states:
			await _flash_peak(g)
		_save("%s_t%03d_%s" % [name_, int(target), tag.replace("!", "-")])
		_unforce(g)
		_restore(g)
	print("CAPTURE_RESULT ", JSON.stringify({"files": results, "perf": perf}))
	get_tree().quit(0)


func _ensure_game(args: Dictionary) -> void:
	if main.game == null:
		main.start_game(args.get("bot", "expert"), args.get("mode", "story") == "story")
		await _frames(10)


# ------------------------------------------------------------------ forced lighting states

func _force(g, st: String) -> void:
	match st:
		"dark":
			_restore_state["brk_lights"] = g.sim.brk_lights
			g._route(g.sim.set_breaker("lights", false))
		"gen_off":
			_restore_state["gen"] = g.sim.gen
			g.sim.gen = KeeperSim.Gen.OFF
		"dawn":
			_restore_state["dawn"] = g.outside.dawn
			g.outside.set_sky("dawn")
			g.outside.dawn = 1.0
		"flash":
			pass                        # triggered right before the save (see _flash_peak)
		_:
			push_warning("capture: unknown state '%s'" % st)


func _unforce(g) -> void:
	if _restore_state.has("brk_lights"):
		g._route(g.sim.set_breaker("lights", _restore_state["brk_lights"]))
	if _restore_state.has("gen"):
		g.sim.gen = _restore_state["gen"]
	if _restore_state.has("dawn"):
		g.outside.dawn = _restore_state["dawn"]
		g.outside.set_sky("night")
	_restore_state.clear()


## Re-strike every frame until the flicker term (outside.gd: 0.55 + 0.45 sin(47 t)) is near its peak,
## so flash captures are comparable between runs.
func _flash_peak(g) -> void:
	for i in 40:
		g.outside.on_events([{"type": "lightning", "power": 1.0, "bearing": FLASH_BEARING}])
		await _frames(1)
		if sin(g.outside._t * 47.0) > 0.85:
			return


# ------------------------------------------------------------------ camera

func _place(g, vname: String) -> void:
	if vname == "player":
		return
	if vname.begins_with("doc_"):
		# document inspection view as the player sees it (story_presenter.open_document)
		_hud(g, true)
		g.presenter.open_document(vname.substr(4))
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
		push_warning("capture: unknown view '%s'" % vname)
		return
	if cam == null:
		cam = Camera3D.new()
		cam.far = 2000.0
		add_child(cam)
	cam.near = v[4]
	cam.global_position = v[0]
	cam.look_at(v[1], Vector3.UP if absf((v[1] - v[0]).normalized().y) < 0.99 else Vector3.FORWARD)
	cam.fov = v[2]
	cam.current = true
	_cutaway(g, v[3])
	_hud(g, not GameState.user_args.has("nohud"))


func _hud(g, on: bool) -> void:
	for layer in [g.ui, g.presenter]:
		if layer:
			layer.visible = on


func _restore(g) -> void:
	_cutaway(g, false)
	_hud(g, true)
	if g.presenter and g.presenter.is_document_open():
		g.presenter.doc_root.visible = false
		g.presenter._doc_open = ""
	if cam:
		cam.current = false
	if g.player:
		if g.player.focused != "":
			g.player.leave_focus()
		g.player.camera.current = true


## Cutaway for plan/iso: hides the lighthouse shell above the room and the room's ceiling-only meshes.
## Room buckets that mix ceiling and floor items (SM_Room_SteelRust: I-beams + battery rack) stay
## visible so nothing on the floor disappears; Stage 1 moves ceiling parts into their own SM_Ceil* buckets.
func _cutaway(g, on: bool) -> void:
	for n in g.outside.find_children("*", "MeshInstance3D", true, false):
		var nm := String(n.name)
		if nm.begins_with("SM_Lantern") or nm.begins_with("SM_Tower") or nm.begins_with("SM_Gallery") or nm == "PT_optic" or nm.begins_with("GLS_lantern") or nm.begins_with("SM_Ceil"):
			n.visible = not on
	for n in g.station.find_children("*", "MeshInstance3D", true, false):
		var nm := String(n.name)
		var ceiling_only: bool = n.get_aabb() != AABB() and (n.global_transform * n.get_aabb()).position.y > F + 2.6
		if nm.begins_with("SM_RoomCeiling") or nm.begins_with("SM_RoomPipes") or nm.begins_with("SM_Ceil") or ceiling_only:
			n.visible = not on


# ------------------------------------------------------------------ benchmark

func _bench(name_: String, args: Dictionary) -> void:
	var secs := float(args.get("bench_secs", "60"))
	var shots: PackedStringArray = String(args.get("bench_shots", "fp_desk,fp_window,fp_gen")).split(",")
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	await _frames(60)
	await _ensure_game(args)
	var g = main.game
	Engine.time_scale = 4.0
	while g.sim.t < 45.0:                 # let the story set up the room (lights, radio) first
		await _frames(1)
	Engine.time_scale = 1.0
	g._route(g.sim.spawn_story_ship({"name": "Bench", "kind": "fishing", "bearing": 20, "aim": 24, "speed_mul": 0.4, "hold": true, "protected": true}))
	var report := {"name": name_, "quality": int(Settings.v["quality"]), "scale3d": get_viewport().scaling_3d_scale,
		"window": DisplayServer.window_get_size(), "focused": DisplayServer.window_is_focused(), "secs": secs, "shots": []}
	for vname in shots:
		_place(g, vname)
		var ft: Array[float] = []
		var gpu: Array[float] = []
		var dc := 0.0
		var prims := 0.0
		var next_strike := 0.5
		var el := 0.0
		var vrid := get_viewport().get_viewport_rid()
		await _frames(30)                 # settle (shader compiles, probe/shadow updates)
		var last := Time.get_ticks_usec()
		while el < secs:
			_worst_case(g)
			if el >= next_strike:
				g.outside.on_events([{"type": "lightning", "power": 1.0, "bearing": FLASH_BEARING}])
				next_strike += 3.0
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			var ms := (now - last) / 1000.0
			last = now
			el += ms / 1000.0
			ft.append(ms)
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vrid))
			dc = maxf(dc, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			prims = maxf(prims, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		var r := {"shot": vname, "frames": ft.size(), "median_ms": _pct(ft, 0.5), "p95_ms": _pct(ft, 0.95),
			"p99_ms": _pct(ft, 0.99), "max_ms": ft.max(), "gpu_median_ms": _pct(gpu, 0.5), "gpu_p95_ms": _pct(gpu, 0.95),
			"draw_calls_max": dc, "primitives_max": prims,
			"video_mem_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
			"texture_mem_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
			"focused": DisplayServer.window_is_focused()}
		report["shots"].append(r)
		print("BENCH ", JSON.stringify(r))
		_restore(g)
	var path := out_dir.path_join("%s_bench.json" % name_)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("BENCH_RESULT ", path)
	get_tree().quit(0)


## Worst case held every frame (the story director would otherwise ease things back).
func _worst_case(g) -> void:
	g.sim.storm_override = 1.0
	g.sim.main_breaker = true
	g.sim.brk_lights = true
	g.sim.brk_radar = true
	g.sim.gen = KeeperSim.Gen.RUNNING
	g.sim.battery = maxf(g.sim.battery, 80.0)


static func _pct(a: Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return snappedf(s[clampi(int(round(q * (s.size() - 1))), 0, s.size() - 1)], 0.01)


# ------------------------------------------------------------------ io

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
