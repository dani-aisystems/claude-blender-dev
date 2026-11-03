extends Node
## Screenshot driver (visual QA). Runs the real game with a bot at a fixed seed, fast-forwards
## between shots, and writes 1920x1080 PNGs to <workspace>/renders/last_light/.
##   --capture=NAME  --shots=menu,20,90,200,300,end  [--bot=expert] [--seed=7] [--speed=4]
## Also logs FPS while running at speed 1 (PERF lines) and prints CAPTURE_RESULT {json}.

var main: Node
var out_dir := ""
var results: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	out_dir = ProjectSettings.globalize_path("res://").path_join("../../../../renders/last_light").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var args: Dictionary = GameState.user_args
	var name_: String = args.get("capture", "shot")
	var shots: PackedStringArray = String(args.get("shots", "menu,20,90,200,end")).split(",")
	var speed := float(args.get("speed", "4"))
	Engine.max_physics_steps_per_frame = 24
	await _frames(40)
	for s in shots:
		if s == "menu":
			await _frames(30)
			_save(name_ + "_menu")
			continue
		if main.world == null:
			main.start_game(args.get("bot", "expert"))
			await _frames(5)
		if s == "end":
			Engine.time_scale = speed * 2.0
			while main.end_panel == null:
				await _frames(10)
			Engine.time_scale = 1.0
			await _frames(30)
			_save(name_ + "_end")
			continue
		if s.begins_with("lightning"):
			# wait for the next lightning flash and capture at its peak
			var got := [false]
			var cb := func(e): if e["type"] == "lightning": got[0] = true
			main.world.sim_event.connect(cb)
			Engine.time_scale = speed
			while not got[0]:
				await _frames(1)
			Engine.time_scale = 1.0
			await _frames(2)
			_save(name_ + "_" + s)
			main.world.sim_event.disconnect(cb)
			continue
		var target := float(s)
		Engine.time_scale = speed
		while main.world and main.world.sim.t < target - 1.0 and main.world.sim.result == SimWorld.Result.RUNNING:
			await _frames(1)
		Engine.time_scale = 1.0
		var fps := []
		for i in 60:
			await _frames(1)
			fps.append(Engine.get_frames_per_second())
		print("PERF t=%s fps=%s" % [s, fps[-1]])
		_save("%s_t%03d" % [name_, int(target)])
	print("CAPTURE_RESULT ", JSON.stringify({"files": results}))
	get_tree().quit(0)


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
