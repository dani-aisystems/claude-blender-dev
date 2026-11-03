extends Node
## Root: menu -> game -> end screen state machine, pause, fullscreen toggle,
## plus CLI-driven capture (--capture) and autotest (--autotest) modes.
##   --seed=N            fixed seed
##   --bot=expert|average|idle   bot plays instead of the keyboard
##   --capture=NAME --shots=20,90,200   screenshots to renders/last_light/NAME_*.png then quit
##   --autotest=SECONDS [--autotest-out=PATH]   bot plays, writes JSON, quits (exit 0 = ok)
##   --windowed          1920x1080 window instead of fullscreen

const WORLD_SCRIPT := preload("res://scripts/game_world.gd")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")

var world: Node3D
var hud: Control
var ui: CanvasLayer
var menu: Control
var howto: Control
var pause_panel: Control
var end_panel: Control
var backdrop: Node3D
var capture: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args: Dictionary = GameState.user_args
	if args.has("windowed") or args.has("capture") or args.has("autotest"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		var screen := DisplayServer.screen_get_usable_rect()
		DisplayServer.window_set_position(screen.position + Vector2i(20, 20))
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_build_menu()
	_show_menu()
	if args.has("capture"):
		capture = preload("res://scripts/capture.gd").new()
		capture.main = self
		add_child(capture)
	elif args.has("autotest"):
		var at := preload("res://scripts/autotest.gd").new()
		at.main = self
		add_child(at)
		start_game(args.get("bot", "average"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.is_action_pressed("pause") and world and end_panel == null:
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ menu

func _build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.03, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	col.offset_left = 140
	col.offset_top = -260
	col.add_theme_constant_override("separation", 18)
	menu.add_child(col)
	var title := UIStyle.label("THE LAST LIGHT", 96, UIStyle.INK, UIStyle.serif())
	col.add_child(title)
	col.add_child(UIStyle.label("One keeper. One lamp. One night of storm.", 26, UIStyle.AMBER, UIStyle.serif()))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	col.add_child(spacer)
	var start := UIStyle.button("Start the Night")
	start.pressed.connect(func(): start_game(""))
	col.add_child(start)
	var how := UIStyle.button("How to Play")
	how.pressed.connect(_toggle_howto)
	col.add_child(how)
	var quit := UIStyle.button("Quit")
	quit.pressed.connect(func(): get_tree().quit())
	col.add_child(quit)
	var best := UIStyle.label("", 20, UIStyle.DIM)
	best.name = "Best"
	col.add_child(best)
	start.grab_focus.call_deferred()


func _toggle_howto() -> void:
	if howto:
		howto.queue_free()
		howto = null
		return
	howto = PanelContainer.new()
	howto.add_theme_stylebox_override("panel", UIStyle.panel_box(0.9))
	howto.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	howto.offset_left = -820
	howto.offset_right = -120
	howto.offset_top = -300
	howto.offset_bottom = 300
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	howto.add_child(v)
	v.add_child(UIStyle.label("How to keep the light", 40, UIStyle.AMBER, UIStyle.serif()))
	var lines := [
		"Ships are sailing blind toward the reef.",
		"A / D  or  ← / →   turn the lighthouse beam.",
		"Hold the beam on a ship. Its ring fills as the captain finds his bearings.",
		"A full ring turns the ship's lamp green: she is safe and steers for a channel.",
		"Unlit ships lose their bearings again and drift back toward the rocks.",
		"Red lamp = about to strike. Act now.",
		"SPACE  boosts the lamp: twice as fast, wider, farther, but it burns oil.",
		"Run dry and the boost is out until the oil recovers.",
		"Lose five ships and the night is lost. Keep the light until dawn.",
		"Esc pauses.   F11 toggles fullscreen.",
	]
	for l in lines:
		var lab := UIStyle.label(l, 22)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD
		lab.custom_minimum_size = Vector2(640, 0)
		v.add_child(lab)
	menu.add_child(howto)


func _show_menu() -> void:
	_clear_game()
	backdrop = WORLD_SCRIPT.new()
	add_child(backdrop)
	backdrop.start(GameState.next_seed(), "expert")   # attract mode behind the menu
	backdrop.finished.connect(func(_s): _show_menu())
	menu.visible = true
	var best: Label = menu.find_child("Best", true, false)
	if GameState.games_played > 0:
		best.text = "Best this session: %d  (%d ships guided home)" % [GameState.best_score, GameState.best_rescued]


func _clear_game() -> void:
	get_tree().paused = false
	for n in [world, backdrop, hud, pause_panel, end_panel]:
		if n and is_instance_valid(n):
			n.queue_free()
	world = null
	backdrop = null
	hud = null
	pause_panel = null
	end_panel = null


# ------------------------------------------------------------------ game

func start_game(bot_mode: String) -> void:
	_clear_game()
	if howto:
		howto.queue_free()
		howto = null
	menu.visible = false
	world = WORLD_SCRIPT.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	if bot_mode == "" and GameState.user_args.has("bot"):
		bot_mode = GameState.user_args["bot"]
	world.start(GameState.next_seed(), bot_mode)
	world.finished.connect(_on_finished)
	hud = HUD_SCRIPT.new()
	ui.add_child(hud)
	hud.setup(world)


func set_paused(p: bool) -> void:
	get_tree().paused = p
	if p and pause_panel == null:
		pause_panel = _modal("Paused", [["Resume", func(): set_paused(false)], ["Restart Night", func(): start_game("")], ["Main Menu", _show_menu]], "")
	elif not p and pause_panel:
		pause_panel.queue_free()
		pause_panel = null


func _on_finished(stats: Dictionary) -> void:
	var is_best := GameState.record_result(stats)
	var won: bool = stats["result"] == "won"
	var title := "Dawn breaks" if won else "The night is lost"
	var stars := ""
	if won:
		var pct := float(stats["rescued"]) / maxf(1.0, float(stats["ships_total"]))
		var n := 3 if pct >= 0.95 else (2 if pct >= 0.8 else 1)
		stars = "★".repeat(n) + "☆".repeat(3 - n)
	var body := "%s\n\nShips guided home   %d\nShips lost   %d\nBest streak   %d\nClose calls   %d\n\nScore   %d%s\nBest this session   %d" % [
		stars, stats["rescued"], stats["lost"], stats["best_streak"], stats["close_calls"], stats["score"],
		"   (new best!)" if is_best else "", GameState.best_score]
	if not won:
		body += "\n\nFive ships struck the reef before dawn."
	await get_tree().create_timer(2.5).timeout
	if world == null:
		return
	end_panel = _modal(title, [["Play Again", func(): start_game("")], ["Main Menu", _show_menu]], body)


func _modal(title: String, buttons: Array, body: String) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.02, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_box(0.9))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	var t := UIStyle.label(title, 64, UIStyle.AMBER, UIStyle.serif())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if body != "":
		var b := UIStyle.label(body, 26, UIStyle.INK, UIStyle.serif())
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(b)
	var first: Button = null
	for pair in buttons:
		var btn := UIStyle.button(pair[0])
		btn.pressed.connect(pair[1])
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(btn)
		if first == null:
			first = btn
	ui.add_child(root)
	first.grab_focus.call_deferred()
	return root
