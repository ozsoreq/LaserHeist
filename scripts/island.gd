extends StaticBody2D
## The floating island the tower is built on. Its grassy top sits at y = 0.

const WIDTH := 380.0

var _rock: PackedVector2Array


func _ready() -> void:
	var mat := PhysicsMaterial.new()
	mat.friction = 1.0
	physics_material_override = mat
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(WIDTH, 40)
	cs.shape = r
	cs.position = Vector2(0, 20)
	add_child(cs)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	_rock = PackedVector2Array([Vector2(-WIDTH * 0.5 - 6, 8), Vector2(WIDTH * 0.5 + 6, 8)])
	var steps := 9
	for i in steps + 1:
		var t := float(i) / steps
		var x := lerpf(WIDTH * 0.5, -WIDTH * 0.5, t)
		var depth := sin(t * PI) * 200.0 + rng.randf_range(-18, 18) + 30.0
		_rock.append(Vector2(x * (1.0 - 0.35 * sin(t * PI)), depth))


func _draw() -> void:
	draw_colored_polygon(_rock, Color("8a6a4f"))
	var shade := PackedVector2Array()
	for p in _rock:
		shade.append(Vector2(p.x * 0.7 + 20, maxf(p.y * 0.85, 30)))
	draw_colored_polygon(shade, Color("745640"))
	draw_rect(Rect2(-WIDTH * 0.5 - 8, -4, WIDTH + 16, 22), Color("6cc24a"))
	draw_rect(Rect2(-WIDTH * 0.5 - 8, -4, WIDTH + 16, 7), Color("8ee06a"))
	for i in 7:
		var x := -WIDTH * 0.45 + i * WIDTH * 0.15
		draw_circle(Vector2(x, 24), 4, Color("ffe066") if i % 2 == 0 else Color("ff8fab"))
