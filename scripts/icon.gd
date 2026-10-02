extends Control
## Vector icons drawn in code, so they look the same on every platform
## (the web build has no system font fallback for symbol glyphs).

var kind := "heart":
	set(v):
		kind = v
		queue_redraw()
var count := 1:
	set(v):
		count = v
		queue_redraw()
var color := Color.WHITE


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.32
	match kind:
		"hearts":
			var hs := size.y * 0.42
			for i in count:
				_heart(Vector2(hs + i * hs * 2.4, size.y * 0.5), hs)
		"left", "right":
			var s := -1.0 if kind == "left" else 1.0
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(r * s, 0), c + Vector2(-r * 0.7 * s, -r), c + Vector2(-r * 0.7 * s, r)]), color)
		"ccw", "cw":
			var s := -1.0 if kind == "ccw" else 1.0
			var a0 := -PI * 0.5 - 1.9 * s
			var a1 := -PI * 0.5 + 0.9 * s
			draw_arc(c, r, minf(a0, a1), maxf(a0, a1), 24, color, r * 0.32, true)
			var tip := c + Vector2.from_angle(a1) * r
			var dir := Vector2.from_angle(a1 + PI * 0.5 * s)
			var side := dir.orthogonal()
			draw_colored_polygon(PackedVector2Array([
				tip + dir * r * 0.55, tip + side * r * 0.45, tip - side * r * 0.45]), color)
		"pause":
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r), Vector2(r * 0.5, r * 2)), color)
			draw_rect(Rect2(c + Vector2(r * 0.2, -r), Vector2(r * 0.5, r * 2)), color)


func _heart(p: Vector2, s: float) -> void:
	var col := Color("ff5d73")
	var k := s * 0.85
	draw_circle(p + Vector2(-k * 0.52, -k * 0.35), k * 0.62, col)
	draw_circle(p + Vector2(k * 0.52, -k * 0.35), k * 0.62, col)
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-k * 1.12, -k * 0.15), p + Vector2(k * 1.12, -k * 0.15), p + Vector2(0, k * 1.05)]), col)
	draw_circle(p + Vector2(-k * 0.6, -k * 0.55), k * 0.16, Color(1, 1, 1, 0.7))
