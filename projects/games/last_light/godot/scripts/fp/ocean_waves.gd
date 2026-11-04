class_name OceanWaves
extends RefCounted
## The Gerstner wave set shared by shaders/ocean.gdshader (GPU) and ship motion (CPU).
## Swells run roughly from the open sea (north) toward the island (+z).

const WAVES := [
	Vector4(0.25, 1.0, 0.13, 60.0),
	Vector4(-0.4, 1.0, 0.11, 34.0),
	Vector4(0.6, 0.9, 0.09, 21.0),
	Vector4(-0.1, 1.0, 0.08, 13.0),
	Vector4(0.9, 0.5, 0.06, 8.0),
	Vector4(-0.7, 0.8, 0.05, 5.3),
]


static func amp_mul(storm: float) -> float:
	return lerpf(0.35, 1.0, storm)


## Surface height at world (x, z) (vertical Gerstner component, evaluated at the rest position).
static func height_at(p: Vector2, t: float, storm: float) -> float:
	var h := 0.0
	var amp := amp_mul(storm)
	for wv in WAVES:
		var w: Vector4 = wv
		var k := TAU / w.w
		var c := sqrt(9.8 / k)
		var d := Vector2(w.x, w.y).normalized()
		var f := k * (d.dot(p) - c * t)
		h += (w.z * amp / k) * sin(f)
	var calm := smoothstep(15.0, 45.0, p.length())
	return h * lerpf(0.35, 1.0, calm)


## Approximate surface normal by central differences.
static func normal_at(p: Vector2, t: float, storm: float, e := 1.5) -> Vector3:
	var hx := height_at(p + Vector2(e, 0), t, storm) - height_at(p - Vector2(e, 0), t, storm)
	var hz := height_at(p + Vector2(0, e), t, storm) - height_at(p - Vector2(0, e), t, storm)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


static func shader_array() -> Array:
	var out: Array = []
	for w in WAVES:
		out.append(Vector4(w.x, w.y, w.z, w.w))
	return out
