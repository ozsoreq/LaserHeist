class_name Zones
extends RefCounted
## Altitude bands: each changes the sky, and higher ones add wind and lower gravity.

const PX_PER_M := 8.0

const LIST := [
	{"name": "Meadow", "m": 0.0, "top": Color("6fbff0"), "bottom": Color("d6f1ff"), "gravity": 1.0, "wind": 0.0},
	{"name": "Rooftops", "m": 40.0, "top": Color("5aa8e6"), "bottom": Color("ffe3c2"), "gravity": 1.0, "wind": 0.0},
	{"name": "Cloud Sea", "m": 120.0, "top": Color("6f9fe0"), "bottom": Color("f2f7ff"), "gravity": 1.0, "wind": 0.0},
	{"name": "Jet Stream", "m": 250.0, "top": Color("3f6dc2"), "bottom": Color("9fc0ee"), "gravity": 0.9, "wind": 1.0},
	{"name": "Stratosphere", "m": 450.0, "top": Color("1c3270"), "bottom": Color("5277c0"), "gravity": 0.7, "wind": 0.5},
	{"name": "Low Orbit", "m": 700.0, "top": Color("0a1130"), "bottom": Color("223467"), "gravity": 0.45, "wind": 0.0},
	{"name": "Deep Space", "m": 1000.0, "top": Color("04050d"), "bottom": Color("141838"), "gravity": 0.3, "wind": 0.0},
]


static func index_at(m: float) -> int:
	var idx := 0
	for i in LIST.size():
		if m >= LIST[i]["m"]:
			idx = i
	return idx


static func zone_at(m: float) -> Dictionary:
	return LIST[index_at(m)]


## 0..1 blend toward the next zone over the last stretch of the current one.
static func _blend(m: float) -> Array:
	var i := index_at(m)
	if i >= LIST.size() - 1:
		return [i, i, 0.0]
	var a: float = LIST[i]["m"]
	var b: float = LIST[i + 1]["m"]
	var start := lerpf(a, b, 0.6)
	return [i, i + 1, clampf((m - start) / (b - start), 0.0, 1.0)]


static func sky_colors(m: float) -> Array[Color]:
	var bl := _blend(m)
	var za: Dictionary = LIST[bl[0]]
	var zb: Dictionary = LIST[bl[1]]
	var t: float = bl[2]
	var top: Color = za["top"].lerp(zb["top"], t)
	var bottom: Color = za["bottom"].lerp(zb["bottom"], t)
	var out: Array[Color] = [top, bottom]
	return out


static func gravity_factor(m: float) -> float:
	var bl := _blend(m)
	return lerpf(LIST[bl[0]]["gravity"], LIST[bl[1]]["gravity"], bl[2])


static func wind_strength(m: float) -> float:
	var bl := _blend(m)
	return lerpf(LIST[bl[0]]["wind"], LIST[bl[1]]["wind"], bl[2])
