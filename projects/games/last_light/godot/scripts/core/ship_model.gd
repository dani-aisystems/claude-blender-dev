class_name ShipModel
extends RefCounted
## One ship: steering, bearings meter, collisions. Pure logic; SimWorld drives it.

enum State { SAILING, LOCKED, RESCUED, WRECKED, STRAYED }

var id := 0
var kind := "fishing"
var pos := Vector2.ZERO
var heading := 0.0
var speed := 5.0
var turn_rate := 0.3          # rad/s
var radius := 3.0
var need := 3.0               # seconds of normal light
var value := 100
var meter := 0.0              # 0..1
var state := State.SAILING
var lit := false
var ever_lit := false
var warning := false
var close_call := false
var route := PackedVector2Array()
var seg := 0                  # route segment: route[seg] -> route[seg + 1]
var seg_t := 0.0              # projection along that segment, 0..1
var blind_target := Vector2.ZERO
var spawn_bearing := 0.0
var spawn_time := 0.0
var resolve_time := -1.0
var tti := INF                # seconds to impact on the current heading
var velocity := Vector2.ZERO


func is_active() -> bool:
	return state == State.SAILING or state == State.LOCKED


## Pure pursuit along the route polyline. Returns the point `lookahead` metres ahead of the
## ship's projection on its current segment. Segments only advance once the ship has actually
## lined up (within `capture` m of the next one), so ships never cut a corner through the reef.
func pursue(lookahead: float, capture: float) -> Vector2:
	while seg < route.size() - 2:
		var nxt := route[seg + 1]
		if pos.distance_to(nxt) < capture or (_project(seg) >= 0.999 and _seg_dist(seg + 1) < capture):
			seg += 1
		else:
			break
	seg_t = _project(seg)
	var a := route[seg]
	var b := route[seg + 1]
	var p := a.lerp(b, seg_t)
	var remaining := lookahead
	var i := seg
	while true:
		var end := route[i + 1]
		var to_end := p.distance_to(end)
		if remaining <= to_end:
			return p + (end - p).normalized() * remaining
		remaining -= to_end
		i += 1
		if i >= route.size() - 1:
			return route[route.size() - 1]
		p = route[i]
	return route[route.size() - 1]


func at_route_end(reach: float) -> bool:
	return seg >= route.size() - 2 and (pos.distance_to(route[route.size() - 1]) < reach or seg_t >= 0.995)


func _project(i: int) -> float:
	var a := route[i]
	var ab := route[i + 1] - a
	return clampf((pos - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)


func _seg_dist(i: int) -> float:
	var a := route[i]
	return pos.distance_to(a.lerp(route[i + 1], _project(i)))


## Heading toward `target`, bent around reefs/island the ship can see (lit or locked ships only).
func avoid_heading(target: Vector2, hazards: Array, cfg: GameConfig) -> float:
	var desired := Geo.bearing_of(target - pos)
	var dist_to_target := pos.distance_to(target)
	for _pass in 2:
		for h in hazards:
			var c: Vector2 = h["pos"]
			var d := pos.distance_to(c)
			if d > cfg.avoid_lookahead + h["r"] or d > dist_to_target + h["r"]:
				continue
			var clear: float = h["r"] + radius + cfg.avoid_margin
			if d <= clear:
				# already scraping: steer straight away from the rock's centre side
				var away := Geo.bearing_of(pos - c)
				desired = Geo.turn_toward(desired, away, PI / 4)
				continue
			var half := asin(clampf(clear / d, 0.0, 1.0))
			var to_c := Geo.bearing_of(c - pos)
			var off := Geo.angle_diff(to_c, desired)
			if absf(off) < half:
				desired = wrapf(to_c + (half if off >= 0.0 else -half), -PI, PI)
	return desired


func compute_tti(hazards: Array, speed_now: float) -> float:
	var d := Geo.dir(heading)
	var best := INF
	for h in hazards:
		best = minf(best, Geo.ray_circle(pos, d, h["pos"], h["r"] + radius))
	return best / maxf(speed_now, 0.01)
