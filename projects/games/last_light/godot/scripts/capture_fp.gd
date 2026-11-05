extends Node
## Visual QA captures and benchmarks for the first-person game. Runs the real game (bot plays the sim),
## places a capture camera at named viewpoints that mirror blender/review_views.py and REFERENCE_SPEC.md,
## and writes 1920x1080 PNGs to <workspace>/renders/last_light/.
##   --capture=NAME --shots=menu,40@player,60@fp_desk,60@fp_desk!dark,90@focus_radio,120@plan,end
##       [--bot=expert] [--speed=4] [--quality=0|1|2] [--mode=story|watch]
##   Shot = [T@]VIEW[!STATE...]. T = sim seconds. STATE (forced for that shot, restored afterwards):
##     dark (room-lights breaker off), flash (lightning at a fixed bearing, captured at its peak),
##     gen_off (generator stopped), dawn (dawn sky), valve_shut (fuel valve closed),
##     fleet2 (adds a test vessel until two are on the channel; not restored, so put it last)
##   VIEW pp_<ia id> (Stage 2): the PLAYER stands 1.3 m from that control and looks at it, so the shot
##     shows the real crosshair and prompt (e.g. 60@pp_start!gen_off!valve_shut)
##   --nohud hides the HUD / dialogue layers for room views (kept for "player" and "focus_*" shots).
##   --quality applies a preset to the whole run WITHOUT writing user://settings.cfg (presets only
##   take effect on scene load, so it cannot change per shot).
##   --novsync: bench without vsync (true frame cost). Perf bisect flags: --noshadows --nossao --nossil --halfao
##     --novolfog --norain --noglow --noroom --probe=off
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
var _cursor_ia := ""            # focus_<view>~<ia>: the player's virtual cursor tracks that control
var _cursor_game: Node = null


## Keeps the virtual cursor on the hovered control while the device-view camera eases in. The OS pointer
## is never moved (capture runs must not touch Daniel's mouse).
func _process(_delta: float) -> void:
	if _cursor_ia == "" or _cursor_game == null or _cursor_game.player == null:
		return
	for b in _cursor_game.station.get_children():
		if b is StaticBody3D and String(b.get_meta("ia", "")) == _cursor_ia:
			_cursor_game.player.virtual_cursor = _cursor_game.player.camera.unproject_position(b.global_position)
			return


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	out_dir = ProjectSettings.globalize_path("res://").path_join("../../../../renders/last_light").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var args: Dictionary = GameState.user_args
	if not args.has("audio"):         # previews are silent (Daniel); --audio to hear them
		AudioServer.set_bus_mute(0, true)
	if args.has("pad"):               # Stage 2C: show the gamepad glyphs and pad cursor (no pad needed)
		InputSetup.pad_active = true
		InputSetup.pad_forced = true
	if args.has("quality"):
		Settings.v["quality"] = clampi(int(args["quality"]), 0, 2)     # in memory only: no settings file write
	if args.has("render_res"):
		Settings.v["render_res"] = clampi(int(args["render_res"]), 0, 1)
	Settings.apply_render_scale()
	Settings.apply_quality_globals()
	if args.has("msaa"):              # perf bisect: 0 off, 1 2x, 2 4x (project default), in memory only
		get_viewport().msaa_3d = clampi(int(args["msaa"]), 0, 3) as Viewport.MSAA
	if args.has("fxaa"):              # perf bisect: screen-space AA instead of MSAA
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	if args.has("novsync"):          # bench: true frame cost, not the display's 8.3 ms vsync steps (in memory only)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
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
		"fp_stair": return eye(-10, 1.0, 170, 3.0, 1.65, 1.0) + [72.0, false, 0.03]
		"fp_window": return eye(180, 0.8, 0, 12.0, 1.65, 0.0) + [60.0, false, 0.03]
		# --- Stage 0 additions: ceiling + close-ups of the hero pieces ---
		"fp_ceiling": return eye(200, 0.7, 30, 1.9, 1.6, 3.05) + [80.0, false, 0.03]     # beams, lamps, lineshaft
		"cu_lamp": return eye(62, 2.0, 62, 3.25, 1.85, 2.05) + [55.0, false, 0.03]       # wall lamp 1 + its shadows
		"cu_optic": return eye(20, 1.3, 45, 2.78, 1.5, 1.25) + [55.0, false, 0.03]       # optic drive housing
		"cu_console": return eye(78, 1.75, 78, 2.9, 1.6, 0.95) + [50.0, false, 0.03]     # light console
		"cu_power": return eye(-80, 1.4, -80, 3.0, 1.6, 1.2) + [62.0, false, 0.03]       # charger / distribution / cells
		"cu_window": return eye(0, 1.4, 0, 3.42, 1.65, 1.75) + [55.0, false, 0.03]       # bay 0 glass
		"cu_door": return eye(170, 0.2, 170, 2.0, 1.65, 1.1) + [55.0, false, 0.03]
		"cu_shelf": return eye(128, 1.55, 128, 3.0, 1.6, 1.15) + [55.0, false, 0.03]     # storage shelf, old-log box
		# --- Cabin repair (Iteration A): one matched close-up per defect in Daniel's screenshot brief ---
		"cu_gauges": return eye(80, 2.15, 82, 2.85, 1.42, 1.17) + [34.0, false, 0.02]    # console hood dials (IMG_3117)
		"cu_selectors": return eye(84, 1.95, 86, 2.6, 1.42, 0.9) + [36.0, false, 0.02]   # mode / intensity knobs
		"cu_battery": return eye(-55, 2.05, -55, 2.92, 1.62, 1.52) + [42.0, false, 0.02] # charger dials (IMG_3121)
		"cu_photo": return eye(-105, 2.35, -105, 3.2, 1.78, 1.85) + [30.0, false, 0.02]  # keepers' photo (IMG_3122)
		"cu_logbook": return eye(-12, 1.75, -13, 2.5, 1.5, 0.79) + [42.0, false, 0.02]   # open station log (IMG_3119)
		"cu_radio": return eye(-4, 1.75, -6, 2.75, 1.38, 0.95) + [50.0, false, 0.02]     # transceiver + mic (IMG_3118)
		"cu_gen": return eye(-140, 0.7, -140, 3.0, 1.6, 0.8) + [62.0, false, 0.02]       # generator cage (IMG_3123)
		# --- Stage 1 iteration 5: desk micro-detail (mug, pencils, logbook, chart, books, chair) ---
		"cu_desk_l": return eye(-20, 1.85, -11, 2.5, 1.25, 0.82) + [45.0, false, 0.02]   # mug, pencil pot, logbook
		"cu_desk_r": return eye(28, 2.1, 16, 2.71, 1.4, 0.85) + [45.0, false, 0.02]      # books, binoculars, forecast
		"cu_chart": return eye(3, 1.95, 2.3, 2.48, 1.6, 0.78) + [50.0, false, 0.02]      # chart, rule, dividers
		"cu_chair": return eye(34, 1.08, 1.7, 1.73, 1.5, 0.6) + [55.0, false, 0.02]      # chair + desk front, standing
		# --- cabin pass: matched to Daniel's photos IMG_3134-3141 ---
		"cu_ext": return eye(106, 1.55, 106, 3.1, 1.45, 0.72) + [48.0, false, 0.02]      # extinguisher (IMG_3134)
		"cu_lantern": return eye(128, 1.6, 128, 3.0, 1.45, 1.2) + [42.0, false, 0.02]    # storage shelf lantern (IMG_3135)
		"cu_coat": return eye(149, 1.0, 150, 2.75, 1.55, 1.05) + [55.0, false, 0.02]     # coat rack (IMG_3137)
		"cu_sill_w": return eye(-30, 1.7, -32, 3.15, 1.45, 0.97) + [45.0, false, 0.02]  # west sill tin (IMG_3138)
		"cu_optic_top": return eye(45, 1.3, 45, 2.78, 2.45, 1.3) + [50.0, false, 0.02]  # optic drive from above (IMG_3141)
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
		"fleet2":                   # Stage 2: at least two vessels on the channel (radio panel Tab tip);
			while g.sim.active_ships().size() < 2:   # not restored: put such shots last
				g._route(g.sim.spawn_story_ship({"name": "Capture Test", "kind": "fishing", "bearing": 30, "aim": 30, "hold": true, "protected": true}))
		"torch":                    # cabin pass: the keeper carries the torch, switched on (not restored)
			g._take_torch(true)
		"valve_shut":               # Stage 2: START refused with a reason
			_restore_state["fuel_valve"] = g.sim.fuel_valve
			g.sim.fuel_valve = false
		"flash":
			pass                        # triggered right before the save (see _flash_peak)
		_:
			push_warning("capture: unknown state '%s'" % st)


func _unforce(g) -> void:
	if _restore_state.has("brk_lights"):
		g._route(g.sim.set_breaker("lights", _restore_state["brk_lights"]))
	if _restore_state.has("gen"):
		g.sim.gen = _restore_state["gen"]
	if _restore_state.has("fuel_valve"):
		g.sim.fuel_valve = _restore_state["fuel_valve"]
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
		g.player.enabled = false                # as game_fp._on_doc: no crosshair or prompt over the page
		g.ui.clear_prompt()
		g.presenter.open_document(vname.substr(4))
		return
	if vname.begins_with("focus_"):
		if cam:
			cam.current = false
		g.player.camera.current = true
		var fv := vname.substr(6).split("~")    # focus_console~mode: hover the MODE knob (Stage 2)
		g.player.enter_focus(fv[0])
		_cursor_ia = fv[1] if fv.size() > 1 else ""
		_cursor_game = g
		print("FOCUS ", g.player.focused)
		return
	if vname.begins_with("pp_"):
		_pose_player(g, vname.substr(3))
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


## Stage 2: "pp_<ia id>" stands the PLAYER (not the capture camera) 1.3 m from that interaction volume,
## towards the room centre, and looks at it, so the shot shows the real crosshair and prompt state.
## Uses only player/station API that predates Stage 2, so the same view drives the "before" captures.
func _pose_player(g, id: String) -> void:
	var target := Vector3.INF
	for b in g.station.get_children():
		if b is StaticBody3D and String(b.get_meta("ia", "")) == id:
			target = b.global_position
			break
	if target == Vector3.INF:
		push_warning("capture: no interaction volume '%s'" % id)
		return
	if cam:
		cam.current = false
	g.player.camera.current = true
	var inward := Vector3(-target.x, 0, -target.z).normalized()
	var stand: Vector3 = target + inward * 1.3
	g.player.global_position = Vector3(stand.x, g.player.global_position.y, stand.z)
	g.player.velocity = Vector3.ZERO
	var to: Vector3 = target - (g.player.global_position + Vector3(0, g.player.EYE, 0))
	g.player._yaw = atan2(-to.x, -to.z)
	g.player._pitch = atan2(to.y, Vector2(to.x, to.z).length())
	g.player._apply_look()
	_hud(g, true)


func _hud(g, on: bool) -> void:
	for layer in [g.ui, g.presenter]:
		if layer:
			layer.visible = on


func _restore(g) -> void:
	_cutaway(g, false)
	_hud(g, true)
	if g.presenter and g.presenter.is_document_open():
		g.presenter.doc_root.visible = false
		g.presenter.dialogue.visible = true
		g.presenter._doc_open = ""
		g.player.enabled = true
	if cam:
		cam.current = false
	if g.player:
		if g.player.focused != "":
			g.player.leave_focus()
		g.player.camera.current = true
		g.player.virtual_cursor = Vector2.INF
	_cursor_ia = ""


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

func _bench_toggle(g, vname: String, secs: float, report: Dictionary) -> void:
	_place(g, vname)
	await _frames(30)
	var targets: Array = String(GameState.user_args.get("bench_targets", "none,station,outside,radar_vp,ui,presenter,audio,player,director")).split(",")
	var res := []
	for t in targets:
		var n: Node = g.get(t) if t in ["station", "outside", "radar_vp", "radar", "ui", "presenter", "audio", "player", "director"] else null
		var old := Node.PROCESS_MODE_INHERIT
		if t == "radar_render":            # keep the script, stop the SubViewport re-rendering
			g.radar_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var hid: Node3D = null
		if t == "radar_hide":
			g.radar.visible = false
		elif t == "scr_hide":              # the desk screen that samples the radar texture
			hid = g.station.find_child("SCR_radar*", true, false)
			if hid:
				hid.visible = false
		if n:
			old = n.process_mode
			n.process_mode = Node.PROCESS_MODE_DISABLED
		await _frames(10)
		GameState.prof = {}
		var ft: Array[float] = []
		var proc: Array[float] = []
		var prim_t := 0.0
		var dc_t := 0.0
		var sec_ft: Array[float] = []
		var sec_pr := 0.0
		var next_sec := 1.0
		var series := []
		var el := 0.0
		var last := Time.get_ticks_usec()
		while el < secs:
			_worst_case(g)
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			var ms := (now - last) / 1000.0
			last = now
			el += ms / 1000.0
			ft.append(ms)
			proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			prim_t += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			sec_ft.append(ms)
			sec_pr += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			if el >= next_sec:
				series.append([snappedf(el, 0.1), snappedf(_pct(sec_ft, 0.5), 0.1), int(sec_pr / sec_ft.size())])
				sec_ft = []
				sec_pr = 0.0
				next_sec += 1.0
			dc_t += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		if n:
			n.process_mode = old
		if t == "radar_render":
			g.radar_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		if t == "radar_hide":
			g.radar.visible = true
		if hid:
			hid.visible = true
		var per := {}
		for k in GameState.prof:
			per[k] = snappedf(GameState.prof[k] / 1000.0 / maxf(1.0, ft.size()), 0.01)   # ms per frame
		var r := {"off": t, "median_ms": _pct(ft, 0.5), "p95_ms": _pct(ft, 0.95), "process_median_ms": _pct(proc, 0.5), "prims_avg": int(prim_t / maxf(1.0, ft.size())), "draws_avg": int(dc_t / maxf(1.0, ft.size())), "script_ms": per, "series_s_ms_prims": series}
		res.append(r)
		print("TOGGLE ", JSON.stringify(r))
	report["toggle"] = res


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
	if args.has("bench_toggle"):          # perf bisect: freeze one node's processing at a time
		await _bench_toggle(g, shots[0], float(args.get("bench_toggle_secs", "6")), report)
		shots = PackedStringArray()
	for vname in shots:
		_place(g, vname)
		var ft: Array[float] = []
		var gpu: Array[float] = []
		var proc: Array[float] = []        # script _process time (Performance.TIME_PROCESS)
		var rcpu: Array[float] = []        # render-thread CPU: viewport draw + frame setup
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
			proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			rcpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vrid) + RenderingServer.get_frame_setup_time_cpu())
			dc = maxf(dc, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			prims = maxf(prims, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		var r := {"shot": vname, "frames": ft.size(), "median_ms": _pct(ft, 0.5), "p95_ms": _pct(ft, 0.95),
			"p99_ms": _pct(ft, 0.99), "max_ms": ft.max(), "gpu_median_ms": _pct(gpu, 0.5), "gpu_p95_ms": _pct(gpu, 0.95),
			"process_median_ms": _pct(proc, 0.5), "render_cpu_median_ms": _pct(rcpu, 0.5),
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
