extends Control
## In-game HUD: energy, shift clock, rescued/lost, ship markers (bearings meter rings,
## off-screen arrows), tutorial prompts and floating feedback text.

var world  # game_world.gd
var _clock: Label
var _rescued: Label
var _lost_row: HBoxContainer
var _energy_bar: Control
var _prompt: Label
var _prompt_t := 0.0
var _floaters: Array = []          # {pos3: Vector3, text, color, age}
var _t := 0.0
var _tutorial := {"turn": false, "hold": false, "boost": false, "warning": false}
var _energy_low_flash := 0.0


func setup(w) -> void:
	world = w
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# top bar
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 36
	top.offset_right = -36
	top.offset_top = 24
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	left.add_child(UIStyle.label("LAMP OIL", 15, UIStyle.DIM))
	_energy_bar = Control.new()
	_energy_bar.custom_minimum_size = Vector2(340, 16)
	_energy_bar.draw.connect(_draw_energy)
	left.add_child(_energy_bar)
	top.add_child(left)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_BEGIN
	_clock = UIStyle.label("22:00", 40, UIStyle.INK, UIStyle.serif())
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_clock)
	var sub := UIStyle.label("KEEP THE LIGHT UNTIL DAWN", 13, UIStyle.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(sub)
	top.add_child(mid)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	_rescued = UIStyle.label("Guided home  0", 24, UIStyle.SAFE, UIStyle.serif())
	_rescued.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_rescued)
	_lost_row = HBoxContainer.new()
	_lost_row.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(_lost_row)
	top.add_child(right)
	# prompt
	_prompt = UIStyle.label("", 30, UIStyle.INK, UIStyle.serif())
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.offset_left = -700
	_prompt.offset_right = 700
	_prompt.offset_top = -150
	_prompt.offset_bottom = -100
	add_child(_prompt)
	world.sim_event.connect(_on_event)
	_refresh_lost()


func show_prompt(text: String, seconds: float = 5.0) -> void:
	_prompt.text = text
	_prompt_t = seconds


func _on_event(e: Dictionary) -> void:
	var sim: SimWorld = world.sim
	match e["type"]:
		"ship_spawned":
			if sim.ships_total() > 0 and e["id"] == 1:
				show_prompt("A ship in the storm.   A / D  or  ← / →  turn the light", 7.0)
		"ship_lit":
			if not _tutorial["hold"]:
				_tutorial["hold"] = true
				show_prompt("Hold the light on her until she finds her bearings", 5.0)
		"ship_locked":
			var s := sim.find_ship(e["id"])
			if s:
				_float(s.pos, "Bearings found" if not e["close_call"] else "Close call!", UIStyle.SAFE)
		"ship_rescued":
			var s := sim.find_ship(e["id"])
			if s:
				_float(s.pos, "+%d" % e["points"], UIStyle.SAFE)
			if e["id"] == 1 and not _tutorial["boost"]:
				_tutorial["boost"] = true
				show_prompt("Hold  SPACE  to boost the lamp: faster, wider, but it burns oil", 7.0)
		"ship_wrecked":
			_float(e["pos"], "Lost", UIStyle.DANGER)
			_refresh_lost()
		"ship_warning":
			if not _tutorial["warning"]:
				_tutorial["warning"] = true
				show_prompt("Red lamp: she's about to strike the reef!", 4.0)
		"energy_low":
			_energy_low_flash = 3.0
		"energy_depleted":
			show_prompt("The lamp is out of oil. Let it recover.", 3.5)
		"gust_warning":
			show_prompt("A squall is coming %s" % ("from the west" if e["dir"] > 0 else "from the east"), 3.0)


func _float(p: Vector2, text: String, color: Color) -> void:
	_floaters.append({"pos3": Geo.to_v3(p, 6.0), "text": text, "color": color, "age": 0.0})


func _refresh_lost() -> void:
	for c in _lost_row.get_children():
		c.queue_free()
	var sim: SimWorld = world.sim
	for i in sim.cfg.max_lost:
		var dot := UIStyle.label("●" if i < sim.lost else "○", 26, UIStyle.DANGER if i < sim.lost else UIStyle.DIM)
		_lost_row.add_child(dot)
	_lost_row.add_child(UIStyle.label("  lost", 18, UIStyle.DIM))


func _process(delta: float) -> void:
	_t += delta
	var sim: SimWorld = world.sim
	var minutes := int(lerpf(22.0 * 60.0, 29.0 * 60.0, sim.night_progress()))
	_clock.text = "%02d:%02d" % [(minutes / 60) % 24, minutes % 60]
	_rescued.text = "Guided home  %d" % sim.rescued
	_prompt_t -= delta
	_prompt.modulate.a = clampf(_prompt_t, 0.0, 1.0)
	_energy_low_flash = maxf(0.0, _energy_low_flash - delta)
	for f in _floaters:
		f["age"] += delta
	_floaters = _floaters.filter(func(f): return f["age"] < 2.2)
	_energy_bar.queue_redraw()
	queue_redraw()


func _draw_energy() -> void:
	var b: BeamModel = world.sim.beam
	var w := _energy_bar.size.x
	var h := _energy_bar.size.y
	_energy_bar.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.45))
	var frac := b.energy / b.cfg.energy_max
	var c := UIStyle.AMBER
	if b.locked_out:
		c = UIStyle.DANGER.darkened(0.3)
	elif frac < b.cfg.energy_low / b.cfg.energy_max:
		c = UIStyle.DANGER if fmod(_t, 0.5) < 0.25 or _energy_low_flash <= 0.0 else UIStyle.AMBER
	_energy_bar.draw_rect(Rect2(2, 2, (w - 4) * frac, h - 4), c)
	var resume := b.cfg.energy_lockout_resume / b.cfg.energy_max
	_energy_bar.draw_line(Vector2(w * resume, 0), Vector2(w * resume, h), Color(1, 1, 1, 0.25), 1.0)
	_energy_bar.draw_rect(Rect2(0, 0, w, h), UIStyle.LINE, false, 1.0)


## Ship markers: a ring around each active ship showing its bearings meter;
## arrows at the screen edge for ships out of view.
func _draw() -> void:
	var cam: Camera3D = world.camera
	if cam == null:
		return
	var vp := get_viewport_rect().size
	var font := UIStyle.sans()
	for s in world.sim.ships:
		if not s.is_active():
			continue
		var p3 := Geo.to_v3(s.pos, 4.0)
		var col := Color(1.0, 0.95, 0.85, 0.7)
		if s.state == ShipModel.State.LOCKED:
			col = UIStyle.SAFE
		elif s.warning:
			col = UIStyle.DANGER.lerp(Color.WHITE, 0.5 + 0.5 * sin(_t * 14.0))
		elif s.lit:
			col = UIStyle.AMBER
		var behind := cam.is_position_behind(p3)
		var sp := cam.unproject_position(p3)
		var margin := 40.0
		var on_screen := not behind and sp.x > margin and sp.x < vp.x - margin and sp.y > margin and sp.y < vp.y - margin
		if on_screen:
			if s.state == ShipModel.State.LOCKED:
				if s.seg >= 3:
					continue   # safely inside; stop cluttering the screen
				draw_arc(sp, 26.0, 0, TAU, 40, Color(col, 0.8), 3.0, true)
				continue
			var r: float = 22.0 + s.radius * 1.5
			draw_arc(sp, r, 0, TAU, 40, Color(0, 0, 0, 0.45), 6.0, true)
			if s.meter > 0.0:
				draw_arc(sp, r, -PI / 2, -PI / 2 + TAU * s.meter, 40, col, 4.0, true)
			else:
				draw_arc(sp, r, 0, TAU, 40, Color(col, 0.35), 2.0, true)
			if s.warning:
				draw_string(font, sp + Vector2(-6, -r - 10), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 30, col)
		elif s.state == ShipModel.State.SAILING:
			var center := vp * 0.5
			var dir := (sp - center).normalized()
			if behind:
				dir = -dir
			var edge := center + dir * minf((vp.x * 0.5 - 60.0) / maxf(absf(dir.x), 0.001), (vp.y * 0.5 - 60.0) / maxf(absf(dir.y), 0.001))
			var perp := Vector2(-dir.y, dir.x)
			var tip := edge + dir * 18.0
			draw_colored_polygon(PackedVector2Array([tip, edge - dir * 6 + perp * 14, edge - dir * 6 - perp * 14]), col)
	for f in _floaters:
		if cam.is_position_behind(f["pos3"]):
			continue
		var sp: Vector2 = cam.unproject_position(f["pos3"]) + Vector2(0, -40.0 - f["age"] * 30.0)
		var a := clampf(2.2 - f["age"], 0.0, 1.0)
		draw_string(UIStyle.serif(), sp + Vector2(-80, 0), f["text"], HORIZONTAL_ALIGNMENT_CENTER, 160, 30, Color(f["color"], a))
