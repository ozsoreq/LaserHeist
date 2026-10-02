class_name PieceCatalog
extends RefCounted
## Every object the crane can drop: physics properties, unlock altitude and look.

const KINDS := {
	"crate": {
		"name": "Crate", "shape": "rect", "size": Vector2(80, 80), "mass": 1.0,
		"friction": 0.9, "bounce": 0.0, "unlock_m": 0, "weight": 10,
		"color": Color("e9b25c"), "outline": Color("6b4320"),
		"tip": "Trusty and square.",
	},
	"plank": {
		"name": "Plank", "shape": "rect", "size": Vector2(200, 26), "mass": 0.8,
		"friction": 0.85, "bounce": 0.0, "unlock_m": 0, "weight": 8,
		"color": Color("c98b4a"), "outline": Color("5a3a1c"),
		"tip": "Bridges gaps. Rotate it to make a pillar.",
	},
	"roof": {
		"name": "Roof", "shape": "poly", "points": [Vector2(-60, 30), Vector2(60, 30), Vector2(0, -34)],
		"mass": 0.9, "friction": 0.8, "bounce": 0.0, "unlock_m": 15, "weight": 5,
		"color": Color("e06a5a"), "outline": Color("6e2a22"),
		"tip": "Pointy side down? Brave.",
	},
	"barrel": {
		"name": "Barrel", "shape": "circle", "radius": 38.0, "mass": 1.1,
		"friction": 0.6, "bounce": 0.05, "unlock_m": 25, "weight": 5,
		"color": Color("a0643a"), "outline": Color("4a2a14"),
		"tip": "It rolls. Wedge it in.",
	},
	"pillow": {
		"name": "Pillow", "shape": "rect", "size": Vector2(110, 44), "mass": 0.4,
		"friction": 1.0, "bounce": 0.0, "unlock_m": 40, "weight": 5,
		"color": Color("f4a7c4"), "outline": Color("8a3d5c"), "face": true,
		"tip": "Soft, light and very grippy.",
	},
	"anvil": {
		"name": "Anvil", "shape": "poly",
		"points": [Vector2(-50, -24), Vector2(50, -24), Vector2(34, 0), Vector2(22, 0), Vector2(30, 24), Vector2(-30, 24), Vector2(-22, 0), Vector2(-34, 0)],
		"mass": 5.0, "friction": 0.9, "bounce": 0.0, "unlock_m": 60, "weight": 4,
		"color": Color("5b6470"), "outline": Color("20252c"),
		"tip": "Heavy. Steadies a wobbly tower.",
	},
	"glue": {
		"name": "Glue Block", "shape": "rect", "size": Vector2(70, 70), "mass": 0.8,
		"friction": 1.0, "bounce": 0.0, "unlock_m": 90, "weight": 4,
		"color": Color("7ed957"), "outline": Color("2f6b1c"), "face": true, "sticky": true,
		"tip": "Sticks to the first things it touches.",
	},
	"ice": {
		"name": "Ice Block", "shape": "rect", "size": Vector2(100, 60), "mass": 0.9,
		"friction": 0.02, "bounce": 0.0, "unlock_m": 130, "weight": 4,
		"color": Color("bdeeff"), "outline": Color("4a9cc4"),
		"tip": "Slippery! Needs walls around it.",
	},
	"balloon": {
		"name": "Balloon Crate", "shape": "rect", "size": Vector2(70, 70), "mass": 0.6,
		"friction": 0.9, "bounce": 0.0, "unlock_m": 180, "weight": 4,
		"color": Color("ffd166"), "outline": Color("7a5a12"), "gravity_scale": 0.3, "balloon": true,
		"tip": "Drifts down gently. Barely weighs a thing.",
	},
	"spring": {
		"name": "Spring", "shape": "rect", "size": Vector2(90, 40), "mass": 0.7,
		"friction": 0.7, "bounce": 0.85, "unlock_m": 240, "weight": 3,
		"color": Color("ff8fab"), "outline": Color("7a2e44"), "spring": true,
		"tip": "Boing. Things bounce off it.",
	},
	"beam": {
		"name": "Steel Beam", "shape": "rect", "size": Vector2(260, 30), "mass": 3.0,
		"friction": 0.8, "bounce": 0.0, "unlock_m": 320, "weight": 5,
		"color": Color("8d99a6"), "outline": Color("2c333b"),
		"tip": "Long, heavy and dependable.",
	},
}


static func get_def(kind: String) -> Dictionary:
	return KINDS[kind]


## Kinds unlocked at a given altitude, in unlock order.
static func unlocked(altitude_m: float) -> Array[String]:
	var out: Array[String] = []
	for k in KINDS:
		if KINDS[k]["unlock_m"] <= altitude_m:
			out.append(k)
	return out


## Weighted random pick from the unlocked kinds.
static func pick(rng: RandomNumberGenerator, altitude_m: float) -> String:
	var pool := unlocked(altitude_m)
	var total := 0
	for k in pool:
		total += KINDS[k]["weight"]
	var r := rng.randi_range(1, total)
	for k in pool:
		r -= KINDS[k]["weight"]
		if r <= 0:
			return k
	return pool[0]


## Outline polygon (local space) for rect and poly shapes.
static func outline_points(def: Dictionary) -> PackedVector2Array:
	match def["shape"]:
		"rect":
			var h: Vector2 = def["size"] * 0.5
			return PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])
		"poly":
			return PackedVector2Array(def["points"])
		_:
			var pts := PackedVector2Array()
			var r: float = def["radius"]
			for i in 24:
				pts.append(Vector2.from_angle(TAU * i / 24.0) * r)
			return pts


## Draws a piece of `kind` onto any CanvasItem at its local origin.
static func draw_piece(ci: CanvasItem, kind: String, scale := 1.0, set_in_stone := false) -> void:
	var def := get_def(kind)
	var fill: Color = def["color"]
	var line: Color = def["outline"]
	if set_in_stone:
		fill = fill.darkened(0.25)
	var pts := outline_points(def)
	for i in pts.size():
		pts[i] *= scale
	var w := maxf(2.0, 4.0 * scale)

	if def.get("balloon", false):
		var top: float = -def["size"].y * 0.5 * scale
		ci.draw_line(Vector2(0, top), Vector2(0, top - 46 * scale), Color("5a4a3a"), 2.0 * scale)
		ci.draw_circle(Vector2(0, top - 70 * scale), 26 * scale, Color("ff5d73"))
		ci.draw_arc(Vector2(0, top - 70 * scale), 26 * scale, 0, TAU, 24, Color("8a1f33"), w * 0.8)
		ci.draw_circle(Vector2(-8, top - 80 * scale), 6 * scale, Color(1, 1, 1, 0.6))

	ci.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, line, w, true)

	var s := scale
	match kind:
		"crate", "balloon":
			var h: Vector2 = def["size"] * 0.5 * s
			var inset := 9.0 * s
			ci.draw_line(Vector2(-h.x + inset, -h.y + inset), Vector2(h.x - inset, h.y - inset), line, w * 0.8)
			ci.draw_line(Vector2(h.x - inset, -h.y + inset), Vector2(-h.x + inset, h.y - inset), line, w * 0.8)
			ci.draw_rect(Rect2(-h + Vector2(inset, inset), (h - Vector2(inset, inset)) * 2), line, false, w * 0.6)
		"plank", "beam":
			var h: Vector2 = def["size"] * 0.5 * s
			if kind == "plank":
				ci.draw_line(Vector2(-h.x * 0.8, -h.y * 0.2), Vector2(h.x * 0.3, -h.y * 0.2), line.lightened(0.2), w * 0.5)
				ci.draw_line(Vector2(-h.x * 0.2, h.y * 0.35), Vector2(h.x * 0.8, h.y * 0.35), line.lightened(0.2), w * 0.5)
			else:
				for x in [-0.85, -0.3, 0.3, 0.85]:
					ci.draw_circle(Vector2(h.x * x, 0), 4 * s, line)
		"roof":
			for t in [0.35, 0.65]:
				var a := pts[2].lerp(pts[0], t)
				var b := pts[2].lerp(pts[1], t)
				ci.draw_line(a, b, line, w * 0.6)
		"barrel":
			var r: float = def["radius"] * s
			ci.draw_arc(Vector2.ZERO, r * 0.62, 0, TAU, 24, line, w * 0.7)
			ci.draw_line(Vector2(-r, 0), Vector2(r, 0), line, w * 0.6)
			ci.draw_line(Vector2(0, -r), Vector2(0, r), line, w * 0.6)
		"ice":
			var h: Vector2 = def["size"] * 0.5 * s
			ci.draw_line(Vector2(-h.x * 0.6, -h.y * 0.5), Vector2(-h.x * 0.1, -h.y * 0.5), Color(1, 1, 1, 0.9), w)
			ci.draw_line(Vector2(-h.x * 0.6, -h.y * 0.1), Vector2(-h.x * 0.35, -h.y * 0.1), Color(1, 1, 1, 0.7), w * 0.7)
		"spring":
			var h: Vector2 = def["size"] * 0.5 * s
			for i in 4:
				var x := lerpf(-h.x * 0.7, h.x * 0.7, i / 3.0)
				ci.draw_arc(Vector2(x, 0), h.y * 0.55, 0, TAU, 12, line, w * 0.6)
		"anvil":
			ci.draw_line(Vector2(-40 * s, -18 * s), Vector2(30 * s, -18 * s), Color(1, 1, 1, 0.35), w * 0.6)
	if def.get("face", false):
		ci.draw_circle(Vector2(-12 * s, -4 * s), 5 * s, Color("1b2230"))
		ci.draw_circle(Vector2(12 * s, -4 * s), 5 * s, Color("1b2230"))
		ci.draw_circle(Vector2(-10 * s, -6 * s), 1.8 * s, Color.WHITE)
		ci.draw_circle(Vector2(14 * s, -6 * s), 1.8 * s, Color.WHITE)
		ci.draw_arc(Vector2(0, 5 * s), 7 * s, 0.2, PI - 0.2, 10, Color("1b2230"), 2.5 * s)
