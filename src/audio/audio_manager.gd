extends Node
## Música, ambiente y efectos de sonido.
##
## Crea los buses Música, Ambiente y Efectos (debajo de Master) y aplica los
## volúmenes de Settings (sección "audio"). La música cambia con un fundido
## cruzado; en el juego hay una capa de persecución que sube cuando la
## policía te persigue. Todo el audio se genera con tools/generate_audio.py.
## En el navegador el sonido empieza con el primer clic o toque (regla de los navegadores).

const BUSES := {"music": "Musica", "ambient": "Ambiente", "sfx": "Efectos"}
const TRACKS := {
	"menu": "res://assets/audio/music_menu.ogg",
	"explore": "res://assets/audio/music_explore.ogg",
	"chase": "res://assets/audio/music_chase.ogg",
	"ambient": "res://assets/audio/ambient_city.ogg",
}
const SFX := ["click", "hover", "key", "pickup", "discover", "unlock", "error", "hint", "open",
		"alert", "caught", "win", "lose"]
const FADE := 1.6
const SILENT_DB := -60.0
const SFX_VOICES := 6

var current_music := ""
var _music: Array[AudioStreamPlayer] = []
var _active := 0
var _chase: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _streams: Dictionary = {}
var _chase_target := 0.0
var _chase_level := 0.0
var _last_hover := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key: String in BUSES:
		if AudioServer.get_bus_index(BUSES[key]) < 0:
			var i := AudioServer.bus_count
			AudioServer.add_bus(i)
			AudioServer.set_bus_name(i, BUSES[key])
			AudioServer.set_bus_send(i, "Master")
	for i in 2:
		_music.append(_player("music"))
		_music[i].volume_db = SILENT_DB
	_chase = _player("music")
	_chase.volume_db = SILENT_DB
	_ambient = _player("ambient")
	for i in SFX_VOICES:
		_voices.append(_player("sfx"))
	apply_volumes()
	Settings.changed.connect(func(section: String, _k: String, _v: Variant) -> void:
		if section == "audio":
			apply_volumes())


func _exit_tree() -> void:
	# Al cerrar el juego se detiene todo para no dejar reproducciones vivas.
	for p in find_children("*", "AudioStreamPlayer", false, false):
		(p as AudioStreamPlayer).stop()
		(p as AudioStreamPlayer).stream = null
	_streams.clear()


func _player(bus_key: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = BUSES[bus_key]
	add_child(p)
	return p


func apply_volumes() -> void:
	var muted := bool(Settings.get_value("audio", "muted"))
	_set_bus("Master", float(Settings.get_value("audio", "master")), muted)
	_set_bus(BUSES["music"], float(Settings.get_value("audio", "music")), false)
	_set_bus(BUSES["ambient"], float(Settings.get_value("audio", "ambient")), false)
	_set_bus(BUSES["sfx"], float(Settings.get_value("audio", "sfx")), false)


func _set_bus(bus_name: String, linear: float, mute: bool) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, mute or linear <= 0.001)


func toggle_mute() -> void:
	Settings.set_value("audio", "muted", not bool(Settings.get_value("audio", "muted")))


func is_muted() -> bool:
	return bool(Settings.get_value("audio", "muted"))


func stream(path: String, loop: bool) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	if not ResourceLoader.exists(path):
		push_warning("Falta el audio %s" % path)
		return null
	var s := load(path) as AudioStream
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = loop
	_streams[path] = s
	return s


## Cambia la música con un fundido cruzado. "" la apaga.
func play_music(track: String) -> void:
	if track == current_music:
		return
	current_music = track
	var old := _music[_active]
	_active = 1 - _active
	var new := _music[_active]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", SILENT_DB, FADE)
	tw.chain().tween_callback(old.stop)
	if track == "":
		set_chase(0)
		return
	new.stream = stream(TRACKS[track], true)
	new.volume_db = SILENT_DB
	new.play()
	create_tween().tween_property(new, "volume_db", 0.0, FADE)
	if track == "explore":
		_chase.stream = stream(TRACKS["chase"], true)
		_chase.volume_db = SILENT_DB
		_chase.play()
	else:
		_chase.stop()


## Capa de persecución: 0 nada, 1 sospecha (un poco), 2 persecución (completa).
func set_chase(level: int) -> void:
	_chase_target = [0.0, 0.35, 1.0][clampi(level, 0, 2)]


func play_ambient(on: bool) -> void:
	if on and not _ambient.playing:
		_ambient.stream = stream(TRACKS["ambient"], true)
		_ambient.volume_db = SILENT_DB
		_ambient.play()
		create_tween().tween_property(_ambient, "volume_db", -4.0, FADE)
	elif not on and _ambient.playing:
		var tw := create_tween()
		tw.tween_property(_ambient, "volume_db", SILENT_DB, FADE * 0.5)
		tw.tween_callback(_ambient.stop)


func sfx(sound: String, pitch: float = 1.0) -> void:
	if not sound in SFX:
		push_warning("Efecto desconocido: %s" % sound)
		return
	if sound == "hover":
		# El paso del ratón por varios botones seguidos no debe sonar como una ráfaga.
		var now := Time.get_ticks_msec()
		if now - _last_hover < 70:
			return
		_last_hover = now
	var s := stream("res://assets/audio/sfx_%s.ogg" % sound, false)
	if s == null:
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = -10.0 if sound == "hover" else 0.0
	p.play()


func _process(delta: float) -> void:
	if not _chase.playing:
		return
	_chase_level = move_toward(_chase_level, _chase_target, delta * 0.6)
	_chase.volume_db = linear_to_db(maxf(_chase_level, 0.001)) - 2.0
