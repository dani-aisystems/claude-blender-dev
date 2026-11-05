extends CharacterBody3D
## First-person keeper: walk (WASD / left stick), look (mouse / right stick), interact (E / left mouse /
## pad A) with a raycast on the interaction layer, and device views (focus) that ease the camera onto a
## console and free the cursor (mouse, or a virtual cursor on the right stick; B / Esc steps back).
## The camera is top-level: position interpolated between physics ticks, look applied immediately.

## The interaction state under the crosshair / cursor (Stage 2), for fp_ui:
##   {state: "none" | "valid" | "unavailable", key, text, sub, in_view: bool, help: String}
signal prompt_changed(info: Dictionary)
signal pressed(accepted: bool)            # input received: the crosshair acknowledges every press
signal focus_changed(id: String)          # "" when leaving a device view
signal events(events: Array)
signal logbook_requested
signal doc_requested(id: String)

const EYE := 1.65
const WALK := 1.6
const SPRINT := 2.6
const REACH := 1.9
## Mouse look in radians per logical screen point (Stage 2C: from event.screen_relative, so it no
## longer changes with the window size). 0.0028 matches the old feel in fullscreen on a 1512-pt display.
const MOUSE_SENS := 0.0028
const TELEPORT := 0.5                        # a jump this large between physics ticks is a placement, not motion
const CONTAINER_KINDS := ["info", "focus"]   # big volumes around a whole cabinet / console
const CONTAINER_DEPTH := 0.6                 # a control this far behind a container's surface wins
const SWITCH_VIEW_DIST := 1.6                # device views whose eyes are this close switch directly (radio <-> chart)

var station: Node                          # station.gd
var camera: Camera3D
var head: Node3D
var focused := ""
var hovered := ""
var enabled := true
var _yaw := 0.0
var _pitch := 0.0
var _bob := 0.0
var _focus_from := Transform3D()
var _focus_to := Transform3D()
var _focus_t := 1.0
var _holding := ""
var _last_prompt := {}
## Device-view cursor that is not the OS pointer (Vector2.INF = follow the mouse). Captures set it to
## hover a control without moving Daniel's pointer; the gamepad stick drives it (Stage 2C).
var virtual_cursor := Vector2.INF
var gui_click_fn: Callable                   # fp_ui.click_at: the pad cursor presses screen buttons too
var vessel_cycle_fn: Callable                # fp_ui.cycle_vessel: LB / RB in the radio view
## Camera smoothing (Stage 2C): the body moves on 60 Hz physics ticks but frames come faster or out of
## step (120 Hz display, Medium at ~55-60 fps). The camera is top-level and drawn at the body position
## interpolated between the last two ticks; look rotation is applied at once (no added latency).
var _pos_prev := Vector3.ZERO
var _pos_cur := Vector3.ZERO
var _bob_y := 0.0
var _roll := 0.0


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.75
	col.shape = cap
	col.position.y = 0.875
	add_child(col)
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.3
	head = Node3D.new()
	head.position.y = EYE
	add_child(head)
	camera = Camera3D.new()
	camera.fov = float(Settings.v["fov"])
	Settings.changed.connect(func(): camera.fov = float(Settings.v["fov"]))
	camera.near = 0.03
	camera.far = 1200.0
	head.add_child(camera)
	camera.top_level = true                 # placed by _sync_camera (interpolated position, live look)
	camera.current = true
	_pos_prev = global_position
	_pos_cur = global_position


func place(t: Transform3D, look_at_point := Vector3.ZERO) -> void:
	global_position = t.origin
	var to := Vector3(look_at_point.x - global_position.x, 0, look_at_point.z - global_position.z).normalized()
	_yaw = atan2(-to.x, -to.z)
	_pitch = -0.08
	_apply_look()


## Capture and autotest runs (bot-driven, often in the background) never take the mouse: on macOS a
## capture re-activates the app, pulling Daniel out of whatever he is working in, and hides his pointer.
func capture_mouse(on: bool) -> void:
	var unattended: bool = GameState.user_args.has("capture") or GameState.user_args.has("autotest")
	if on and not unattended:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif InputSetup.pad_active and not unattended:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN     # the pad has its own cursor (Daniel, 2C); mouse motion brings it back
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion:
		if focused != "" and event.relative.length() > 0.5 and not InputSetup.pad_forced:
			virtual_cursor = Vector2.INF       # the real mouse moved: it drives the device-view cursor again
		if focused == "" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var sens: float = MOUSE_SENS * float(Settings.v["mouse_sens"])
			var inv := -1.0 if Settings.v["invert_y"] else 1.0
			var d: Vector2 = event.screen_relative / maxf(DisplayServer.screen_get_scale(), 1.0)
			_yaw -= d.x * sens
			_pitch = clampf(_pitch - d.y * sens * inv, -1.45, 1.45)
			_apply_look()
	elif event.is_action_pressed("interact") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		_press(event)
	elif event.is_action_released("interact") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed):
		_release()
	elif event.is_action_pressed("back"):     # pad B (keyboard: Esc and right click, below / in game_fp)
		if focused != "":
			leave_focus()
	elif event.is_action_pressed("turn_prev") or event.is_action_pressed("turn_next"):
		var nxt := event.is_action_pressed("turn_next")
		var hid := _ray_hit_id(focused != "")
		if hid != "" and station.DEVICES[hid]["kind"] == "cycle":
			_turn(hid, "next" if nxt else "prev", "wheel" if focused != "" else ("back" if not nxt else "wheel"))
		elif focused == "radio" and vessel_cycle_fn.is_valid():
			vessel_cycle_fn.call(1 if nxt else -1)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if focused != "":
			leave_focus()
		elif hovered != "":
			_turn(hovered, "prev", "back")
	elif event is InputEventMouseButton and event.pressed and focused != "" and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var id := _ray_hit_id(true)
		if id != "":
			_turn(id, "next" if event.button_index == MOUSE_BUTTON_WHEEL_UP else "prev", "wheel")
	elif event.is_action_pressed("logbook"):
		logbook_requested.emit()


func _press(_event: InputEvent) -> void:
	# pad cursor in a device view: on-screen buttons (radio panel) first, then the room's controls
	if focused != "" and virtual_cursor.is_finite() and gui_click_fn.is_valid() and gui_click_fn.call(virtual_cursor):
		pressed.emit(true)
		return
	var id := _ray_hit_id(focused != "")
	if id == "":
		return
	var d: Dictionary = station.DEVICES.get(id, {})
	if d.is_empty():
		return
	if not _actionable(id):
		pressed.emit(false)
		var av: Dictionary = station.availability(id)
		if av["reason"] != "":
			events.emit([{"type": "refused", "device": id, "reason": av["reason"]}])
		return
	match d["kind"]:
		"focus":
			enter_focus(d.get("focus_id", id))
		"logbook":
			logbook_requested.emit()
		"doc", "door":
			doc_requested.emit(id)
		"wheel":
			if focused != "":
				return                       # in the console view it turns with A / D, not by clicking
			enter_focus("console")
		_:
			_holding = id
			events.emit(station.use(id, "press"))
	pressed.emit(true)


## Would pressing on this control do something right now? Mirrors _press, so a prompt with a key is
## never a dead end (Stage 2: the radio view used to offer "[Click] Study chart" and ignore the click).
func _actionable(id: String) -> bool:
	var d: Dictionary = station.DEVICES.get(id, {})
	if d.is_empty() or not station.availability(id)["ok"]:
		return false
	match d["kind"]:
		"focus":
			return focused == "" or _can_switch(d.get("focus_id", id))
		"wheel":
			return true                      # free walk: opens the console; in the view: A / D (prompt says so)
	return true


## A device view can hand over directly to a neighbouring one (the radio and the chart share the desk).
func _can_switch(to_id: String) -> bool:
	if focused == "" or to_id == focused:
		return false
	var a: Dictionary = station.focus.get(focused, {})
	var b: Dictionary = station.focus.get(to_id, {})
	return a.has("eye") and b.has("eye") and (a["eye"] as Vector3).distance_to(b["eye"]) <= SWITCH_VIEW_DIST


## Turn a selector knob one step with the wheel or right click; using it retires that tip.
func _turn(id: String, action: String, tip: String) -> void:
	var ev: Array = station.use(id, action)
	if not ev.is_empty():
		Settings.tip_used(tip)
		pressed.emit(true)
	events.emit(ev)


func _release() -> void:
	if _holding != "":
		events.emit(station.use(_holding, "release"))
		_holding = ""


## Let go of everything held (START, the handwheel). Pause calls this: the key release would otherwise
## be lost under the pause menu and the engine would keep cranking after resume.
func release_holds() -> void:
	_release()
	events.emit(station.release_all())
	if station.sim:
		station.sim.set_wheel(0.0)


func enter_focus(id: String) -> void:
	var f: Dictionary = station.focus.get(id, {})
	if not f.has("eye"):
		return
	if focused != "" and focused != id:      # direct switch between neighbouring views
		events.emit(station.release_all())
		if focused == "console":
			station.sim.set_wheel(0.0)
	focused = id
	_focus_from = camera.global_transform
	var eye: Vector3 = f["eye"]
	var at: Vector3 = f.get("at", eye + Vector3.FORWARD)
	_focus_to = Transform3D(Basis.looking_at(at - eye, Vector3.UP), eye)
	_focus_t = 0.0
	velocity = Vector3.ZERO
	if InputSetup.pad_active:                 # the pad cursor starts in the middle of the view
		virtual_cursor = get_viewport().get_visible_rect().size * 0.5
	capture_mouse(false)
	focus_changed.emit(id)


func leave_focus() -> void:
	if focused == "":
		return
	events.emit(station.release_all())
	if focused == "console":
		station.sim.set_wheel(0.0)
	focused = ""
	_focus_from = camera.global_transform
	_focus_t = 0.0
	capture_mouse(true)
	focus_changed.emit("")


func _apply_look() -> void:
	rotation.y = _yaw
	head.rotation.x = _pitch
	_snap_if_placed()
	_sync_camera()


## A placement (spawn, load, capture pose, test aim) is not motion: don't interpolate across it.
## Walking only moves the body inside _physics_process, which records _pos_cur right after
## move_and_slide, so any difference here means the position was set from outside.
func _snap_if_placed() -> void:
	if not global_position.is_equal_approx(_pos_cur):
		_pos_prev = global_position
		_pos_cur = global_position


## Where the free-walk eye is this frame: the body interpolated between physics ticks, plus head bob.
func _home() -> Transform3D:
	var p := _pos_prev.lerp(_pos_cur, Engine.get_physics_interpolation_fraction())
	return Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, _roll)), p + Vector3(0, EYE + _bob_y, 0))


func _sync_camera() -> void:
	if _focus_t < 1.0:
		var e := ease(_focus_t, -2.2)
		camera.global_transform = _focus_from.interpolate_with(_focus_to if focused != "" else _home(), e)
	elif focused != "":
		camera.global_transform = _focus_to
	else:
		camera.global_transform = _home()


## Per rendered frame: pad look and the device-view cursor, head bob, the camera (Stage 2C).
func _process(delta: float) -> void:
	if not enabled:
		return
	_snap_if_placed()
	if focused == "":
		var s := InputSetup.stick("look_left", "look_right", "look_up", "look_down")
		if s != Vector2.ZERO:
			var k: float = InputSetup.LOOK_SPEED * float(Settings.v.get("stick_sens", 1.0)) * delta
			var inv := -1.0 if Settings.v["invert_y"] else 1.0
			_yaw -= s.x * k
			_pitch = clampf(_pitch - s.y * k * 0.7 * inv, -1.45, 1.45)
			rotation.y = _yaw
			head.rotation.x = _pitch
		# subtle head motion (Options: Head bob)
		var hs := Vector2(velocity.x, velocity.z).length()
		_bob += delta * hs * 5.2
		var bob_on: bool = Settings.v.get("head_bob", true) and hs > 0.2
		_bob_y = lerpf(_bob_y, sin(_bob) * 0.018 if bob_on else 0.0, minf(1.0, delta * 10.0))
		_roll = lerpf(_roll, cos(_bob * 0.5) * 0.004 if bob_on else 0.0, minf(1.0, delta * 8.0))
	else:
		var c := InputSetup.stick("look_left", "look_right", "look_up", "look_down")
		if c != Vector2.ZERO:
			var vp := get_viewport().get_visible_rect().size
			var from := virtual_cursor if virtual_cursor.is_finite() else get_viewport().get_mouse_position()
			virtual_cursor = (from + c * InputSetup.CURSOR_SPEED * float(Settings.v.get("stick_sens", 1.0)) * delta).clamp(Vector2.ZERO, vp)
	if _focus_t < 1.0:
		_focus_t = minf(1.0, _focus_t + delta / 0.45)
	_sync_camera()


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	if focused != "":
		if focused == "console":
			var axis := Input.get_axis("move_left", "move_right")
			if Input.is_action_pressed("beam_left"):
				axis = -1.0
			elif Input.is_action_pressed("beam_right"):
				axis = 1.0
			station.sim.set_wheel(axis)
		_update_prompt()
		return
	# walking
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var spd := SPRINT if Input.is_action_pressed("sprint") else WALK
	var target := dir * spd
	velocity.x = move_toward(velocity.x, target.x, 9.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 9.0 * delta)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_pos_prev = _pos_cur if global_position.distance_to(_pos_cur) <= TELEPORT else global_position
	_pos_cur = global_position
	_update_prompt()


func _ray_hit_id(from_mouse: bool) -> String:
	var space := get_world_3d().direct_space_state
	var origin: Vector3
	var dir: Vector3
	if from_mouse:
		var mp := cursor_pos()
		origin = camera.project_ray_origin(mp)
		dir = camera.project_ray_normal(mp)
	else:
		origin = camera.global_position
		dir = -camera.global_transform.basis.z
	return pick(space, origin, dir, REACH + (1.2 if from_mouse else 0.0))


## Where the device-view cursor is, in viewport pixels.
func cursor_pos() -> Vector2:
	return virtual_cursor if virtual_cursor.is_finite() else get_viewport().get_mouse_position()


## The control along a ray. Small controls (breakers, START, console knobs) sit INSIDE the larger
## "info"/"focus" volume of their cabinet, so the first volume hit is not always the one meant:
##  - inside a device view that device's own volume is ignored (its controls are what you click);
##  - a specific control up to CONTAINER_DEPTH behind a container volume wins over the container;
##  - furniture colliders do not hide controls mounted on them; walls, floor, ceiling and the stair
##    housing/door still do (no using things through a wall).
func pick(space: PhysicsDirectSpaceState3D, origin: Vector3, dir: Vector3, length: float) -> String:
	var hits: Array = []
	var exclude: Array[RID] = []
	for i in 6:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * length, 1 << 1, exclude)
		var h := space.intersect_ray(q)
		if h.is_empty():
			break
		exclude.append(h["rid"])
		var id: String = h["collider"].get_meta("ia", "")
		var d: Dictionary = station.DEVICES.get(id, {})
		if d.is_empty():
			continue
		if focused != "" and (id == focused or d.get("focus_id", "") == focused):
			continue
		hits.append({"id": id, "kind": d["kind"], "dist": origin.distance_to(h["position"])})
	if hits.is_empty():
		return ""
	var best: Dictionary = hits[0]
	if best["kind"] in CONTAINER_KINDS:
		for h in hits.slice(1):
			if not (h["kind"] in CONTAINER_KINDS) and h["dist"] - best["dist"] <= CONTAINER_DEPTH:
				best = h
				break
	if _occluded(space, origin, dir, best["dist"]):
		return ""
	return best["id"]


func _occluded(space: PhysicsDirectSpaceState3D, origin: Vector3, dir: Vector3, dist: float) -> bool:
	var exclude: Array[RID] = [get_rid()]
	for i in 6:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * maxf(dist - 0.05, 0.0), 1, exclude)
		var b := space.intersect_ray(q)
		if b.is_empty():
			return false
		if _is_occluder(b["collider"]):
			return true
		exclude.append(b["rid"])
	return false


static func _is_occluder(c: Object) -> bool:
	if not (c is Node):
		return true
	var n := String((c as Node).name)
	if not n.begins_with("COL_"):
		return true
	return n.begins_with("COL_wall") or n.begins_with("COL_floor") or n.begins_with("COL_ceiling") or n.begins_with("COL_stair")


func _update_prompt() -> void:
	var in_view := focused != ""
	var id := _ray_hit_id(in_view)
	hovered = id
	var info := {"state": "none", "key": "", "text": "", "sub": "", "in_view": in_view, "help": ""}
	if id != "":
		var p: Dictionary = station.prompt_info(id, in_view)
		var ok := _actionable(id)
		info["text"] = p["text"]
		info["sub"] = p["sub"]
		info["key"] = p["key"] if ok else ""
		info["state"] = "valid" if ok else "unavailable"
	if in_view:
		info["help"] = "%s  Step back" % InputSetup.key("step_back")
		if focused == "console":
			info["help"] = "%s  Turn the handwheel      %s" % [InputSetup.key("handwheel"), info["help"]]
	if info != _last_prompt:
		_last_prompt = info
		prompt_changed.emit(info)


## The prompt as one line (tests, logs): "[E]  Use the radio · sub".
static func prompt_text(info: Dictionary) -> String:
	if info.is_empty() or info["text"] == "":
		return info.get("help", "")
	var s: String = ("%s  %s" % [info["key"], info["text"]]) if info["key"] != "" else info["text"]
	return s + ("  ·  " + info["sub"] if info["sub"] != "" else "")
