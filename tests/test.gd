extends Node
## Headless test run:
##   godot --headless --fixed-fps 60 res://tests/test.tscn
## Exits with code 0 when every check passes.

var main: Node2D
var failures: Array[String] = []
var frame := 0
var phase := "build"


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		failures.append(msg)


func _ready() -> void:
	print("Sky Stack tests")
	_unit_tests()
	main = load("res://scenes/main.tscn").instantiate()
	main.autopilot = true
	add_child(main)
	main.rng.seed = 1234
	main.start_game()
	# Drop every kind of object at least once.
	var all: Array[String] = []
	for k in PieceCatalog.KINDS:
		all.append(k)
	main.forced_kinds.assign(["crate", "crate", "plank", "crate", "crate"] + all + ["crate", "crate"])


func _unit_tests() -> void:
	for k in PieceCatalog.KINDS:
		var d := PieceCatalog.get_def(k)
		check(PieceCatalog.outline_points(d).size() >= 3, "%s has an outline" % k)
	check(PieceCatalog.unlocked(0.0).has("crate"), "crates are unlocked from the start")
	check(not PieceCatalog.unlocked(0.0).has("anvil"), "anvils unlock later")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ok := true
	for i in 200:
		if not PieceCatalog.unlocked(30.0).has(PieceCatalog.pick(rng, 30.0)):
			ok = false
	check(ok, "random picks only use unlocked objects")
	check(Zones.zone_at(0.0)["name"] == "Meadow", "ground level is the Meadow")
	check(Zones.zone_at(260.0)["name"] == "Jet Stream", "260 m is the Jet Stream")
	check(Zones.gravity_factor(1200.0) < Zones.gravity_factor(10.0), "gravity weakens in space")
	check(Zones.wind_strength(10.0) == 0.0 and Zones.wind_strength(300.0) > 0.0, "wind only blows up high")


func _physics_process(_delta: float) -> void:
	frame += 1
	match phase:
		"build":
			if frame == 2400:
				print("  info dropped=%d peak=%.1f m lives=%d" % [main.dropped, main.peak_m, main.lives])
				check(main.dropped >= 12, "the autopilot keeps dropping pieces")
				check(main.peak_m > 40.0, "the tower grows past 40 m")
				var stone := 0
				for p in main.pieces_root.get_children():
					if p is Piece and p.set_in_stone:
						stone += 1
				check(main.height_m > 0.0, "a settled tower is measured")
				check(main.lives >= 0, "hearts never go negative")
				print("  info pieces set in stone: %d" % stone)
				_start_lose_test()
		"lose":
			if frame == 2400 + 240:
				check(main.lives == _lives_before - 1, "a piece falling off the island costs a heart")
				_start_game_over_test()
		"over":
			if frame == 2400 + 240 + 600:
				check(main.mode == main.Mode.OVER, "running out of hearts ends the game")
				check(GameState.best_height >= main.peak_m, "the record is saved")
				_finish()


var _lives_before := 0


func _start_lose_test() -> void:
	phase = "lose"
	main.autopilot = false
	main.start_game()
	_lives_before = main.lives
	main._spawn_held()
	main.crane_x = main.CRANE_RANGE
	main._process(0.0)
	main._drop()


func _start_game_over_test() -> void:
	phase = "over"
	main.lives = 1
	main.spawn_timer = 0.0
	main._spawn_held()
	main.crane_x = -main.CRANE_RANGE
	main._drop()


func _finish() -> void:
	print("%d failure(s)" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
