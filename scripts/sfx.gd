class_name Sfx
extends Node
## Tiny procedural sound bank: no audio files needed.

const RATE := 22050

var _bank := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	_bank["drop"] = _tone(520.0, 260.0, 0.18, 0.35, 0.0)
	_bank["thud"] = _tone(140.0, 60.0, 0.22, 0.8, 0.35)
	_bank["clink"] = _tone(1400.0, 1100.0, 0.12, 0.35, 0.05)
	_bank["boing"] = _tone(220.0, 660.0, 0.35, 0.5, 0.0, true)
	_bank["squish"] = _tone(300.0, 120.0, 0.2, 0.5, 0.5)
	_bank["rotate"] = _tone(900.0, 1100.0, 0.05, 0.2, 0.0)
	_bank["lose"] = _tone(400.0, 90.0, 0.6, 0.6, 0.1)
	_bank["zone"] = _arpeggio([523.25, 659.25, 783.99, 1046.5], 0.11, 0.4)
	_bank["record"] = _arpeggio([392.0, 523.25, 659.25, 783.99, 1046.5, 1318.5], 0.09, 0.4)
	_bank["over"] = _arpeggio([523.25, 392.0, 329.63, 261.63], 0.16, 0.4)
	_bank["unlock"] = _arpeggio([783.99, 1046.5], 0.1, 0.35)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not GameState.sound_on or not _bank.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _bank[sound]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func _tone(f0: float, f1: float, dur: float, vol: float, noise: float, wobble := false) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 31.0 + f1)
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		if wobble:
			f *= 1.0 + 0.15 * sin(t * 40.0)
		phase += TAU * f / RATE
		var s := sin(phase) * (1.0 - noise) + rng.randf_range(-1.0, 1.0) * noise
		var env := (1.0 - t) * (1.0 - t) * minf(1.0, i / (RATE * 0.004))
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _arpeggio(freqs: Array, step: float, vol: float) -> AudioStreamWAV:
	var per := int(step * RATE)
	var tail := int(0.25 * RATE)
	var n := per * freqs.size() + tail
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var s := 0.0
		for k in freqs.size():
			var start := k * per
			if i < start:
				continue
			var t := float(i - start) / RATE
			var f: float = freqs[k]
			s += sin(TAU * f * t) * exp(-t * 7.0) * 0.6 + sin(TAU * f * 2.0 * t) * exp(-t * 12.0) * 0.2
		data.encode_s16(i * 2, int(clampf(s * vol, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
