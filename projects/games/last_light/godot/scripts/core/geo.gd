class_name Geo
extends RefCounted
## Sea-plane geometry. Positions are Vector2(x, z) in Godot world space (north = -z).
## Bearing: radians, 0 = north, +PI/2 = east (clockwise seen from above). Matches layout.py.


static func dir(bearing: float) -> Vector2:
	return Vector2(sin(bearing), -cos(bearing))


static func bearing_of(v: Vector2) -> float:
	return atan2(v.x, -v.y)


static func polar(bearing: float, radius: float) -> Vector2:
	return dir(bearing) * radius


## Shortest signed angle from a to b, in [-PI, PI).
static func angle_diff(a: float, b: float) -> float:
	return wrapf(b - a, -PI, PI)


static func to_v3(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


static func to_v2(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


## Node3D yaw so that local -Z (forward) points along the bearing.
static func yaw_for(bearing: float) -> float:
	return -bearing


## Distance along unit direction d from origin to the first hit of circle (c, r). INF if none.
static func ray_circle(origin: Vector2, d: Vector2, c: Vector2, r: float) -> float:
	var oc := origin - c
	var cc := oc.length_squared() - r * r
	if cc <= 0.0:
		return 0.0
	var b := oc.dot(d)
	var disc := b * b - cc
	if disc < 0.0:
		return INF
	var t := -b - sqrt(disc)
	return t if t >= 0.0 else INF


## Rotate heading toward target by at most max_step radians.
static func turn_toward(heading: float, target: float, max_step: float) -> float:
	var d := angle_diff(heading, target)
	return wrapf(heading + clampf(d, -max_step, max_step), -PI, PI)
