extends CanvasLayer
## On-screen stats, touch buttons and the title / pause / game-over panels.

signal play_pressed
signal resume_pressed
signal restart_pressed
signal move_held(dir: int, pressed: bool)
signal rotate_pressed(dir: int)
signal drop_pressed
signal pause_pressed

const PreviewScript := preload("res://scripts/piece_preview.gd")
const IconScript := preload("res://scripts/icon.gd")
const INK := Color("1b2a44")

var height_label: Label
var best_label: Label
var hearts: Control
var zone_label: Label
var wind_label: Label
var piece_label: Label
var preview: Control
var toast_label: Label
var controls: HBoxContainer
var overlay: Control
var _toast_tween: Tween


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top"]:
		top.add_theme_constant_override("margin_" + side, 24)
	root.add_child(top)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)
	height_label = _label("0 m", 72)
	best_label = _label("Best 0 m", 26)
	zone_label = _label("Meadow", 30)
	wind_label = _label("", 28)
	for l in [height_label, best_label, zone_label]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		left.add_child(l)
	hearts = IconScript.new()
	hearts.kind = "hearts"
	hearts.custom_minimum_size = Vector2(260, 46)
	hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(hearts)
	wind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(wind_label)

	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)
	var pause_btn := _icon_button("pause")
	pause_btn.custom_minimum_size = Vector2(72, 72)
	pause_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	right.add_child(pause_btn)
	var next_label := _label("Next", 24)
	right.add_child(next_label)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.35), 18))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview = PreviewScript.new()
	preview.custom_minimum_size = Vector2(130, 130)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(preview)
	right.add_child(frame)

	piece_label = _label("", 26)
	piece_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	piece_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	piece_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	piece_label.offset_top = -210
	piece_label.offset_bottom = -150
	root.add_child(piece_label)

	toast_label = _label("", 44, Color("fff3b0"))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.set_anchors_preset(Control.PRESET_CENTER)
	toast_label.offset_left = -330
	toast_label.offset_right = 330
	toast_label.offset_top = -260
	toast_label.offset_bottom = -120
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)

	controls = HBoxContainer.new()
	controls.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_top = -140
	controls.offset_bottom = -24
	controls.offset_left = 16
	controls.offset_right = -16
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 12)
	root.add_child(controls)
	var hold_btn := func(icon: String, dir: int) -> Button:
		var b := _icon_button(icon)
		b.button_down.connect(func() -> void: move_held.emit(dir, true))
		b.button_up.connect(func() -> void: move_held.emit(dir, false))
		return b
	controls.add_child(hold_btn.call("left", -1))
	var rl := _icon_button("ccw")
	rl.pressed.connect(func() -> void: rotate_pressed.emit(-1))
	controls.add_child(rl)
	var drop := _button("DROP", 34, Color("ff9f43"))
	drop.custom_minimum_size.x = 170
	drop.pressed.connect(func() -> void: drop_pressed.emit())
	controls.add_child(drop)
	var rr := _icon_button("cw")
	rr.pressed.connect(func() -> void: rotate_pressed.emit(1))
	controls.add_child(rr)
	controls.add_child(hold_btn.call("right", 1))
	for b in controls.get_children():
		(b as Button).focus_mode = Control.FOCUS_NONE
		if (b as Button).custom_minimum_size.x < 100:
			(b as Button).custom_minimum_size = Vector2(96, 96)

	overlay = CenterContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)


# ---------------------------------------------------------------- stats

func update_stats(height_m: float, peak_m: float, best_m: float, lives: int, zone: String, wind: float) -> void:
	height_label.text = "%d m" % int(round(height_m))
	best_label.text = "Peak %d m   ·   Record %d m" % [int(round(peak_m)), int(round(best_m))]
	hearts.count = maxi(lives, 0)
	zone_label.text = zone
	if absf(wind) > 0.05:
		var arrow := ">" if wind > 0 else "<"
		wind_label.text = "Wind " + arrow.repeat(clampi(int(absf(wind) * 3.0) + 1, 1, 3))
	else:
		wind_label.text = ""


func set_pieces(held_kind: String, next_kind: String) -> void:
	preview.kind = next_kind
	if held_kind == "":
		piece_label.text = ""
	else:
		var def := PieceCatalog.get_def(held_kind)
		piece_label.text = "%s — %s" % [def["name"], def["tip"]]


func toast(text: String) -> void:
	toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	toast_label.modulate.a = 1.0
	toast_label.scale = Vector2.ONE
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)


func set_playing(on: bool) -> void:
	controls.visible = on
	piece_label.visible = on


# ---------------------------------------------------------------- panels

func clear_overlay() -> void:
	for c in overlay.get_children():
		c.queue_free()


func show_title(best_m: float) -> void:
	clear_overlay()
	set_playing(false)
	var v := _panel()
	v.add_child(_label("SKY STACK", 92, Color.WHITE, 16))
	v.add_child(_label("How high can you build?", 32))
	v.add_child(_spacer(10))
	v.add_child(_label("Arrows / A D / mouse   move the crane\nQ E / wheel   rotate\nSpace / click   drop", 24))
	v.add_child(_label("Drop 3 pieces off the island and it's over.\nEach new sky zone gives back a heart.", 24))
	if best_m > 0:
		v.add_child(_label("Record: %d m" % int(round(best_m)), 34, Color("fff3b0")))
	v.add_child(_spacer(10))
	var b := _button("PLAY", 48, Color("ff9f43"))
	b.custom_minimum_size = Vector2(320, 110)
	b.pressed.connect(func() -> void: play_pressed.emit())
	v.add_child(b)
	b.grab_focus.call_deferred()


func show_pause() -> void:
	clear_overlay()
	var v := _panel()
	v.add_child(_label("Paused", 64, Color.WHITE, 12))
	var resume := _button("Resume", 40, Color("ff9f43"))
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	v.add_child(resume)
	var restart := _button("Restart", 34)
	restart.pressed.connect(func() -> void: restart_pressed.emit())
	v.add_child(restart)
	var sound := _button("Sound: %s" % ("On" if GameState.sound_on else "Off"), 30)
	sound.pressed.connect(func() -> void:
		GameState.sound_on = not GameState.sound_on
		GameState.save()
		sound.text = "Sound: %s" % ("On" if GameState.sound_on else "Off"))
	v.add_child(sound)
	resume.grab_focus.call_deferred()


func show_game_over(peak_m: float, best_m: float, record: bool, dropped: int, zone: String) -> void:
	clear_overlay()
	set_playing(false)
	var v := _panel()
	v.add_child(_label("Tower toppled!", 56, Color.WHITE, 12))
	v.add_child(_label("%d m" % int(round(peak_m)), 110, Color("fff3b0"), 18))
	v.add_child(_label("reached %s with %d pieces" % [zone, dropped], 28))
	if record:
		v.add_child(_label("NEW RECORD!", 44, Color("ff9f43"), 12))
	else:
		v.add_child(_label("Record: %d m" % int(round(best_m)), 30))
	v.add_child(_spacer(10))
	var b := _button("Build again", 44, Color("ff9f43"))
	b.custom_minimum_size = Vector2(360, 100)
	b.pressed.connect(func() -> void: restart_pressed.emit())
	v.add_child(b)
	b.grab_focus.call_deferred()


# ---------------------------------------------------------------- helpers

func _panel() -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(Color(0.08, 0.12, 0.22, 0.82), 32, 36))
	overlay.add_child(p)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	return v


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _box(color: Color, radius: int, pad := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


func _label(text: String, font_size: int, color := Color.WHITE, outline := 8) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _icon_button(icon: String) -> Button:
	var b := _button("", 20)
	b.custom_minimum_size = Vector2(72, 72)
	var ic := IconScript.new()
	ic.kind = icon
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	return b


func _button(text: String, font_size: int, color := Color("3d5a80")) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_stylebox_override("normal", _box(color, 22, 14))
	b.add_theme_stylebox_override("hover", _box(color.lightened(0.15), 22, 14))
	b.add_theme_stylebox_override("pressed", _box(color.darkened(0.2), 22, 14))
	b.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), 22, 14))
	return b
