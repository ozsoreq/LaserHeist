extends Control
## Draws a scaled-down piece (used for the "Next" preview).

var kind := "":
	set(value):
		kind = value
		queue_redraw()


func _draw() -> void:
	if kind == "":
		return
	var def := PieceCatalog.get_def(kind)
	var extent := 80.0
	match def["shape"]:
		"rect":
			extent = maxf(def["size"].x, def["size"].y)
		"circle":
			extent = def["radius"] * 2.0
		"poly":
			extent = 120.0
	if def.get("balloon", false):
		extent = 150.0
	var s := minf(1.0, (minf(size.x, size.y) - 16.0) / extent)
	var c := size * 0.5
	if def.get("balloon", false):
		c.y += 30.0 * s
	draw_set_transform(c, 0.0, Vector2.ONE)
	PieceCatalog.draw_piece(self, kind, s)
