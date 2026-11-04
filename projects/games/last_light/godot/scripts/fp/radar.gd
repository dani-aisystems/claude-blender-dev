extends Control
## PPI radar scope drawn into a SubViewport; the texture lights SCR_radar on the desk.
## Shows reef clutter, channel leading lines, ship echoes (refreshed as the sweep passes),
## labels for ships that confirmed their position, and the lighthouse beam bearing.

const RANGE_M := 250.0
const SWEEP_S := 2.4

var sim: KeeperSim
var _sweep := 0.0
var _echoes := {}          # ship id -> {pos, age, label}
var _font: Font


func _ready() -> void:
	custom_minimum_size = Vector2(512, 512)
	size = Vector2(512, 512)
	_font = UIStyle.sans()


func _process(delta: float) -> void:
	var _pt := Time.get_ticks_usec()
	_process_body(delta)
	GameState.prof_add("radar", Time.get_ticks_usec() - _pt)


func _process_body(delta: float) -> void:
	if sim == null:
		return
	var prev := _sweep
	_sweep = fmod(_sweep + delta / SWEEP_S * TAU, TAU)
	if sim.radar_on():
		for s in sim.ships:
			if not s.is_active():
				continue
			var b := fposmod(Geo.bearing_of(s.pos), TAU)
			var crossed := (prev <= _sweep and b > prev and b <= _sweep) or (prev > _sweep and (b > prev or b <= _sweep))
			if crossed:
				_echoes[s.id] = {"pos": s.pos, "age": 0.0, "label": s.name if s.labelled else "", "piloting": s.state == FleetShip.State.PILOTING}
	for id in _echoes.keys():
		_echoes[id]["age"] += delta
		var s := sim.find_ship(id)
		if _echoes[id]["age"] > SWEEP_S * 2.5 or s == null or not s.is_active():
			_echoes.erase(id)
	queue_redraw()


func _p(world: Vector2) -> Vector2:
	return Vector2(256, 256) + world / RANGE_M * 240.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0))
	if sim == null or not sim.radar_on():
		return
	var g := Color(0.25, 1.0, 0.45)
	draw_circle(Vector2(256, 256), 246, Color(0.01, 0.06, 0.03))
	for r in [50.0, 100.0, 150.0, 200.0, 250.0]:
		draw_arc(Vector2(256, 256), r / RANGE_M * 240.0, 0, TAU, 64, Color(g, 0.18), 1.0, true)
	for deg in range(0, 360, 30):
		var d := Geo.dir(deg_to_rad(deg))
		draw_line(_p(d * 20.0), _p(d * RANGE_M), Color(g, 0.08), 1.0)
		draw_string(_font, _p(d * 262.0) - Vector2(14, -6), "%03d" % deg, HORIZONTAL_ALIGNMENT_CENTER, 28, 14, Color(g, 0.45))
	# channel leading lines
	for c in sim.layout.channels:
		var d := Geo.dir(c["bearing"])
		for k in 9:
			var a := 40.0 + k * 13.0
			draw_line(_p(d * a), _p(d * (a + 7.0)), Color(1.0, 0.65, 0.25, 0.55), 2.0)
	# reef clutter (static echoes)
	for r in sim.layout.reefs:
		draw_circle(_p(r["pos"]), maxf(2.5, r["r"] / RANGE_M * 240.0), Color(g, 0.42))
	draw_circle(Vector2(256, 256), sim.layout.island_radius / RANGE_M * 240.0, Color(g, 0.6))
	# beam bearing (amber) when the lamp is lit
	if sim.lamp_on():
		var bd := Geo.dir(sim.bearing)
		draw_line(_p(Vector2.ZERO), _p(bd * sim.vis_range() * (sim.cfg.focus_mul if sim.mode == KeeperSim.Mode.MANUAL else 1.0)), Color(1.0, 0.7, 0.3, 0.7), 2.0)
	# sweep with afterglow
	for k in 24:
		var a := _sweep - k * 0.03
		draw_line(_p(Vector2.ZERO), _p(Geo.dir(a) * RANGE_M), Color(g, 0.35 * (1.0 - k / 24.0)), 2.0)
	# ship echoes
	for id in _echoes:
		var e: Dictionary = _echoes[id]
		var fade := clampf(1.0 - e["age"] / (SWEEP_S * 2.5), 0.0, 1.0)
		var col := Color(0.6, 1.0, 0.7, fade) if not e["piloting"] else Color(0.6, 0.9, 1.0, fade)
		draw_circle(_p(e["pos"]), 6.0, col)
		var s := sim.find_ship(id)
		if s and e["label"] != "":
			draw_line(_p(e["pos"]), _p(e["pos"] + Geo.dir(s.heading) * 22.0), Color(col, fade * 0.8), 2.0)
			draw_string(_font, _p(e["pos"]) + Vector2(10, -8), e["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8, 1.0, 0.85, fade))
	draw_string(_font, Vector2(14, 28), "RANGE 250 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(g, 0.6))
