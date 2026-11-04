class_name FleetShip
extends RefCounted
## A vessel in the v2 keeper game: follows radio orders, needs to see the light, pilots itself
## home once lined up inbound on a channel. Pure logic; KeeperSim drives it.

enum State { SAILING, PILOTING, SAVED, LOST }

var id := 0
var name := ""
var kind := "fishing"
var call_text := ""
var pos := Vector2.ZERO
var heading := 0.0
var ordered := 0.0            # ordered heading (rad)
var speed := 0.0              # current m/s
var cruise := 3.0
var turn_rate := 0.2
var radius := 3.0
var slow := false
var hold := false
var state := State.SAILING
var sees_light := false
var labelled := false         # radar label after CONFIRM POSITION
var answered := false         # the keeper has spoken to this ship at least once
var tti := INF
var spawn_time := 0.0
var resolve_time := -1.0
var last_call := 0.0
var mayday_sent := false
var dark_time := 0.0          # seconds the lamp was dark while this ship was at sea
var route := PackedVector2Array()
var seg := 0
var seg_t := 0.0
var channel_name := ""


func is_active() -> bool:
	return state == State.SAILING or state == State.PILOTING


func target_speed(cfg: KeeperConfig) -> float:
	if state == State.PILOTING:
		return cruise * 0.8
	if hold:
		return 0.0
	return cruise * (cfg.slow_mul if slow else 1.0)


## Pure pursuit along the route polyline (see v1 ShipModel): never cuts corners through the reef.
func pursue(lookahead: float, capture: float) -> Vector2:
	while seg < route.size() - 2:
		var nxt := route[seg + 1]
		if pos.distance_to(nxt) < capture or (_project(seg) >= 0.999 and _seg_dist(seg + 1) < capture):
			seg += 1
		else:
			break
	seg_t = _project(seg)
	var p := route[seg].lerp(route[seg + 1], seg_t)
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
	return pos.distance_to(route[i].lerp(route[i + 1], _project(i)))


func compute_tti(hazards: Array) -> float:
	if speed < 0.05:
		return INF
	var d := Geo.dir(heading)
	var best := INF
	for h in hazards:
		best = minf(best, Geo.ray_circle(pos, d, h["pos"], h["r"] + radius))
	return best / speed


## Bearing (deg, 0-359) and range (m) of this ship from the light, for radio reports.
func report() -> Dictionary:
	var b := int(round(rad_to_deg(Geo.bearing_of(pos)))) % 360
	if b < 0:
		b += 360
	return {"bearing": b, "range": int(round(pos.length() / 10.0)) * 10, "heading": posmod(int(round(rad_to_deg(heading))), 360)}
