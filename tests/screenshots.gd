extends Node
## Renders a few gameplay screenshots (needs a display, e.g. xvfb-run):
##   godot --rendering-driver opengl3 res://tests/screenshots.tscn -- out=/tmp/shots

var main: Node2D
var out_dir := "user://shots"
var frame := 0
var shots := {
	30: "title",
	400: "early",
	1500: "building",
	2290: "jetstream",
}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out_dir = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.rng.seed = 99


func _process(_delta: float) -> void:
	frame += 1
	if frame == 60:
		main.autopilot = true
		main.start_game()
		main.forced_kinds.assign(["crate", "plank", "crate", "crate", "pillow", "crate", "anvil", "crate", "plank", "crate", "glue", "crate", "crate", "beam", "crate", "crate", "crate", "crate", "crate", "crate", "crate", "crate", "crate", "crate"])
	if frame == 2000:
		# Jump high to preview the upper sky zones.
		main.set_physics_process(false)
		main.camera.position.y = -330.0 * Zones.PX_PER_M
		main.tower_top_y = -330.0 * Zones.PX_PER_M
	if frame == 2300:
		main.camera.position.y = -900.0 * Zones.PX_PER_M
		main.tower_top_y = -900.0 * Zones.PX_PER_M
	if shots.has(frame):
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [out_dir, shots[frame]])
		print("saved ", shots[frame])
	if frame == 2300 + 40:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/space.png" % out_dir)
	if frame == 2700:
		get_tree().quit()
