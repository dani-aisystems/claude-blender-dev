extends SceneTree
## Interaction checklist (automated part) for the five primary workstations: radio, generator controls,
## power panel, light console, stair door. Runs against the real room GLB + station + sim.
##  #1 approach : a clear standing spot (player capsule, layer-1 colliders) 0.8-1.5 m from the control
##  #2 prompt   : from that spot, at eye height, the crosshair ray picks THIS control (REACH 1.9 m)
##  #3 part     : the matching PT_/NDL_ node actually moves
##  #5 state    : the sim / game state changes
##  #6 sound    : an audio player is spawned (whether it SOUNDS right is for a human to judge)
##  #8 save     : save_dict -> fresh game -> same device states AND same part poses
##  (#4 believable animation and #7 readable instruments are visual: see the s0 captures.)
##   godot --headless --path godot -s res://tests/interaction_test.gd
## Prints one line per check and INTERACTION_RESULT {json}; exit 1 on any FAIL.

const F := 20.0
const WORKSTATIONS := {
	"radio": ["radio"],
	"generator": ["fuel_valve", "start", "gen_panel"],
	"power": ["brk_main", "brk_lights", "brk_radar", "charge", "battery", "power_panel"],
	"console": ["console", "mode", "intensity", "handwheel"],
	"door": ["door"],
	"desk": ["chart", "radar", "logbook", "drawer", "forecast", "photo", "note", "archive"],
}
const PART := {"fuel_valve": "PT_fuel_valve", "start": "PT_start", "brk_main": "PT_brk_main", "brk_lights": "PT_brk_lights",
	"brk_radar": "PT_brk_radar", "charge": "PT_charge", "mode": "PT_mode", "intensity": "PT_intensity",
	"handwheel": "PT_handwheel", "radio": "PT_handset", "door": "PT_stair_door"}

var g: Node3D
var rows: Array = []
var fails := 0
var warns := 0
var reachable := {}            # Vector2i grid cell (0.1 m) -> true, flood-filled from the spawn point
const CELL := 0.1


func _initialize() -> void:
	_run.call_deferred()


func _row(ws: String, dev: String, check: String, status: String, note := "") -> void:
	rows.append({"ws": ws, "device": dev, "check": check, "status": status, "note": note})
	if status == "FAIL":
		fails += 1
	elif status == "WARN":
		warns += 1
	print("  %-4s %-10s %-12s %-7s %s" % [status, ws, dev, check, note])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _new_game(save: Dictionary = {}) -> Node3D:
	var gg: Node3D = load("res://scripts/fp/game_fp.gd").new()
	root.add_child(gg)
	gg.start(3, "", false, true, save)
	await _frames(3)
	gg.director.process_mode = Node.PROCESS_MODE_DISABLED   # no story beats during the checks
	return gg


func _run() -> void:
	await process_frame
	g = await _new_game()
	await _frames(5)
	# Power the station the way chapter 1 leaves it, so controls have something to act on.
	g.sim.battery = 80.0
	await _flood_from_spawn()
	for ws in WORKSTATIONS:
		print("WORKSTATION ", ws)
		for dev in WORKSTATIONS[ws]:
			await _reach(ws, dev)
			await _operate(ws, dev)
	await _save_roundtrip()
	var summary := {"failed": fails, "rows": rows}
	print("INTERACTION_RESULT ", JSON.stringify({"failed": fails, "warnings": warns, "checks": rows.size()}))
	var out := FileAccess.open("user://interaction_result.json", FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(summary, " "))
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ #1 approach + #2 prompt

func _ia(dev: String) -> Node3D:
	return g.station.room.find_child("IA_" + dev, true, false) as Node3D


## Centre of the IA_ box plus 8 points at 60 % of its half-size (scale = half-size, see station.gd).
func _aim_points(ia: Node3D) -> Array:
	var gt := ia.global_transform
	var pts := [gt.origin]
	for sx in [-0.6, 0.0, 0.6]:
		for sy in [-0.6, 0.0, 0.6]:
			if sx != 0.0 or sy != 0.0:
				pts.append(gt * Vector3(sx, sy, 0.0))
	return pts


func _clear_at(feet: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = g.player.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.75
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis(), feet + Vector3(0, 0.875 + 0.03, 0))
	q.collision_mask = 1
	q.exclude = [g.player.get_rid()]
	return space.intersect_shape(q, 1).is_empty()


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / CELL), roundi(p.z / CELL))


## Flood-fill the walkable floor from the spawn point with the player's capsule (layer-1 colliders),
## 4-neighbour steps of 10 cm. A control is "approachable" only from a spot the keeper can walk to.
func _flood_from_spawn() -> void:
	var start := _cell(g.station.spawn.origin)
	var open: Array[Vector2i] = [start]
	var seen := {start: true}
	var clear_cache := {}
	while not open.is_empty():
		var c: Vector2i = open.pop_back()
		var feet := Vector3(c.x * CELL, F, c.y * CELL)
		if Vector2(feet.x, feet.z).length() > 3.25 - 0.28:
			continue
		if not clear_cache.has(c):
			clear_cache[c] = _clear_at(feet)
		if not clear_cache[c]:
			continue
		reachable[c] = true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n):
				seen[n] = true
				open.append(n)
	var area := reachable.size() * CELL * CELL
	var floor_area := PI * pow(3.25 - 0.28, 2)
	_row("room", "floor", "walkable", "PASS" if reachable.size() > 200 else "FAIL",
		"%.1f m2 reachable from spawn (%.0f %% of the %.1f m2 inside the wall clearance)" % [area, 100.0 * area / floor_area, floor_area])
	await process_frame


func _aim(target: Vector3) -> void:
	var cam_pos: Vector3 = g.player.camera.global_position
	var to := target - cam_pos
	g.player._yaw = atan2(-to.x, -to.z)
	g.player._pitch = atan2(to.y, Vector2(to.x, to.z).length())
	g.player._apply_look()


func _reach(ws: String, dev: String) -> void:
	var ia := _ia(dev)
	if ia == null:
		_row(ws, dev, "approach", "FAIL", "IA_%s missing" % dev)
		return
	var p := ia.global_position
	var out := Vector3(-p.x, 0, -p.z).normalized()        # from the control toward the room centre
	var best := -1.0
	var spot_found := false
	var hit_dists: Array = []
	for ang in [0.0, -20.0, 20.0, -40.0, 40.0]:
		var dir := out.rotated(Vector3.UP, deg_to_rad(ang))
		for i in 15:
			var d := 0.6 + i * 0.1
			var feet := Vector3(p.x, F, p.z) + dir * d
			if Vector2(feet.x, feet.z).length() > 3.25 - 0.3 or not _clear_at(feet) or not reachable.has(_cell(feet)):
				continue
			if d >= 0.8 and d <= 1.5:
				spot_found = true
			g.player.global_position = feet
			await physics_frame
			# a player can aim anywhere on the control: try its centre, then points across its box
			for t in _aim_points(ia):
				_aim(t)
				await physics_frame
				var id: String = g.player._ray_hit_id(false)
				if id == dev or (dev == "radio" and id == "radar"):
					hit_dists.append(snappedf(d, 0.1))
					if d >= 0.8 and d <= 1.5:
						best = maxf(best, d)
					break
	_row(ws, dev, "approach", "PASS" if spot_found else "FAIL", "walkable spot 0.8-1.5 m away, reachable from spawn" if spot_found else "no spot 0.8-1.5 m away that is reachable from spawn")
	if best > 0.0:
		_row(ws, dev, "prompt", "PASS", "picked from %.1f-%.1f m" % [hit_dists.min(), hit_dists.max()])
	else:
		_row(ws, dev, "prompt", "FAIL", "picked at %s m (need a hit within 0.8-1.5 m); %s" % [hit_dists, await _diagnose(p, out)])


## Why the crosshair misses: what the interaction ray hits, and which layer-1 collider occludes it.
func _diagnose(p: Vector3, out: Vector3) -> String:
	g.player.global_position = Vector3(p.x, F, p.z) + out * 1.1
	await physics_frame
	_aim(p)
	await physics_frame
	var space: PhysicsDirectSpaceState3D = g.player.get_world_3d().direct_space_state
	var o: Vector3 = g.player.camera.global_position
	var dir := (p - o).normalized()
	var q := PhysicsRayQueryParameters3D.create(o, o + dir * 3.0, 1 << 1)
	var hit := space.intersect_ray(q)
	var q2 := PhysicsRayQueryParameters3D.create(o, o + dir * 3.0, 1)
	q2.exclude = [g.player.get_rid()]
	var blk := space.intersect_ray(q2)
	var s := "eye->IA %.2f m" % o.distance_to(p)
	s += ", IA ray: " + ("%s at %.2f" % [hit["collider"].get_meta("ia", "?"), o.distance_to(hit["position"])] if not hit.is_empty() else "none")
	s += ", blocker: " + ("%s at %.2f" % [_body_name(blk["collider"]), o.distance_to(blk["position"])] if not blk.is_empty() else "none")
	return s


func _body_name(b: Object) -> String:
	if b is Node:
		var n: Node = b
		for c in n.get_children():
			if c is CollisionShape3D or c is MeshInstance3D:
				pass
		return String(n.name) + ("/" + String(n.get_parent().name) if n.get_parent() else "")
	return str(b)


# ------------------------------------------------------------------ #3 part, #5 state, #6 sound

func _audio_count() -> int:
	var n := 0
	for c in g.audio.get_children():
		if (c is AudioStreamPlayer or c is AudioStreamPlayer3D) and c.playing:
			n += 1
	return n


func _pose(dev: String) -> Transform3D:
	var pn: String = PART.get(dev, "")
	if pn == "" or not g.station.parts.has(pn):
		return Transform3D()
	return g.station.parts[pn]["node"].transform


func _moved(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) > 0.002 or a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion()) > 0.02


func _use(dev: String, action := "press") -> Array:
	var ev: Array = g.station.use(dev, action)
	g._route(ev)
	return ev


func _operate(ws: String, dev: String) -> void:
	var d: Dictionary = g.station.DEVICES[dev]
	var pose0 := _pose(dev)
	var snd0 := _audio_count()
	var kind: String = d["kind"]
	var state_ok := false
	var state_note := ""
	var sound_expected := true
	match kind:
		"toggle", "cycle":
			var before = d["get"].call(g.sim)
			_use(dev)
			var after = d["get"].call(g.sim)
			state_ok = after != before
			state_note = "%s -> %s" % [before, after]
		"hold":
			g.sim.fuel_valve = true
			_use(dev, "press")
			state_ok = g.sim.start_held and g.sim.gen == KeeperSim.Gen.CRANKING
			state_note = "start_held=%s gen=%s" % [g.sim.start_held, g.sim.gen]
		"info":
			var ev := _use(dev)
			state_ok = ev.any(func(e): return e["type"] == "inspect")
			state_note = "inspect event, notice '%s'" % g.ui.notice.text.left(40)
		"focus":
			g.player.enter_focus(d.get("focus_id", dev))
			await _frames(30)
			var want_focus: String = d.get("focus_id", dev)
			state_ok = g.player.focused == want_focus and (want_focus != "radio" or g.ui.radio_panel.visible)
			state_note = "focused=%s" % g.player.focused
			sound_expected = false
			if dev == "console":                      # inside the view, the mouse must reach every control
				var space: PhysicsDirectSpaceState3D = g.player.get_world_3d().direct_space_state
				var o: Vector3 = g.player.camera.global_position
				for c in ["mode", "intensity", "handwheel", "note"]:
					var ok := false
					for t in _aim_points(_ia(c)):
						if g.player.pick(space, o, (t - o).normalized(), g.player.REACH + 1.2) == c:
							ok = true
							break
					_row(ws, c, "view-click", "PASS" if ok else "FAIL", "clickable from the console view" if ok else "not clickable in the console view")
			if dev == "radio":                        # transmit to a real vessel: handset + radio audio
				g._route(g.sim.spawn_story_ship({"name": "Testboat", "kind": "fishing", "bearing": 20, "aim": 24, "hold": true, "protected": true}))
				await _frames(2)
				g.ui._refresh_vessels()
				snd0 = _audio_count()
				var ev: Array = g.sim.command(g.ui.selected_ship, "confirm")
				g._route(ev)
				state_ok = state_ok and ev.any(func(e): return e["type"] == "tx")
				state_note += ", tx=%s" % ev.any(func(e): return e["type"] == "tx")
				sound_expected = true
		"wheel":
			g._route(g.sim.set_mode(KeeperSim.Mode.MANUAL))
			var b0: float = g.sim.bearing
			for i in 60:
				g.sim.set_wheel(1.0)
				await physics_frame
			g.sim.set_wheel(0.0)
			var turned := rad_to_deg(absf(angle_difference(b0, g.sim.bearing)))
			state_ok = turned > 5.0
			state_note = "bearing turned %.1f deg in 1 s (A/D in the console view drives the same set_wheel)" % turned
			sound_expected = false                    # motor/hum loops, no one-shot
		"doc":
			sound_expected = false
			var snd_before := _audio_count()
			g._on_doc(dev)
			await _frames(2)
			var opened: bool = g.presenter.is_document_open()
			var hinted: bool = not opened and g.presenter.hint.text != ""
			var doc_sound := _audio_count() > snd_before
			for i in 3:                               # E closes; some documents chain (1953 log -> clipping)
				if not g.presenter.is_document_open():
					break
				var e := InputEventKey.new()
				e.keycode = KEY_E
				e.physical_keycode = KEY_E
				e.pressed = true
				Input.parse_input_event(e)
				await _frames(3)
				var u := e.duplicate()
				u.pressed = false
				Input.parse_input_event(u)
				await _frames(3)
			var closed: bool = not g.presenter.is_document_open() and g.player.enabled
			state_ok = (opened or hinted) and closed
			state_note = "%s, closed with E and control returned=%s" % ["document opened" if opened else ("hint shown (chapter-gated)" if hinted else "NOTHING happened"), closed]
			_row(ws, dev, "sound", "PASS" if doc_sound else "WARN", "paper sound on open" if doc_sound else "no sound when a document opens (logged for Stage 5)")
		"door":
			g._on_doc("door")                         # bolted: a hint, no state change by design
			var hint_ok: bool = g.presenter.hint.text != ""
			g._on_story_event("door_open", [])        # the ch4 story path opens it
			state_ok = hint_ok and g.station.door_open
			state_note = "bolted hint=%s, story open=%s" % [hint_ok, g.station.door_open]
	var snd1 := _audio_count()
	await _frames(60)
	var pose1 := _pose(dev)
	_row(ws, dev, "state", "PASS" if state_ok else "FAIL", state_note)
	if sound_expected:
		_row(ws, dev, "sound", "PASS" if snd1 > snd0 else "FAIL", "audio players %d -> %d" % [snd0, snd1])
	elif kind == "doc":
		pass                                      # reported above
	else:
		_row(ws, dev, "sound", "N/A", "no one-shot for %s" % kind)
	if PART.has(dev):
		_row(ws, dev, "part", "PASS" if _moved(pose0, pose1) else "FAIL", "%s moved" % PART[dev] if _moved(pose0, pose1) else "%s did not move" % PART[dev])
	else:
		_row(ws, dev, "part", "N/A", "no moving part (%s)" % kind)
	# tidy up so the next device starts from a sane state
	if kind == "hold":
		_use(dev, "release")
	if kind == "focus":
		g.player.leave_focus()
		await _frames(30)


# ------------------------------------------------------------------ #8 save / load

## Wait until the given parts stop moving (eased animations; the door swings over ~3 s).
func _settle(devs: Array) -> void:
	var prev := {}
	for i in 600:
		await physics_frame
		var still := true
		for dev in devs:
			var p := _pose(dev)
			# much tighter than _moved(): eased parts move <0.02 rad per frame while still swinging
			if prev.has(dev) and (p.origin.distance_to(prev[dev].origin) > 0.0001 or p.basis.get_rotation_quaternion().angle_to(prev[dev].basis.get_rotation_quaternion()) > 0.0005):
				still = false
			prev[dev] = p
		if still and i > 10:
			return

func _save_roundtrip() -> void:
	print("SAVE/LOAD round trip")
	# a deliberately non-default station
	g._route(g.sim.set_fuel_valve(true))
	g._route(g.sim.set_breaker("radar", false))
	g._route(g.sim.set_charge(true))
	g._route(g.sim.set_mode(KeeperSim.Mode.MANUAL))
	g._route(g.sim.set_intensity(2))
	g.station.door_open = true
	await _frames(90)
	var want := {}
	var poses := {}
	for dev in ["fuel_valve", "brk_main", "brk_lights", "brk_radar", "charge", "mode", "intensity"]:
		want[dev] = g.station.DEVICES[dev]["get"].call(g.sim)
	for dev in ["fuel_valve", "brk_radar", "charge", "mode", "intensity", "door"]:
		poses[dev] = _pose(dev)
	# A load re-enters the saved beat and re-runs its actions (by design: saves are only taken between
	# beats). Ch1 beat 0 sets mode/intensity to 0, so save from a beat that does not touch the station.
	var beats: Array = g.director.chapter_data(g.director.state.chapter)["beats"]
	for i in range(1, beats.size()):
		var touches := false
		for a in beats[i].get("do", []):
			if String(a[0]) in ["mode", "intensity", "breaker", "fuel", "charge", "battery", "fault", "door"]:
				touches = true
		if not touches:
			g.director.state.beat = i
			break
	await _settle(["fuel_valve", "brk_radar", "charge", "mode", "intensity", "door"])
	for dev in poses:
		poses[dev] = _pose(dev)
	var save: Dictionary = g.save_dict()
	var g2 := await _new_game(save)
	var old := g
	g = g2
	await _settle(poses.keys())
	for dev in want:
		var got = g.station.DEVICES[dev]["get"].call(g.sim)
		_row("save", dev, "state", "PASS" if got == want[dev] else "FAIL", "want %s got %s" % [want[dev], got])
	_row("save", "door", "state", "PASS" if g.station.door_open else "FAIL", "door_open=%s" % g.station.door_open)
	for dev in poses:
		var same := not _moved(poses[dev], _pose(dev))
		_row("save", dev, "part", "PASS" if same else "FAIL", "pose restored" if same else "pose differs after load")
	old.queue_free()
