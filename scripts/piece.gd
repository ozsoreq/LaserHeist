class_name Piece
extends RigidBody2D
## One droppable object. Held by the crane (frozen), then falls, lands and settles.

signal landed(piece: Piece, impact: float)

enum State { HELD, FALLING, LANDED }

var kind := "crate"
var def: Dictionary
var state := State.HELD
var settle_time := 0.0
var set_in_stone := false
var base_gravity_scale := 1.0
var glued_to: Array[Node] = []
var world: Node # Main; provides wind and gravity per altitude.

var _outline: PackedVector2Array
var _radius := 0.0


func setup(p_kind: String, p_world: Node) -> void:
	kind = p_kind
	world = p_world
	def = PieceCatalog.get_def(kind)
	mass = def["mass"]
	base_gravity_scale = def.get("gravity_scale", 1.0)
	gravity_scale = base_gravity_scale
	var mat := PhysicsMaterial.new()
	mat.friction = def["friction"]
	mat.bounce = def["bounce"]
	mat.rough = def["friction"] >= 1.0
	physics_material_override = mat
	contact_monitor = true
	max_contacts_reported = 6
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	can_sleep = true

	match def["shape"]:
		"rect":
			var cs := CollisionShape2D.new()
			var r := RectangleShape2D.new()
			r.size = def["size"]
			cs.shape = r
			add_child(cs)
		"circle":
			var cs := CollisionShape2D.new()
			var c := CircleShape2D.new()
			c.radius = def["radius"]
			_radius = def["radius"]
			cs.shape = c
			add_child(cs)
		"poly":
			var cp := CollisionPolygon2D.new()
			cp.polygon = PackedVector2Array(def["points"])
			add_child(cp)
	_outline = PieceCatalog.outline_points(def)
	body_entered.connect(_on_body_entered)
	hold()


func hold() -> void:
	state = State.HELD
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	collision_layer = 0
	collision_mask = 0


func release() -> void:
	state = State.FALLING
	collision_layer = 1
	collision_mask = 1
	freeze = false
	linear_velocity = Vector2(0, 60)
	angular_velocity = 0.0


## Locks a piece deep inside the tower so tall towers stay stable and cheap.
func turn_to_stone() -> void:
	if set_in_stone:
		return
	set_in_stone = true
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	set_deferred("freeze", true)
	queue_redraw()


func is_settled() -> bool:
	return set_in_stone or (state == State.LANDED and settle_time > 0.6)


## Highest point of the piece in global space (smallest y).
func top_y() -> float:
	if def["shape"] == "circle":
		return global_position.y - _radius
	var best := INF
	for p in _outline:
		best = minf(best, (global_transform * p).y)
	return best


func _physics_process(delta: float) -> void:
	if state == State.HELD or set_in_stone:
		return
	if world:
		gravity_scale = base_gravity_scale * world.gravity_factor_at(global_position.y)
		var wind: float = world.wind_at(global_position.y)
		if wind != 0.0:
			apply_central_force(Vector2(wind * mass, 0))
	if state == State.LANDED and linear_velocity.length() < 12.0 and absf(angular_velocity) < 0.3:
		settle_time += delta
	else:
		settle_time = 0.0


func _on_body_entered(body: Node) -> void:
	if state == State.FALLING:
		state = State.LANDED
		landed.emit(self, linear_velocity.length())
	if def.get("sticky", false) and glued_to.size() < 2 and not glued_to.has(body) and body is PhysicsBody2D:
		glued_to.append(body)
		# Joints can't be added while physics is flushing contacts.
		_weld.call_deferred(body)


func _weld(body: PhysicsBody2D) -> void:
	if not is_instance_valid(body) or not is_inside_tree():
		return
	# Two pins between the bodies make a rigid weld.
	for off in [Vector2(-18, 0), Vector2(18, 0)]:
		var pin := PinJoint2D.new()
		pin.disable_collision = false
		pin.softness = 0.0
		get_parent().add_child(pin)
		pin.global_position = global_transform * (off as Vector2)
		pin.node_a = pin.get_path_to(self)
		pin.node_b = pin.get_path_to(body)
	if world and world.has_method("on_glued"):
		world.on_glued(self)


func _draw() -> void:
	PieceCatalog.draw_piece(self, kind, 1.0, set_in_stone)
