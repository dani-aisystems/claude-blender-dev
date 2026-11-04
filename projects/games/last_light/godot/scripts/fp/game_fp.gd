extends Node3D
## One night at North Point: owns KeeperSim and wires the room (station), the world outside,
## the first-person keeper, the radar screen and the UI. Bot-driven when `bot_mode` is set
## (menu attract camera, screenshot capture, the exported-app autotest).

signal finished(stats: Dictionary)
signal quit_to_menu

var sim := KeeperSim.new()
var station: Node3D
var outside: Node3D
var player: CharacterBody3D
var ui: CanvasLayer
var radar_vp: SubViewport
var bot: KeeperBot2
var bot_mode := ""
var attract := false
var cine_cam: Camera3D
var _cine_t := 0.0
var _ended := false
var _paused := false


func start(seed_value: int, mode := "", attract_mode := false) -> void:
	bot_mode = mode
	attract = attract_mode
	var night: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/night.json"))
	sim.setup(KeeperConfig.new(), LayoutData.load_file(), night, seed_value)
	if bot_mode != "":
		bot = KeeperBot2.new(bot_mode, seed_value)
	radar_vp = SubViewport.new()
	radar_vp.size = Vector2i(512, 512)
	radar_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if GameState.user_args.has("noradar") else SubViewport.UPDATE_ALWAYS
	radar_vp.transparent_bg = false
	var scope := preload("res://scripts/fp/radar.gd").new()
	scope.sim = sim
	radar_vp.add_child(scope)
	add_child(radar_vp)
	outside = preload("res://scripts/fp/outside.gd").new()
	add_child(outside)
	outside.setup(sim)
	station = preload("res://scripts/fp/station.gd").new()
	station.radar_tex = radar_vp.get_texture()
	add_child(station)
	station.setup(sim)
	if attract:
		cine_cam = Camera3D.new()
		cine_cam.fov = 50.0
		cine_cam.far = 2000.0
		add_child(cine_cam)
		cine_cam.current = true
		return
	player = preload("res://scripts/fp/player.gd").new()
	player.station = station
	add_child(player)
	player.place(station.spawn, Vector3.ZERO)
	ui = preload("res://scripts/fp/fp_ui.gd").new()
	ui.sim = sim
	add_child(ui)
	player.prompt_changed.connect(ui.set_prompt)
	player.focus_changed.connect(ui.set_focus)
	player.events.connect(_route)
	player.logbook_requested.connect(func():
		var open: bool = ui.toggle_logbook()
		player.enabled = not open
		player.capture_mouse(not open and player.focused == ""))
	ui.command_requested.connect(func(id, cmd): _route(sim.command(id, cmd)))
	ui.resume_requested.connect(func(): set_paused(false))
	ui.restart_requested.connect(func(): finished.emit({"restart": true}))
	ui.menu_requested.connect(func(): quit_to_menu.emit())
	if bot_mode == "":
		player.capture_mouse(true)


func _unhandled_input(event: InputEvent) -> void:
	if attract or _ended or player == null:
		return
	if event.is_action_pressed("pause"):
		if ui.logbook.visible:
			ui.toggle_logbook()
			player.enabled = true
			player.capture_mouse(player.focused == "")
		elif player.focused != "":
			player.leave_focus()
		else:
			set_paused(not _paused)
		get_viewport().set_input_as_handled()


func set_paused(p: bool) -> void:
	_paused = p
	get_tree().paused = p
	ui.show_pause(p)
	player.capture_mouse(not p and player.focused == "")


func _physics_process(delta: float) -> void:
	if _ended:
		return
	if bot:
		_route(bot.act(sim, delta))
	_route(sim.step(delta))


func _route(events: Array) -> void:
	if events.is_empty():
		return
	station.on_events(events)
	outside.on_events(events)
	if ui:
		_ui_events(events)
	for e in events:
		if e["type"] in ["game_won", "game_lost"] and not _ended:
			_ended = true
			_finish.call_deferred()


func _ui_events(events: Array) -> void:
	for e in events:
		match e["type"]:
			"radio":
				ui.add_subtitle(e["from"], e["text"], false)
			"tx":
				ui.add_subtitle("North Point", e["text"], true)
			"radio_busy":
				ui.show_notice("Still transmitting…", 1.5)
			"radio_dead":
				ui.show_notice("The radio is dead: no power.", 2.5)
			"gen_start":
				ui.show_notice("The generator catches and settles into a rumble.")
			"gen_crank_fail":
				ui.show_notice("It turns over but won't catch. Is the fuel valve open?" if e["why"] == "valve" else "Out of diesel.")
			"gen_too_hot":
				ui.show_notice("The engine is still too hot to restart.")
			"gen_hot":
				ui.show_notice("Generator running hot. Switch charging off for a while.")
			"gen_overheat":
				ui.show_notice("The generator cuts out: overheated.", 5.0)
			"gen_stop":
				ui.show_notice("The generator winds down.", 2.5)
			"battery_low":
				ui.show_notice("Battery below a quarter.", 4.0)
			"battery_dead":
				ui.show_notice("The batteries are flat. Everything goes dark.", 6.0)
			"brownout":
				ui.show_notice("The lights dip: the main circuit is overloaded!", 3.0)
			"breaker_trip":
				ui.show_notice("MAIN breaker tripped" + (" by the jammed motor!" if e["cause"] == "motor" else ": overload!"), 5.0)
			"jam":
				ui.show_notice("A grinding shudder from above: the rotation motor has jammed.", 5.0)
			"jam_cleared":
				ui.show_notice("The motor frees with a clunk.", 3.0)
			"logbook":
				ui.show_notice("New entry in the keeper's log  (L)", 4.0)
			"ship_saved":
				ui.show_notice("%s is safe. +%d" % [e["name"], e["points"]], 4.0)
			"ship_lost":
				ui.show_notice("%s has struck the rocks." % e["name"], 6.0)


func _finish() -> void:
	var st := sim.stats()
	await get_tree().create_timer(4.0).timeout
	finished.emit(st)


func _process(delta: float) -> void:
	if attract and cine_cam:
		_cine_t += delta
		var a := _cine_t * 0.05 + 2.4
		var r := 46.0 + 6.0 * sin(_cine_t * 0.07)
		cine_cam.position = Vector3(sin(a) * r, 15.0 + 3.0 * sin(_cine_t * 0.05), cos(a) * r)
		cine_cam.look_at(Vector3(0, 19.5, 0), Vector3.UP)


func show_end(stats: Dictionary, best: bool) -> void:
	if ui:
		player.enabled = false
		player.capture_mouse(false)
		ui.show_end(stats, best)
