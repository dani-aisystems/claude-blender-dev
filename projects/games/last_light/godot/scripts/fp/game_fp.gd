extends Node3D
## One session at North Point. Two modes:
##   story (default): the six-chapter campaign driven by StoryDirector (data/story/*)
##   watch: the v2 free night (data/night.json) - kept for the bot sims and attract shots
## Wires KeeperSim, the room (station), the world outside, the keeper, the radar, the HUD and the
## story presentation. Bot-driven when bot_mode is set (menu attract, captures, autotest).

signal finished(stats: Dictionary)
signal quit_to_menu
signal campaign_over(ending: Dictionary)

var sim := KeeperSim.new()
var station: Node3D
var outside: Node3D
var player: CharacterBody3D
var ui: CanvasLayer
var radar_vp: SubViewport
var radar: Control
var bot: KeeperBot2
var bot_mode := ""
var attract := false
var story_mode := false
var director: StoryDirector
var presenter: CanvasLayer
var audio: Node
var visitor_fig: Node3D
var cine_cam: Camera3D
var _cine_t := 0.0
var _ended := false
var _paused := false
var backlog: Control                       # Stage 3A dialogue history (story mode)
var _backlog_from_pause := false
var _backlog_focus: Control = null
var _moved := 0.0
var _looked := 0.0
var _last_yaw := 0.0
var _last_pos := Vector3.ZERO
var _story_flags_t := 0.0


func start(seed_value: int, mode := "", attract_mode := false, story := false, save: Dictionary = {}) -> void:
	bot_mode = mode
	attract = attract_mode
	story_mode = story
	var night: Dictionary = {"ships": [], "faults": []} if story else JSON.parse_string(FileAccess.get_file_as_string("res://data/night.json"))
	sim.setup(KeeperConfig.new(), LayoutData.load_file(), night, seed_value)
	sim.story_mode = story
	if bot_mode != "":
		bot = KeeperBot2.new(bot_mode, seed_value)
	radar_vp = SubViewport.new()
	radar_vp.size = Vector2i(512, 512)
	radar_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	radar = preload("res://scripts/fp/radar.gd").new()
	radar.sim = sim
	radar_vp.add_child(radar)
	add_child(radar_vp)
	outside = preload("res://scripts/fp/outside.gd").new()
	add_child(outside)
	outside.setup(sim)
	station = preload("res://scripts/fp/station.gd").new()
	station.radar_tex = radar_vp.get_texture()
	add_child(station)
	station.setup(sim)
	station.outside = outside          # window lights follow the storm, dawn and lightning
	audio = preload("res://scripts/audio_director.gd").new()
	add_child(audio)
	audio.setup(sim, station)
	if attract:
		cine_cam = Camera3D.new()
		cine_cam.fov = 50.0
		cine_cam.far = 2000.0
		add_child(cine_cam)
		cine_cam.current = true
		audio.set_menu(true)
		outside.attract = true
		return
	player = preload("res://scripts/fp/player.gd").new()
	player.station = station
	add_child(player)
	player.place(station.spawn, Vector3.ZERO)
	ui = preload("res://scripts/fp/fp_ui.gd").new()
	ui.sim = sim
	add_child(ui)
	player.prompt_changed.connect(ui.set_prompt)
	player.pressed.connect(ui.pulse)
	ui.cursor_fn = player.cursor_pos
	player.gui_click_fn = ui.click_at
	player.vessel_cycle_fn = ui.cycle_vessel
	station.docs_enabled = story_mode          # documents and the door's story lines exist only in the campaign
	station.door_usable = story_mode
	player.focus_changed.connect(ui.set_focus)
	player.focus_changed.connect(func(_id): refresh_mouse())
	player.events.connect(_route)
	player.logbook_requested.connect(_toggle_logbook)
	player.doc_requested.connect(_on_doc)
	ui.command_requested.connect(func(id, cmd): _route(sim.command(id, cmd)))
	ui.resume_requested.connect(func(): set_paused(false))
	ui.restart_requested.connect(func(): finished.emit({"restart": true}))
	ui.menu_requested.connect(func(): quit_to_menu.emit())
	ui.save_requested.connect(_manual_save)
	ui.backlog_requested.connect(func(): open_backlog(true))
	if story_mode:
		_setup_story(save)
	if bot_mode == "":
		refresh_mouse()


# ------------------------------------------------------------------ story

func _setup_story(save: Dictionary) -> void:
	director = StoryDirector.new()
	add_child(director)
	director.setup(sim, bot_mode != "")
	if GameState.user_args.has("capture"):
		director.bot_line_s = 2.6
		director.bot_wait_mul = 1.0
	presenter = preload("res://scripts/story/story_presenter.gd").new()
	add_child(presenter)
	presenter.bind(director)
	director.presenter_driven = true          # 3B: chapter changes and time skips wait for the fades
	presenter.dialogue.at_radio_fn = _at_radio
	presenter.dialogue.mouse_restore_fn = refresh_mouse
	presenter.dialogue.in_view_fn = func(): return player != null and player.focused != ""
	presenter.dialogue.doc_open_fn = presenter.is_document_open
	ui.number_keys_taken_fn = func(): return presenter.dialogue.has_open_choices() or presenter.is_document_open()
	ui.reply_root_fn = func(): return presenter.dialogue.choice_box
	ui.optional_calls_fn = func(): return director.available_calls()
	ui.call_requested.connect(func(cid):
		if director.request_call(cid):
			ui._refresh_calls())
	presenter.dialogue.apply_settings(Settings.v["text_speed"], Settings.v["subtitle_size"])
	Settings.changed.connect(_on_settings_changed)     # method (not lambda): auto-disconnects when freed
	presenter.dialogue.blip.connect(func(kind): audio.ui_blip(kind))
	presenter.document_closed.connect(_on_doc_closed)
	backlog = preload("res://scripts/ui/backlog_ui.gd").new()
	backlog.chapter_title_fn = func(n): return String(director.chapter_data(n).get("title", ""))
	backlog.close_requested.connect(close_backlog)
	ui.add_child(backlog)                  # fp_ui processes during pause; drawn above the pause menu
	director.story_event.connect(_on_story_event)
	director.request_autosave.connect(func(): autosave())
	director.campaign_finished.connect(_on_campaign_finished)
	director.line_shown.connect(func(item): audio.on_line(item))
	if not save.is_empty():
		_apply_save(save)
		director.begin(false)
	else:
		director.begin(true)


func _at_radio() -> bool:
	if player == null:
		return true
	if player.focused == "radio":
		return true
	var f: Dictionary = station.focus.get("radio", {})
	return f.has("at") and player.global_position.distance_to(Vector3(f["at"].x, player.global_position.y, f["at"].z)) < 1.7


func _on_story_event(name_: String, args: Array) -> void:
	match name_:
		"sim_events":
			_route(args[0])
		"hint":
			presenter.show_hint(args[0])
		"timeskip":
			pass                                  # 3B: the presenter runs it as a transition (transition_requested)
		"caption":
			presenter.show_caption(args[0])
		"ending_card":
			player.enabled = false
			ui.clear_prompt()
			refresh_mouse()
			presenter.show_ending(args[0], args[1], args[2])
		"sky":
			outside.set_sky(args[0])
		"phantom_echo":
			radar.phantom = {"bearing": deg_to_rad(float(args[0])), "range": float(args[1]), "until": radar_time() + float(args[2])}
		"door_open":
			station.door_open = true
			audio.sfx_at("door_heavy", station.door_position())
		"visitor_enter":
			_spawn_visitor()
		"knock":
			audio.knock(station.door_position())
		"footsteps":
			audio.footsteps(args[0], station.door_position())
		"sfx", "static", "music":
			audio.story_cue(name_, args)
		_:
			push_warning("story: unhandled presentation event '%s'" % name_)   # story_test keeps the data clean


func radar_time() -> float:
	return sim.t


func _spawn_visitor() -> void:
	if visitor_fig:
		return
	visitor_fig = preload("res://scripts/fp/visitor_figure.gd").new()
	add_child(visitor_fig)
	for vi in visitor_fig.find_children("*", "VisualInstance3D", true, false):
		(vi as VisualInstance3D).layers = station.LAYER_INTERIOR   # lit by the room, not the lantern
	var dp: Vector3 = station.door_position()
	var to_center := Vector3(-dp.x, 0, -dp.z).normalized()
	visitor_fig.global_position = Vector3(dp.x, 20.0, dp.z) + to_center * 0.55 + to_center.cross(Vector3.UP) * -0.45
	visitor_fig.look_at(Vector3(0, 20.0, 0) + Vector3(0, 0, 0), Vector3.UP)


func _on_doc(id: String) -> void:
	if not story_mode:
		return
	var doc := ""
	match id:
		"logbook":
			doc = "log_1971"
		"photo":
			doc = "photo_keepers"
		"note":
			doc = "note_046"
		"forecast":
			doc = "forecast"
		"chart":
			doc = "chart"                      # cabin pass: full-screen chart inspection
		"coat_note":
			doc = "coat_note"                  # cabin pass: the stores note in the oilskin pocket
		"drawer":
			if director.state.chapter >= 5:
				doc = "letter_1957"
			else:
				presenter.show_hint("The bottom drawer. Old Notices to Mariners and a tin of pencils. I never go through it.")
		"archive":
			# 3B: the first open is the 1953 log (then the clipping); later opens alternate with the
			# Inquiry extract, the photostat Ross read in the Mitchell Library
			var st := director.state
			if not st.has_flag("read_log_1953") or st.has_flag("archive_flip"):
				doc = "log_1953"
				st.flags.erase("archive_flip")
			else:
				doc = "inquiry_extract"
				st.flags["archive_flip"] = 1
		"door":
			_use_door()
		"phone":
			var conv := "look_phone_ch4" if director.state.chapter == 4 and director.beat_reached("hail") else "look_phone"
			if not director.play_aside(conv):
				presenter.show_hint("The GPO line. Dead since the September gale.")
		"tide_tables":
			var st2 := director.state
			if not st2.has_flag("found_grants"):
				director.play_aside("look_grants_a")
			elif st2.clue("grants") and director.play_aside("look_grants_b"):
				pass
			else:
				presenter.show_hint("Admiralty Tide Tables, 1953. Father's Grant's behind them, still half full.")
		"vapour":
			var conv2 := "look_vapour_b" if director.state.clue("same_hand") else "look_vapour_a"
			if not director.play_aside(conv2):
				presenter.show_hint("The old vapour burner and its mantle, from before the electric.")
		"photo53", "photo53desk":
			doc = "photo_1953"
	if doc != "":
		player.enabled = false
		ui.clear_prompt()                   # the reading view has no crosshair target
		presenter.open_document(doc)
		director.state.flags["seen_" + doc] = 1


func _on_doc_closed(doc: String) -> void:
	match doc:
		"log_1971":
			director.on_player_event("read_log_1971")
		"log_1953":
			director.on_player_event("read_log_1953")
			director.state.clues["log_1953"] = true
			presenter.open_document("clipping_1954")
			return
		"letter_1957":
			director.on_player_event("read_letter")
	player.enabled = true
	refresh_mouse()
	var aside := director.after_read_conv(doc)      # 3B: a room line the first time it's read this chapter
	if aside != "":
		director.play_aside(aside)


## The stair door (3B). Before ch4 it gives the keeper's line; in ch4, from the moment the dark boat is
## alongside until the door scene, it can be bolted (the door conversation reads `bolted`).
func _use_door() -> void:
	var st := director.state
	if st.chapter < 4:
		presenter.show_hint("The stair door, and the long stair down. Nobody on it till the relief comes on Thursday.")
	elif _bolt_available():
		st.flags["bolted"] = 1
		director.play_aside("look_bolt")


func _bolt_available() -> bool:
	var st := director.state
	return st.chapter == 4 and not station.door_open and not st.has_flag("bolted") and director.beat_reached("hail") \
		and not director.is_talking() and not st.has_flag("door_shut")


func _toggle_logbook() -> void:
	if story_mode:
		_on_doc("logbook")
		return
	var open: bool = ui.toggle_logbook()
	player.enabled = not open
	refresh_mouse()


func _on_campaign_finished(ending: Dictionary) -> void:
	if _ended:
		return
	_ended = true
	SaveSystem.delete("auto")
	campaign_over.emit(ending)


# ------------------------------------------------------------------ save / load

func can_save() -> bool:
	return story_mode and director != null and director.can_manual_save() and not _ended


func save_dict() -> Dictionary:
	var c: Dictionary = director.chapter_data(director.state.chapter)
	return {"story": director.state.to_dict(), "sim": sim.to_dict(), "chapter_title": c.get("title", ""),
		"clock": sim.clock_text(),
		"player": {"pos": [player.global_position.x, player.global_position.y, player.global_position.z], "yaw": player._yaw, "pitch": player._pitch,
			"torch": player.torch_held, "torch_on": player.torch_light != null and player.torch_light.visible},
		"station": {"door_open": station.door_open, "visitor": visitor_fig != null}}


func _manual_save(slot: String) -> void:
	if not can_save():
		ui.show_notice("You can't save in the middle of a scene. Try again in a moment.", 3.0)
		return
	if SaveSystem.exists(slot) and not ui.has_meta("confirm_" + slot):
		ui.set_meta("confirm_" + slot, true)
		ui.show_notice("Slot %s already holds a save. Choose it again to overwrite." % slot, 3.5)
		return
	ui.remove_meta("confirm_" + slot)
	if SaveSystem.write(slot, save_dict()):
		ui.show_notice("Saved to slot %s." % slot, 2.5)
		set_paused(false)


func autosave() -> void:
	if story_mode and bot_mode == "" and director != null and director.can_autosave() and not _ended:
		SaveSystem.write("auto", save_dict())
		ui.show_notice("Progress saved.", 2.0)


func _apply_save(d: Dictionary) -> void:
	sim.from_dict(d["sim"])
	director.load_data(d["story"])
	var p: Dictionary = d.get("player", {})
	if p.has("pos"):
		player.global_position = Vector3(p["pos"][0], p["pos"][1], p["pos"][2])
		player._yaw = float(p.get("yaw", 0.0))
		player._pitch = float(p.get("pitch", 0.0))
		player._apply_look()
	if bool(p.get("torch", false)):               # cabin pass: the torch stays with the keeper
		player.give_torch(bool(p.get("torch_on", false)))
		station.set_torch_taken(true)
	var st: Dictionary = d.get("station", {})
	station.door_open = bool(st.get("door_open", false))
	if bool(st.get("visitor", false)):
		_spawn_visitor()
	for s in sim.ships:
		if s.is_active():
			outside.on_events([{"type": "ship_spawned", "ship": s.id, "name": s.name}])
	if director.state.chapter >= 4 or director.state.flags.has("dusk_done"):
		outside.set_sky("night")


# ------------------------------------------------------------------ loop

## Which device the player is using (Stage 2C): prompts and hints show its glyphs, and a gamepad gets
## the device-view cursor and focus on dialogue replies. Sticks count only past a clear deflection.
func _input(event: InputEvent) -> void:
	if InputSetup.pad_forced:
		return
	var pad := InputSetup.pad_active
	if event is InputEventJoypadButton and event.pressed:
		pad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.4:
		pad = true
	elif event is InputEventKey and event.pressed:
		pad = false
	elif event is InputEventMouseButton and event.pressed:
		pad = false
	elif event is InputEventMouseMotion and event.relative.length() > 2.0:
		pad = false
	if pad and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		InputSetup.pad_name = Input.get_joy_name(event.device)
	if pad != InputSetup.pad_active:
		InputSetup.pad_active = pad
		refresh_mouse()                       # pad: the OS pointer hides in views and replies; mouse: it returns
		if ui:
			ui._refresh_vessels()             # the Tab tip shows the right glyph
		if pad and presenter:
			presenter.dialogue.focus_first_choice()


func _unhandled_input(event: InputEvent) -> void:
	if attract or _ended or player == null:
		return
	if event.is_action_pressed("back") and ui.logbook.visible:     # pad B closes the logbook too
		ui.toggle_logbook()
		player.enabled = true
		refresh_mouse()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("history") and story_mode and presenter and not presenter.is_document_open() and not ui.logbook.visible:
		open_backlog(false)                   # H / View: the dialogue history (Stage 3A)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if presenter and presenter.is_document_open():
			return
		if ui.logbook.visible:
			ui.toggle_logbook()
			player.enabled = true
			refresh_mouse()
		elif player.focused != "":
			player.leave_focus()
		else:
			set_paused(not _paused)
		get_viewport().set_input_as_handled()


func set_paused(p: bool) -> void:
	if p and player:
		player.release_holds()             # the key-up would be lost under the pause menu
	if not p and backlog and backlog.visible:
		backlog.close()                    # resuming from anywhere also closes the history
	_paused = p
	get_tree().paused = p
	ui.show_pause(p, story_mode)
	refresh_mouse()


## The one place that decides whether mouse-look owns the cursor. Free-walk only: not for bots, and
## not while paused, in a device view, reading a document/logbook, or while dialogue choices are open.
func mouse_should_capture() -> bool:
	if player == null or attract or bot_mode != "":
		return false
	if _paused or player.focused != "" or ui.logbook.visible:
		return false
	if backlog and backlog.visible:
		return false                          # reading the dialogue history (it only exists while paused)
	if not player.enabled:
		return false                          # reading a document, the logbook or the end screen
	if presenter and presenter.is_document_open():
		return false
	# open replies no longer free the pointer in free walk (cabin pass, Daniel): mouse look stays on and
	# the replies are answered with the keys; in device views the pointer is already free
	return true


## The dialogue history (Stage 3A). It pauses the game, so the typewriter, the director and the station
## all stand still; closing restores exactly what was there: the pause menu (if it was opened from it)
## or play, the mouse through refresh_mouse(), and the reply highlight for the pad.
func open_backlog(from_pause: bool) -> void:
	if backlog == null or backlog.visible or _ended:
		return
	var fo := get_viewport().gui_get_focus_owner()
	_backlog_focus = fo if fo and presenter.dialogue.choice_box.is_ancestor_of(fo) else null
	_backlog_from_pause = from_pause and _paused
	if not _paused:
		set_paused(true)
	if ui.pause_panel:
		ui.pause_panel.visible = false
	backlog.open(director.state.history)
	refresh_mouse()


func close_backlog() -> void:
	if backlog == null or not backlog.visible:
		return
	backlog.close()
	if _backlog_from_pause and ui.pause_panel:
		ui.pause_panel.visible = true
		ui.focus_pause()
		refresh_mouse()
	else:
		set_paused(false)
	if not _paused and presenter.dialogue.has_open_choices():
		if is_instance_valid(_backlog_focus) and presenter.dialogue.choice_box.is_ancestor_of(_backlog_focus):
			_backlog_focus.grab_focus()
		else:
			presenter.dialogue.focus_first_choice()
	_backlog_focus = null


func _on_settings_changed() -> void:
	if presenter:
		presenter.dialogue.apply_settings(Settings.v["text_speed"], Settings.v["subtitle_size"])


func refresh_mouse() -> void:
	if player:
		player.capture_mouse(mouse_should_capture())


func _physics_process(delta: float) -> void:
	if _ended and not story_mode:
		return
	if bot:
		_route(bot.act(sim, delta))
	_route(sim.step(delta))
	if story_mode and player:
		_track_player(delta)


func _track_player(delta: float) -> void:
	_update_door_prompt()
	_update_story_props()
	if bot_mode != "":
		# bot-driven runs (captures/autotest): satisfy interaction objectives the way the headless test does
		for f in ["moved", "looked", "used_battery", "read_log_1971", "read_log_1953", "read_letter", "at_door", "at_radio"]:
			director.state.flags[f] = 1
		return
	var p := player.global_position
	_moved += Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length()
	_last_pos = p
	_looked += absf(wrapf(player._yaw - _last_yaw, -PI, PI))
	_last_yaw = player._yaw
	_story_flags_t -= delta
	if _story_flags_t > 0.0:
		return
	_story_flags_t = 0.2
	var st := director.state
	if _moved > 1.5:
		st.flags["moved"] = 1
	if _looked > 1.2:
		st.flags["looked"] = 1
	var dp: Vector3 = station.door_position()
	st.flags["at_door"] = 1 if Vector2(p.x - dp.x, p.z - dp.z).length() < 1.8 else st.flags.get("at_door_once", 0)
	if st.flags["at_door"] == 1:
		st.flags["at_door_once"] = 1
	st.flags["at_radio"] = 1 if _at_radio() else 0


## The keeper takes the torch from the storage shelf (only during a blackout: station.availability).
func _take_torch(on: bool) -> void:
	player.give_torch(on)
	station.set_torch_taken(true)
	if ui and Settings.tip_wanted("torch"):
		ui.show_notice("The keeper's torch.  %s switches it on and off." % InputSetup.key("torch"), 5.0)
		Settings.tip_used("torch")


## The stair door's prompt follows the story (Stage 2: it said "Bolted for the night" even after the
## ch4 door opened). Before ch4 pressing gives the keeper's line about the bolt; from ch4 the door is the
## story's to open (dialogue), so it is shown without a key.
## 3B: the 1953 photograph lies inside the stair door if Ross slid it under (door kept shut), or on the
## desk from chapter 5 if he came in and left it there.
func _update_story_props() -> void:
	var st := director.state
	var under := st.clue("photo_1953")
	var desk := not under and st.has_flag("door_open") and st.chapter >= 5
	if station.story_prop_shown("photo53") != under:
		station.set_story_prop("photo53", under)
	if station.story_prop_shown("photo53desk") != desk:
		station.set_story_prop("photo53desk", desk)


func _update_door_prompt() -> void:
	if station.door_open:
		station.door_prompt = "The stair door stands open"
		station.door_usable = false
	elif director and _bolt_available():
		station.door_prompt = "Draw the bolt on the stair door"
		station.door_usable = true
	elif director and director.state.has_flag("bolted") and director.state.chapter == 4:
		station.door_prompt = "The stair door  ·  bolted"
		station.door_usable = false
	elif director and director.state.chapter >= 4:
		station.door_prompt = "The stair door"
		station.door_usable = false
	else:
		station.door_prompt = "Try the stair door"
		station.door_usable = true


func _route(events: Array) -> void:
	if events.is_empty():
		return
	for e in events:
		if e["type"] == "pickup" and e.get("item", "") == "torch":
			_take_torch(true)
	station.on_events(events)
	outside.on_events(events)
	if audio:
		audio.on_events(events)
	if director:
		director.on_sim_events(events)
		for e in events:
			if e["type"] == "inspect":
				director.on_player_event("used_" + String(e["device"]))
	if ui:
		_ui_events(events)
	if not story_mode:
		for e in events:
			if e["type"] in ["game_won", "game_lost"] and not _ended:
				_ended = true
				_finish.call_deferred()


func _ui_events(events: Array) -> void:
	for e in events:
		match e["type"]:
			"radio":
				if not Settings.v["subtitles"]:
					continue
				if not story_mode or e.get("kind", "") in ["ack", "position", "lost_light", "has_light", "mayday", "piloting", "saved", "lost", "call", "recall"]:
					ui.add_subtitle(e["from"], e["text"], false)
			"tx":
				ui.add_subtitle("North Point", e["text"], true)
			"refused", "note":                  # Stage 2: a press that can't work says why, once
				var t: String = e.get("reason", e.get("text", ""))
				if t != "":
					ui.show_notice_once(t, 3.0)
			"radio_busy":
				ui.show_notice("Still transmitting…", 1.5)
			"radio_dead":
				ui.show_notice("The radio is dead: no power.", 2.5)
			"gen_crank_fail":
				ui.show_notice("It turns over but won't catch. Is the fuel valve open?" if e["why"] == "valve" else "Out of diesel.")
			"gen_too_hot":
				ui.show_notice("The engine is still too hot to restart.")
			"gen_hot":
				ui.show_notice("Generator running hot. Switch charging off for a while.")
			"gen_overheat":
				ui.show_notice("The generator cuts out: overheated.", 5.0)
			"battery_low":
				ui.show_notice("Battery below a quarter.", 4.0)
			"battery_dead":
				ui.show_notice("The batteries are flat. Everything goes dark.", 6.0)
			"brownout":
				ui.show_notice("The lights dip: the main circuit is overloaded!", 3.0)
			"breaker_trip":
				if e["cause"] != "story":
					ui.show_notice("MAIN breaker tripped" + (" by the jammed motor!" if e["cause"] == "motor" else ": overload!"), 5.0)
			"jam":
				if not story_mode:
					ui.show_notice("A grinding shudder from above: the rotation motor has jammed.", 5.0)
			"logbook":
				ui.show_notice("New entry in the keeper's log  (%s)" % InputSetup.glyph("logbook"), 4.0)
			"ship_saved":
				if not story_mode:
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
		# slow push-in on the lighthouse from the sea (menu)
		var a := 2.75 + 0.03 * sin(_cine_t * 0.05)
		var r := 120.0 - 10.0 * sin(_cine_t * 0.03)
		cine_cam.position = Vector3(sin(a) * r, 9.0 + 1.5 * sin(_cine_t * 0.11), cos(a) * r - 40.0)
		cine_cam.look_at(Vector3(0, 17.0, 0), Vector3.UP)
		cine_cam.rotation.z = 0.004 * sin(_cine_t * 0.7)


func show_end(stats: Dictionary, best: bool) -> void:
	if ui:
		player.enabled = false
		refresh_mouse()
		ui.show_end(stats, best)
