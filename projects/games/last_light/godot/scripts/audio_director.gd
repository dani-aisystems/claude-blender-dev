extends Node
## Layered soundscape (all sounds synthesised by audio/synth.py).
##  Ambient (2D, storm-scaled): wind, rain on glass, sea.   Music bus: menu pad / tension drone.
##  Positional (3D) in the room: generator (cage), electrical hum (power cabinet), clockwork (optic drive),
##  radio static (desk speaker), motor grind (ceiling gear).  Events: thunder (delayed after the flash),
##  switches, breaker, crank, horns, squelch/typewriter blips, and the visitor's approach:
##  steps on the jetty -> the base door far below -> iron steps up the stair -> three knocks.

const A := "res://assets/audio/%s.wav"

var sim: KeeperSim
var station: Node3D
var loops := {}
var _streams := {}
var _menu := false
var _pending: Array = []        # [time, callable]
var _t := 0.0
var _static_t := 0.0
var _music: AudioStreamPlayer


func setup(k: KeeperSim, st: Node3D) -> void:
	sim = k
	station = st
	for n in ["amb_wind", "amb_rain", "amb_sea"]:
		loops[n] = _player2d(n, "Ambient", -8.0)
	_music = _player2d("music_menu", "Music", -6.0, false)
	loops["gen_idle"] = _player3d("gen_idle", _dev("IA_gen_panel", Vector3(-2.2, 20.6, 1.7)), 4.0)
	loops["hum"] = _player3d("hum", _dev("IA_power_panel", Vector3(-2.9, 21.2, 0.5)), 2.0)
	loops["clockwork"] = _player3d("clockwork", Vector3(1.9, 22.6, -1.9), 3.0)
	loops["static"] = _player3d("static", _dev("IA_radio", Vector3(0, 21.0, -2.8)), 2.0, "Dialogue")
	loops["motor_grind"] = _player3d("motor_grind", Vector3(0, 22.8, 0), 3.0)
	for n in ["gen_idle", "hum", "clockwork", "static", "motor_grind"]:
		loops[n].volume_db = -80.0
		loops[n].play()
	for n in ["amb_wind", "amb_rain", "amb_sea"]:
		loops[n].play()


func _dev(_name: String, fallback: Vector3) -> Vector3:
	return fallback


func _stream(n: String) -> AudioStream:
	if not _streams.has(n):
		var s: AudioStream = load(A % n)
		_streams[n] = s
	return _streams[n]


func _looped(n: String) -> AudioStream:
	var s: AudioStreamWAV = _stream(n).duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	return s


func _player2d(n: String, bus: String, db: float, loop := true) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _looped(n) if loop else _looped(n)
	p.bus = bus
	p.volume_db = db
	add_child(p)
	return p


func _player3d(n: String, pos: Vector3, unit: float, bus := "SFX") -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _looped(n)
	p.bus = bus
	p.unit_size = unit
	p.max_distance = 30.0
	add_child(p)
	p.global_position = pos
	return p


func set_menu(on: bool) -> void:
	_menu = on
	_music.stream = _looped("music_menu")
	_music.volume_db = -8.0
	_music.play()


## One-shot (2D unless pos given).
func sfx(n: String, db := 0.0, bus := "SFX") -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _stream(n)
	p.bus = bus
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func sfx_at(n: String, pos: Vector3, db := 0.0, unit := 3.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(n)
	p.bus = "SFX"
	p.volume_db = db
	p.unit_size = unit
	add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


func _later(sec: float, f: Callable) -> void:
	_pending.append([_t + sec, f])


# ------------------------------------------------------------------ hooks

func on_events(events: Array) -> void:
	for e in events:
		match e["type"]:
			"lightning":
				var k := randi() % 3
				var p: float = e.get("power", 0.7)
				_later(e.get("thunder_delay", 1.0), func(): sfx("thunder_%d" % k, lerpf(-10.0, 0.0, p), "Ambient"))
			"click":
				var dev: String = e["device"]
				sfx("click_knob" if dev in ["mode", "intensity"] else ("click_button" if dev == "start" else "click_switch"), -4.0)
			"breaker_trip":
				sfx("breaker_trip", 0.0)
			"gen_crank":
				sfx_at("gen_crank", loops["gen_idle"].global_position, 0.0)
			"gen_stop", "gen_overheat":
				sfx_at("gen_stop", loops["gen_idle"].global_position, -2.0)
			"ship_spawned":
				var s := sim.find_ship(e["ship"])
				if s and not s.unlit:
					_later(1.5, func(): sfx("horn_ship" if s.kind == "steamer" else "horn_fishing", -14.0, "Ambient"))
			"radio", "tx":
				_static_t = 2.5
				sfx("squelch", -8.0, "Dialogue")


func on_line(item: Dictionary) -> void:
	if item.get("look", item.get("mode", "")) == "radio":    # an in-room speaker in a radio scene is no transmission
		_static_t = maxf(_static_t, 3.5)


func ui_blip(kind: String) -> void:
	match kind:
		"char":
			sfx("blip", -14.0, "Dialogue")
		"squelch":
			sfx("squelch", -10.0, "Dialogue")


func story_cue(name_: String, args: Array) -> void:
	match name_:
		"sfx":
			var n: String = args[0]
			match n:
				"static_burst":
					_static_t = 3.0
					sfx("squelch", -2.0, "Dialogue")
				"silence":
					_duck = 1.0
				"paper_slide":
					sfx_at("paper_slide", station.door_position(), -2.0, 2.0)
				_:
					if ResourceLoader.exists(A % n):
						sfx(n)
		"static":
			_static_t = 0.0 if (args.size() > 0 and args[0] == "fade") else (6.0 if args.size() > 0 and args[0] == "heavy" else 3.5)
		"music":
			_music.stream = _looped("music_tension" if args[0] == "tension" else "music_menu")
			_music.volume_db = -12.0
			_music.play()


var _duck := 0.0


func knock(door: Vector3) -> void:
	for i in 3:
		_later(i * 1.15, func(): sfx_at("knock", door + Vector3(0, 1.3, 0), 2.0, 4.0))


## The visitor's approach, placed in space: jetty (north-east below), base door (deep below), stair.
func footsteps(stage: String, door: Vector3) -> void:
	match stage:
		"jetty":
			var p := Vector3(11.3, 2.0, -21.2)
			for i in 10:
				_later(i * 0.62, func(): sfx_at("step_metal_%d" % (i % 4), p.lerp(Vector3(4, 3.5, 4), i / 10.0), -10.0, 8.0))
		"base_door":
			sfx_at("door_base", Vector3(0, 4.0, 5.0), 0.0, 10.0)
		"stair":
			# iron spiral stair: steps climb toward the door over ~12 s, a pause half way
			for i in 18:
				var delay := i * 0.62 + (2.5 if i > 9 else 0.0)
				var y := lerpf(6.0, 19.6, i / 17.0)
				_later(delay, func(): sfx_at("step_metal_%d" % (i % 4), Vector3(door.x, y, door.z) + Vector3(door.x, 0, door.z).normalized() * 0.6, lerpf(-14.0, -2.0, i / 17.0), 4.0))


func _process(delta: float) -> void:
	_t += delta
	var keep: Array = []
	for p in _pending:
		if _t >= p[0]:
			p[1].call()
		else:
			keep.append(p)
	_pending = keep
	if sim == null:
		return
	var storm := sim.storm
	_duck = maxf(0.0, _duck - delta * 0.12)
	var duck_db := -24.0 * _duck
	loops["amb_wind"].volume_db = lerpf(-18.0, -4.0, storm) + duck_db
	loops["amb_rain"].volume_db = lerpf(-20.0, -6.0, storm) + duck_db
	loops["amb_sea"].volume_db = lerpf(-16.0, -6.0, storm) + duck_db
	loops["gen_idle"].volume_db = (-2.0 if sim.gen == KeeperSim.Gen.RUNNING else -80.0)
	loops["hum"].volume_db = -10.0 if sim.powered() else -80.0
	loops["clockwork"].volume_db = -8.0 if (sim.motor_on() and not sim.jammed) or sim.mode == KeeperSim.Mode.MANUAL and absf(sim._manual_vel) > 0.01 else -80.0
	loops["motor_grind"].volume_db = -2.0 if sim.jammed and sim.motor_on() else -80.0
	_static_t = maxf(0.0, _static_t - delta)
	loops["static"].volume_db = lerpf(-80.0, -16.0 + 6.0 * storm, clampf(_static_t, 0.0, 1.0)) if sim.radio_on() else -80.0
