extends Node
## Autoload: input bindings, best scores and settings (saved in user://).

const SAVE_PATH := "user://sky_stack.cfg"

var best_height := 0.0
var best_pieces := 0
var games_played := 0
var sound_on := true


func _ready() -> void:
	_register_inputs()
	load_save()


func _register_inputs() -> void:
	var binds := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"rotate_ccw": [KEY_Q, KEY_Z],
		"rotate_cw": [KEY_E, KEY_X, KEY_UP, KEY_W],
		"drop": [KEY_SPACE, KEY_DOWN, KEY_S, KEY_ENTER],
		"pause": [KEY_ESCAPE, KEY_P],
	}
	var pad := {
		"move_left": [JOY_BUTTON_DPAD_LEFT],
		"move_right": [JOY_BUTTON_DPAD_RIGHT],
		"rotate_ccw": [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_X],
		"rotate_cw": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_Y],
		"drop": [JOY_BUTTON_A],
		"pause": [JOY_BUTTON_START],
	}
	for action in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		for b in pad[action]:
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(action, jb)
	for dir in [["move_left", -1.0], ["move_right", 1.0]]:
		var axis := InputEventJoypadMotion.new()
		axis.axis = JOY_AXIS_LEFT_X
		axis.axis_value = dir[1]
		InputMap.action_add_event(dir[0], axis)


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best_height = cfg.get_value("score", "best_height", 0.0)
	best_pieces = cfg.get_value("score", "best_pieces", 0)
	games_played = cfg.get_value("score", "games_played", 0)
	sound_on = cfg.get_value("settings", "sound_on", true)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best_height", best_height)
	cfg.set_value("score", "best_pieces", best_pieces)
	cfg.set_value("score", "games_played", games_played)
	cfg.set_value("settings", "sound_on", sound_on)
	cfg.save(SAVE_PATH)


## Records a finished run. Returns true if it set a new height record.
func submit_run(height: float, pieces: int) -> bool:
	games_played += 1
	var record := height > best_height
	if record:
		best_height = height
	best_pieces = maxi(best_pieces, pieces)
	save()
	return record
