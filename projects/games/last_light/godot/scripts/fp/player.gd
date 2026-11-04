extends CharacterBody3D
## First-person keeper: walk (WASD), look (mouse), interact (E / left mouse) with a raycast on the
## interaction layer, and device views (focus) that ease the camera onto a console and free the cursor.

signal prompt_changed(text: String)
signal focus_changed(id: String)          # "" when leaving a device view
signal events(events: Array)
signal logbook_requested
signal doc_requested(id: String)

const EYE := 1.65
const WALK := 1.6
const SPRINT := 2.6
const REACH := 1.9
const MOUSE_SENS := 0.0022

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
var _last_prompt := "-"


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
	camera.current = true


func place(t: Transform3D, look_at_point := Vector3.ZERO) -> void:
	global_position = t.origin
	var to := Vector3(look_at_point.x - global_position.x, 0, look_at_point.z - global_position.z).normalized()
	_yaw = atan2(-to.x, -to.z)
	_pitch = -0.08
	_apply_look()


func capture_mouse(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and focused == "" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = MOUSE_SENS * float(Settings.v["mouse_sens"])
		var inv := -1.0 if Settings.v["invert_y"] else 1.0
		_yaw -= event.relative.x * sens
		_pitch = clampf(_pitch - event.relative.y * sens * inv, -1.45, 1.45)
		_apply_look()
	elif event.is_action_pressed("interact") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		_press(event)
	elif event.is_action_released("interact") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed):
		_release()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if focused != "":
			leave_focus()
		elif hovered != "":
			events.emit(station.use(hovered, "prev"))
	elif event is InputEventMouseButton and event.pressed and focused != "" and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var id := _ray_hit_id(true)
		if id != "":
			events.emit(station.use(id, "next" if event.button_index == MOUSE_BUTTON_WHEEL_UP else "prev"))
	elif event.is_action_pressed("logbook"):
		logbook_requested.emit()


func _press(_event: InputEvent) -> void:
	var id := _ray_hit_id(focused != "")
	if id == "":
		return
	var d: Dictionary = station.DEVICES.get(id, {})
	if d.is_empty():
		return
	match d["kind"]:
		"focus":
			if focused == "":
				enter_focus(d.get("focus_id", id))
		"logbook":
			logbook_requested.emit()
		"doc", "door":
			doc_requested.emit(id)
		"wheel":
			if focused == "":
				enter_focus("console")
		_:
			_holding = id
			events.emit(station.use(id, "press"))


func _release() -> void:
	if _holding != "":
		events.emit(station.use(_holding, "release"))
		_holding = ""


func enter_focus(id: String) -> void:
	var f: Dictionary = station.focus.get(id, {})
	if not f.has("eye"):
		return
	focused = id
	_focus_from = camera.global_transform
	var eye: Vector3 = f["eye"]
	var at: Vector3 = f.get("at", eye + Vector3.FORWARD)
	_focus_to = Transform3D(Basis.looking_at(at - eye, Vector3.UP), eye)
	_focus_t = 0.0
	velocity = Vector3.ZERO
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


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	# camera blend for device views
	if _focus_t < 1.0:
		_focus_t = minf(1.0, _focus_t + delta / 0.45)
		var e := ease(_focus_t, -2.2)
		var home := head.global_transform
		if focused != "":
			camera.global_transform = _focus_from.interpolate_with(_focus_to, e)
		else:
			camera.global_transform = _focus_from.interpolate_with(home, e)
			if _focus_t >= 1.0:
				camera.transform = Transform3D()
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
	# subtle head motion
	var hs := Vector2(velocity.x, velocity.z).length()
	_bob += delta * hs * 5.2
	var target_y := EYE + (sin(_bob) * 0.018 if hs > 0.2 else 0.0)
	head.position.y = lerpf(head.position.y, target_y, minf(1.0, delta * 10.0))
	camera.rotation.z = lerpf(camera.rotation.z, (cos(_bob * 0.5) * 0.004 if hs > 0.2 else 0.0), minf(1.0, delta * 8.0))
	_update_prompt()


func _ray_hit_id(from_mouse: bool) -> String:
	var space := get_world_3d().direct_space_state
	var origin: Vector3
	var dir: Vector3
	if from_mouse:
		var mp := get_viewport().get_mouse_position()
		origin = camera.project_ray_origin(mp)
		dir = camera.project_ray_normal(mp)
	else:
		origin = camera.global_position
		dir = -camera.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * (REACH + (1.2 if from_mouse else 0.0)), 1 << 1)
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return ""
	# walls (layer 1) occlude: re-test on layer 1 and compare distance
	var q2 := PhysicsRayQueryParameters3D.create(origin, hit["position"], 1)
	var block := space.intersect_ray(q2)
	if not block.is_empty() and origin.distance_to(block["position"]) < origin.distance_to(hit["position"]) - 0.05:
		return ""
	var id: String = hit["collider"].get_meta("ia", "")
	var d: Dictionary = station.DEVICES.get(id, {})
	# device views only expose their own controls; the room only exposes reachable devices
	if focused == "" and id in ["mode", "intensity", "handwheel"]:
		return id
	return id if not d.is_empty() else ""


func _update_prompt() -> void:
	var id := _ray_hit_id(focused != "")
	hovered = id
	var text := ""
	if id != "":
		var key := "[Click]" if focused != "" else "[E]"
		text = "%s  %s" % [key, station.describe(id)]
		if station.DEVICES[id]["kind"] == "cycle":
			text += "     [Right click] back"
	elif focused != "":
		text = "[Esc / Right click]  Step back"
		if focused == "console":
			text = "[A / D] Turn handwheel     " + text
	if text != _last_prompt:
		_last_prompt = text
		prompt_changed.emit(text)
