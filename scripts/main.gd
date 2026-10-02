extends Node2D
## Sky Stack: drop odd objects from the crane and build as high as you can.

const IslandScript := preload("res://scripts/island.gd")
const SkyScript := preload("res://scripts/sky_background.gd")
const HudScript := preload("res://scripts/hud.gd")

const CRANE_SPEED := 560.0
const CRANE_RANGE := 340.0
const RESPAWN_DELAY := 0.75
const STONE_DEPTH := 900.0 # pieces this far below the top are locked in place
const LOSE_Y := 700.0 # fell past the island
const START_LIVES := 3
const MAX_LIVES := 5
const WIND_FORCE := 320.0

enum Mode { TITLE, PLAYING, PAUSED, OVER }

var mode := Mode.TITLE
var autopilot := false
var forced_kinds: Array[String] = [] # tests: exact drop order
var rng := RandomNumberGenerator.new()

var pieces_root: Node2D
var camera: Camera2D
var island: StaticBody2D
var sky: Node2D
var hud: CanvasLayer
var sfx: Sfx

var held: Piece
var next_kind := "crate"
var crane_x := 0.0
var crane_y := -900.0
var held_rot := 0.0
var spawn_timer := 0.0
var spawn_age := 0.0
var lives := START_LIVES
var dropped := 0
var height_m := 0.0
var peak_m := 0.0
var zone_idx := 0
var known_kinds: Array[String] = []
var time := 0.0
var wind_wave := 0.0
var tower_top_y := 0.0
var shake := 0.0
var over_timer := -1.0
var _touch_dir := 0
var _mouse_steer := false


func _ready() -> void:
	rng.randomize()
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	sky = SkyScript.new()
	sky_layer.add_child(sky)

	island = IslandScript.new()
	add_child(island)
	pieces_root = Node2D.new()
	pieces_root.name = "Pieces"
	add_child(pieces_root)

	camera = Camera2D.new()
	camera.position = Vector2(0, -300)
	add_child(camera)
	camera.make_current()

	sfx = Sfx.new()
	add_child(sfx)

	hud = HudScript.new()
	add_child(hud)
	hud.play_pressed.connect(start_game)
	hud.restart_pressed.connect(start_game)
	hud.resume_pressed.connect(_resume)
	hud.pause_pressed.connect(_toggle_pause)
	hud.move_held.connect(func(dir: int, on: bool) -> void: _touch_dir = dir if on else 0)
	hud.rotate_pressed.connect(_rotate)
	hud.drop_pressed.connect(_drop)
	process_mode = Node.PROCESS_MODE_ALWAYS
	pieces_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.show_title(GameState.best_height)
	_update_hud()


# ---------------------------------------------------------------- flow

func start_game() -> void:
	get_tree().paused = false
	for c in pieces_root.get_children():
		c.queue_free()
	held = null
	lives = START_LIVES
	dropped = 0
	height_m = 0.0
	peak_m = 0.0
	zone_idx = 0
	tower_top_y = 0.0
	time = 0.0
	over_timer = -1.0
	crane_x = 0.0
	known_kinds = PieceCatalog.unlocked(0.0)
	next_kind = "crate"
	spawn_timer = 0.2
	mode = Mode.PLAYING
	hud.clear_overlay()
	hud.set_playing(true)
	hud.toast("Build to the sky!")
	_update_hud()


func _toggle_pause() -> void:
	if mode == Mode.PLAYING:
		mode = Mode.PAUSED
		get_tree().paused = true
		hud.show_pause()
	elif mode == Mode.PAUSED:
		_resume()


func _resume() -> void:
	if mode != Mode.PAUSED:
		return
	mode = Mode.PLAYING
	get_tree().paused = false
	hud.clear_overlay()


func _game_over() -> void:
	mode = Mode.OVER
	if held:
		held.queue_free()
		held = null
	var record := GameState.submit_run(peak_m, dropped)
	sfx.play("record" if record else "over")
	hud.show_game_over(peak_m, GameState.best_height, record, dropped, Zones.zone_at(peak_m)["name"])
	_update_hud()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		return
	if mode != Mode.PLAYING:
		return
	if event.is_action_pressed("rotate_ccw"):
		_rotate(-1)
	elif event.is_action_pressed("rotate_cw"):
		_rotate(1)
	elif event.is_action_pressed("drop"):
		_drop()
	elif event is InputEventMouseMotion:
		_mouse_steer = true
		crane_x = clampf(get_global_mouse_position().x, -CRANE_RANGE, CRANE_RANGE)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				crane_x = clampf(get_global_mouse_position().x, -CRANE_RANGE, CRANE_RANGE)
				_drop()
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_UP:
				_rotate(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_rotate(-1)


func _rotate(dir: int) -> void:
	if mode != Mode.PLAYING or not held:
		return
	held_rot += dir * PI / 4.0
	sfx.play("rotate")


func _drop() -> void:
	if mode != Mode.PLAYING or not held:
		return
	held.rotation = held_rot
	held.global_position = _held_position()
	held.release()
	held.landed.connect(_on_piece_landed)
	held = null
	dropped += 1
	spawn_timer = RESPAWN_DELAY
	sfx.play("drop")
	hud.set_pieces("", next_kind)


# ---------------------------------------------------------------- world queries (used by pieces)

func altitude_m(y: float) -> float:
	return maxf(0.0, -y / Zones.PX_PER_M)


func gravity_factor_at(y: float) -> float:
	return Zones.gravity_factor(altitude_m(y))


func wind_at(y: float) -> float:
	return Zones.wind_strength(altitude_m(y)) * wind_wave * WIND_FORCE


func on_glued(_piece: Piece) -> void:
	sfx.play("squish")


# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	if mode == Mode.PAUSED:
		return
	time += delta
	wind_wave = sin(time * 0.55) * 0.75 + sin(time * 1.9 + 1.3) * 0.25
	if mode == Mode.PLAYING or mode == Mode.OVER:
		_check_lost_pieces()
		_measure_tower()
	if mode == Mode.PLAYING:
		_update_crane(delta)
		if over_timer >= 0.0:
			over_timer -= delta
			if over_timer < 0.0:
				_game_over()


func _process(delta: float) -> void:
	var view := get_viewport_rect().size
	var target_y := minf(-300.0, tower_top_y - view.y * 0.05)
	camera.position.y = lerpf(camera.position.y, target_y, clampf(delta * 2.5, 0.0, 1.0))
	shake = maxf(0.0, shake - delta * 30.0)
	camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	crane_y = camera.position.y - view.y * 0.5 + 230.0
	if held:
		held.global_position = held.global_position.lerp(_held_position(), clampf(delta * 18.0, 0.0, 1.0))
		held.rotation = lerp_angle(held.rotation, held_rot, clampf(delta * 14.0, 0.0, 1.0))
	sky.cam_alt_px = -camera.position.y
	sky.wind = Zones.wind_strength(altitude_m(camera.position.y)) * wind_wave
	queue_redraw()
	_update_hud()


func _held_position() -> Vector2:
	var drop := 70.0
	if held and held.def.get("balloon", false):
		drop = 110.0
	return Vector2(crane_x, crane_y + drop)


func _update_crane(delta: float) -> void:
	var axis := Input.get_axis("move_left", "move_right") + _touch_dir
	if axis != 0.0:
		_mouse_steer = false
	crane_x = clampf(crane_x + clampf(axis, -1.0, 1.0) * CRANE_SPEED * delta, -CRANE_RANGE, CRANE_RANGE)
	if held:
		spawn_age += delta
		if autopilot:
			_autopilot(delta)
	else:
		spawn_timer -= delta
		if spawn_timer <= 0.0 and lives > 0 and over_timer < 0.0:
			_spawn_held()


func _spawn_held() -> void:
	held = Piece.new()
	held.setup(next_kind, self)
	pieces_root.add_child(held)
	held.global_position = _held_position()
	held_rot = 0.0
	spawn_age = 0.0
	next_kind = forced_kinds.pop_front() if forced_kinds.size() > 0 else PieceCatalog.pick(rng, peak_m)
	hud.set_pieces(held.kind, next_kind)


func _on_piece_landed(piece: Piece, impact: float) -> void:
	var vol := clampf(remap(impact, 50.0, 900.0, -18.0, 0.0), -18.0, 0.0)
	match piece.kind:
		"anvil", "beam":
			sfx.play("clink", 0.8, vol)
			sfx.play("thud", 0.7, vol)
			shake = clampf(impact / 120.0, 0.0, 8.0)
		"spring":
			sfx.play("boing", 1.0, vol)
		"pillow", "balloon":
			sfx.play("thud", 1.4, vol - 6.0)
		_:
			sfx.play("thud", randf_range(0.9, 1.15), vol)


func _check_lost_pieces() -> void:
	for p in pieces_root.get_children():
		if p is Piece and p != held and not p.is_queued_for_deletion() and p.global_position.y > LOSE_Y:
			p.queue_free()
			if mode != Mode.PLAYING or lives <= 0:
				continue
			lives -= 1
			shake = 10.0
			sfx.play("lose")
			if lives <= 0:
				hud.toast("Oh no!")
				over_timer = 1.2
			else:
				hud.toast("Lost one! %d %s left" % [lives, "heart" if lives == 1 else "hearts"])


func _measure_tower() -> void:
	var top := 0.0
	for p in pieces_root.get_children():
		if p is Piece and not p.is_queued_for_deletion() and p.is_settled():
			top = minf(top, p.top_y())
	tower_top_y = top
	height_m = altitude_m(top)
	if height_m > peak_m:
		peak_m = height_m
		_check_milestones()
	# Lock pieces buried deep in the tower so very tall towers stay stable.
	for p in pieces_root.get_children():
		if p is Piece and not p.set_in_stone and p.is_settled() and p.top_y() > tower_top_y + STONE_DEPTH:
			p.turn_to_stone()


func _check_milestones() -> void:
	if mode != Mode.PLAYING:
		return
	var z := Zones.index_at(peak_m)
	if z > zone_idx:
		zone_idx = z
		var zone: Dictionary = Zones.LIST[z]
		var extra := ""
		if lives < MAX_LIVES:
			lives += 1
			extra = "\n+1 heart"
		var note := ""
		if zone["wind"] > 0.0:
			note = "\nWatch the wind!"
		elif zone["gravity"] < 1.0:
			note = "\nGravity is getting weaker..."
		hud.toast("%s!%s%s" % [zone["name"], extra, note])
		sfx.play("zone")
	for k in PieceCatalog.unlocked(peak_m):
		if not known_kinds.has(k):
			known_kinds.append(k)
			if zone_idx == Zones.index_at(peak_m) and k != "crate":
				hud.toast("New object: %s!" % PieceCatalog.get_def(k)["name"])
				sfx.play("unlock")


func _autopilot(_delta: float) -> void:
	# Simple bot used by tests and for demos: drop near the top piece's x.
	var target_x := 0.0
	var best := INF
	for p in pieces_root.get_children():
		if p is Piece and p != held and p.is_settled() and p.top_y() < best:
			best = p.top_y()
			target_x = p.global_position.x
	target_x = clampf(target_x, -120.0, 120.0)
	crane_x = move_toward(crane_x, target_x, CRANE_SPEED / 60.0)
	if spawn_age > 0.5 and absf(crane_x - target_x) < 2.0:
		_drop()


func _update_hud() -> void:
	var zone: String = Zones.zone_at(height_m)["name"]
	var wind := Zones.wind_strength(altitude_m(tower_top_y)) * wind_wave
	hud.update_stats(height_m, peak_m, GameState.best_height, lives if mode != Mode.TITLE else START_LIVES, zone, wind)


# ---------------------------------------------------------------- drawing (crane)

func _draw() -> void:
	if mode != Mode.PLAYING and mode != Mode.PAUSED:
		return
	var view := get_viewport_rect().size
	var top_y := camera.position.y - view.y * 0.5
	var hook := Vector2(crane_x, crane_y)
	# Rail and trolley.
	draw_rect(Rect2(-CRANE_RANGE - 60, top_y + 60, (CRANE_RANGE + 60) * 2, 16), Color("f4c542"))
	for i in 18:
		var x := -CRANE_RANGE - 60 + i * 45.0
		draw_line(Vector2(x, top_y + 60), Vector2(x + 22, top_y + 76), Color("1b2a44"), 4)
	draw_rect(Rect2(crane_x - 34, top_y + 50, 68, 34), Color("ff9f43"))
	draw_line(Vector2(crane_x, top_y + 84), hook, Color("3b3b3b"), 4)
	draw_arc(hook + Vector2(0, 10), 12, -0.3, PI + 0.3, 12, Color("3b3b3b"), 5)
	# Drop guide.
	if held:
		var y := hook.y + 120.0
		var end := tower_top_y - 10.0
		while y < end:
			draw_line(Vector2(crane_x, y), Vector2(crane_x, minf(y + 18.0, end)), Color(1, 1, 1, 0.55), 3)
			y += 34.0
