extends Node2D
## Screen-space sky: altitude gradient plus parallax decor (hills, clouds,
## balloons, birds, planes, stars, satellites and a ringed planet).

const PARALLAX := 0.45
const CHUNK := 260.0

var cam_alt_px := 0.0 # camera centre height above the island, in pixels
var wind := 0.0
var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	var m := cam_alt_px / Zones.PX_PER_M
	var span_m := size.y * 0.5 / Zones.PX_PER_M
	var top_c := Zones.sky_colors(m + span_m)
	var bot_c := Zones.sky_colors(maxf(0.0, m - span_m))
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([top_c[0], top_c[0], bot_c[1], bot_c[1]]))

	# Parallax space: y grows downward, 0 is the island at rest.
	var cam_py := -cam_alt_px * PARALLAX
	var first := floori((cam_py - size.y * 0.5 - CHUNK) / CHUNK)
	var last := ceili((cam_py + size.y * 0.5 + CHUNK) / CHUNK)
	for c in range(first, last + 1):
		_draw_chunk(c, cam_py, size)

	if wind != 0.0:
		var streaks := int(absf(wind) * 14.0)
		for i in streaks:
			var y := fposmod(i * 97.3, size.y)
			var x := fposmod(i * 211.7 + _time * wind * 900.0, size.x + 200.0) - 100.0
			draw_line(Vector2(x, y), Vector2(x - signf(wind) * 60.0, y), Color(1, 1, 1, 0.35), 2.0)


func _draw_chunk(c: int, cam_py: float, size: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c * 7919 + 17)
	var to_screen := func(py: float) -> float: return size.y * 0.5 + (py - cam_py)
	var alt_m := -(c * CHUNK) / PARALLAX / Zones.PX_PER_M

	if c >= 0:
		if c != 1:
			return
		# Rolling hills far below the floating island.
		var base := to_screen.call(320.0) as float
		for i in 5:
			var hx := size.x * (i / 4.0) + rng.randf_range(-40, 40)
			var hr := rng.randf_range(160, 260)
			_ellipse(Vector2(hx, base + 40), Vector2(hr, hr * 0.55), Color("7cc46a").darkened(0.1 * (i % 2)))
		draw_rect(Rect2(0, base + 60, size.x, 2000), Color("6bb35c"))
		return

	var count := rng.randi_range(1, 3)
	for i in count:
		var x := rng.randf_range(-40, size.x + 40)
		var y: float = to_screen.call(c * CHUNK + rng.randf_range(0, CHUNK))
		var roll := rng.randf()
		if alt_m < 120 and roll < 0.3:
			_hot_air_balloon(Vector2(x, y), rng.randf_range(0.6, 1.0), Color.from_hsv(rng.randf(), 0.6, 0.95))
		elif alt_m < 450 and roll < 0.75:
			var drift := fposmod(x + _time * (8.0 + wind * 60.0), size.x + 300) - 150
			_cloud(Vector2(drift, y), rng.randf_range(0.6, 1.4), 1.0 if alt_m < 300 else 0.6)
		elif alt_m >= 60 and alt_m < 320:
			var bx := fposmod(x + _time * 40.0, size.x + 100) - 50
			_bird(Vector2(bx, y + sin(_time * 3.0 + i) * 6.0))
		elif alt_m >= 250 and alt_m < 500:
			var px := fposmod(x - _time * 70.0, size.x + 200) - 100
			_plane(Vector2(px, y))
		if alt_m > 380:
			var n := int(clampf((alt_m - 380) / 40.0, 0, 18))
			for s in n:
				var sy: float = to_screen.call(c * CHUNK + rng.randf_range(0, CHUNK))
				var sp := Vector2(rng.randf_range(0, size.x), sy)
				var tw := 0.6 + 0.4 * sin(_time * rng.randf_range(1, 4) + s)
				draw_circle(sp, rng.randf_range(1.0, 2.6), Color(1, 1, 1, tw))
		if alt_m > 700 and rng.randf() < 0.25:
			_satellite(Vector2(fposmod(x + _time * 25.0, size.x), y))
	if c == floori(-1000.0 * Zones.PX_PER_M * PARALLAX / CHUNK):
		_planet(Vector2(size.x * 0.75, to_screen.call(c * CHUNK)))


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)


func _cloud(p: Vector2, s: float, alpha: float) -> void:
	var col := Color(1, 1, 1, 0.85 * alpha)
	_ellipse(p, Vector2(70, 26) * s, col)
	_ellipse(p + Vector2(-38, -14) * s, Vector2(34, 26) * s, col)
	_ellipse(p + Vector2(18, -22) * s, Vector2(40, 32) * s, col)


func _hot_air_balloon(p: Vector2, s: float, col: Color) -> void:
	_ellipse(p, Vector2(30, 36) * s, col)
	draw_line(p + Vector2(-18, 26) * s, p + Vector2(-8, 52) * s, Color("5a4a3a"), 2)
	draw_line(p + Vector2(18, 26) * s, p + Vector2(8, 52) * s, Color("5a4a3a"), 2)
	draw_rect(Rect2(p + Vector2(-10, 50) * s, Vector2(20, 14) * s), Color("8a5a2a"))


func _bird(p: Vector2) -> void:
	var flap := sin(_time * 10.0 + p.x) * 5.0
	draw_polyline(PackedVector2Array([p + Vector2(-12, -flap), p, p + Vector2(12, -flap)]), Color("2b3440"), 2.5)


func _plane(p: Vector2) -> void:
	draw_line(p, p + Vector2(46, 0), Color("eef2f6"), 8)
	draw_line(p + Vector2(18, 0), p + Vector2(28, -14), Color("d0d8e0"), 5)
	draw_line(p + Vector2(40, 0), p + Vector2(46, -10), Color("d0d8e0"), 4)
	draw_line(p + Vector2(46, 0), p + Vector2(160, 0), Color(1, 1, 1, 0.35), 3)


func _satellite(p: Vector2) -> void:
	draw_rect(Rect2(p - Vector2(8, 8), Vector2(16, 16)), Color("c8ccd4"))
	draw_rect(Rect2(p + Vector2(-40, -5), Vector2(28, 10)), Color("3d6fc4"))
	draw_rect(Rect2(p + Vector2(12, -5), Vector2(28, 10)), Color("3d6fc4"))


func _planet(p: Vector2) -> void:
	var ring := Color(1, 0.9, 0.7, 0.75)
	_ring_half(p, PI, TAU, ring) # back half, behind the planet
	draw_circle(p, 90, Color("e08f62"))
	draw_circle(p + Vector2(-20, -20), 70, Color("eba57d"))
	_ring_half(p, 0.0, PI, ring) # front half


func _ring_half(p: Vector2, a0: float, a1: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var a := lerpf(a0, a1, i / 24.0)
		pts.append(p + Vector2(cos(a) * 160.0, sin(a) * 38.0).rotated(-0.25))
	draw_polyline(pts, col, 8.0, true)
