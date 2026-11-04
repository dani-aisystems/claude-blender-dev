extends Node
## THE LAST LIGHT v2 root: title screen over a live exterior shot of the lighthouse, then the
## first-person night. CLI (after --):
##   --seed=N  --windowed  --bot=expert|novice|idle
##   --capture=NAME --shots=menu,30@player,60@fp_desk,...   (see capture_fp.gd)
##   --autotest=SECONDS [--autotest-out=PATH]

const GAME := preload("res://scripts/fp/game_fp.gd")

var game: Node3D
var menu_bg: Node3D
var menu: CanvasLayer
var howto: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args: Dictionary = GameState.user_args
	if args.has("windowed") or args.has("capture") or args.has("autotest"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		DisplayServer.window_set_position(DisplayServer.screen_get_usable_rect().position + Vector2i(10, 10))
	if args.has("scale3d"):
		get_viewport().scaling_3d_scale = float(args["scale3d"])
	if args.has("msaa0"):
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	if args.has("capture"):
		var cap := preload("res://scripts/capture_fp.gd").new()
		cap.main = self
		add_child(cap)
		show_menu()
	elif args.has("autotest"):
		var at := preload("res://scripts/autotest.gd").new()
		at.main = self
		add_child(at)
		start_game(args.get("bot", "expert"))
	else:
		show_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and game and get_tree().paused:
		game.set_paused(false)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _clear() -> void:
	get_tree().paused = false
	for n in [game, menu_bg, menu]:
		if n and is_instance_valid(n):
			n.queue_free()
	game = null
	menu_bg = null
	menu = null
	howto = null


func show_menu() -> void:
	_clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_bg = GAME.new()
	add_child(menu_bg)
	menu_bg.start(GameState.next_seed(), "expert", true)
	menu = CanvasLayer.new()
	add_child(menu)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.01, 0.02, 0.25)
	root.add_child(shade)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	col.offset_left = 130
	col.offset_top = -250
	col.add_theme_constant_override("separation", 16)
	root.add_child(col)
	col.add_child(UIStyle.label("THE LAST LIGHT", 96, UIStyle.INK, UIStyle.serif()))
	col.add_child(UIStyle.label("North Point Light · 02:17 · a gale from the north-west", 26, UIStyle.AMBER, UIStyle.serif()))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 36)
	col.add_child(sp)
	var start := UIStyle.button("Begin the watch")
	start.pressed.connect(func(): start_game(""))
	col.add_child(start)
	var how := UIStyle.button("How to keep the light")
	how.pressed.connect(_toggle_howto.bind(root))
	col.add_child(how)
	var quit := UIStyle.button("Quit")
	quit.pressed.connect(func(): get_tree().quit())
	col.add_child(quit)
	if GameState.games_played > 0:
		col.add_child(UIStyle.label("Best this session: %d" % GameState.best_score, 20, UIStyle.DIM))
	start.grab_focus.call_deferred()


func _toggle_howto(root: Control) -> void:
	if howto and is_instance_valid(howto):
		howto.queue_free()
		howto = null
		return
	howto = PanelContainer.new()
	howto.add_theme_stylebox_override("panel", UIStyle.panel_box(0.92))
	howto.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	howto.offset_left = -860
	howto.offset_right = -110
	howto.offset_top = -340
	howto.offset_bottom = 340
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	howto.add_child(v)
	v.add_child(UIStyle.label("Keeping the light", 40, UIStyle.AMBER, UIStyle.serif()))
	for line in [
		"WASD walk · mouse look · E or left click to use · Shift walk faster · L logbook · Esc step back / pause",
		"Ships call you on the radio (desk, under the windows). Find them on the radar, CONFIRM their position, and turn them 30° at a time until they're inbound on a channel: West Gut 314°, North Sound 000°, East Gut 046°.",
		"A ship has to SEE the light to find the channel. In thick weather turn the lamp to HIGH, or switch to MANUAL and hold the beam on her with the handwheel.",
		"Everything runs off the battery. Start the generator in the cage (open the FUEL VALVE, hold START) and switch CHARGE on at the west wall. Watch the engine TEMP.",
		"If the motor jams, turn MODE to OFF and back on. If MAIN trips, reset it at the distribution cabinet.",
		"Lose three ships and the night is lost. Keep the light until dawn.",
	]:
		var l := UIStyle.label(line, 21)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(700, 0)
		v.add_child(l)
	root.add_child(howto)


func start_game(bot_mode: String) -> void:
	_clear()
	game = GAME.new()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	if bot_mode == "" and GameState.user_args.has("bot"):
		bot_mode = GameState.user_args["bot"]
	game.start(GameState.next_seed(), bot_mode, false)
	game.finished.connect(_on_finished)
	game.quit_to_menu.connect(show_menu)


func _on_finished(stats: Dictionary) -> void:
	if stats.has("restart"):
		start_game("")
		return
	var best := GameState.record_result(stats)
	if game:
		game.show_end(stats, best)
