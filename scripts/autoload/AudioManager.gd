extends Node
## Audio Manager: music crossfading, ambient loops, pooled SFX, volume & mute, and browser unlock safety.

var music_volume: float = 0.7
var sfx_volume: float = 0.8
var ambient_volume: float = 0.5
var muted: bool = false

var _music_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
var _current_music: String = ""
var _current_ambient: String = ""
var _audio_unlocked: bool = false
var _stream_cache: Dictionary = {}


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.finished.connect(_on_ambient_finished)
	add_child(_ambient_player)

	for _i in range(4):
		var sp := AudioStreamPlayer.new()
		add_child(sp)
		_sfx_players.append(sp)

	if OS.get_name() != "Web":
		_audio_unlocked = true
	_apply_volumes()


func _input(event: InputEvent) -> void:
	if not _audio_unlocked and (event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch):
		_audio_unlocked = true
		if _current_music != "" and not _music_player.playing:
			play_music(_current_music)
		if _current_ambient != "" and not _ambient_player.playing:
			play_ambient(_current_ambient)


func set_volumes(music: float, sfx: float, ambient: float, is_muted: bool) -> void:
	music_volume = clampf(music, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	ambient_volume = clampf(ambient, 0.0, 1.0)
	muted = is_muted
	_apply_volumes()


func _apply_volumes() -> void:
	var m_db := -80.0 if (muted or music_volume <= 0.01) else linear_to_db(music_volume)
	var a_db := -80.0 if (muted or ambient_volume <= 0.01) else linear_to_db(ambient_volume)
	var s_db := -80.0 if (muted or sfx_volume <= 0.01) else linear_to_db(sfx_volume)
	_music_player.volume_db = m_db
	_ambient_player.volume_db = a_db
	for sp in _sfx_players:
		sp.volume_db = s_db


func _load_wav(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	if ResourceLoader.exists(path):
		var st := load(path) as AudioStream
		if st != null:
			_stream_cache[path] = st
			return st
	return null


func play_music(track_name: String) -> void:
	if track_name == _current_music and _music_player.playing:
		return
	_current_music = track_name
	if not _audio_unlocked or DisplayServer.get_name() == "headless":
		return
	var st := _load_wav("res://assets/audio/music/%s.wav" % track_name)
	if st == null:
		return
	_music_player.stream = st
	_apply_volumes()
	_music_player.play()


func play_ambient(amb_name: String) -> void:
	if amb_name == _current_ambient and _ambient_player.playing:
		return
	_current_ambient = amb_name
	if not _audio_unlocked or DisplayServer.get_name() == "headless":
		return
	var st := _load_wav("res://assets/audio/ambient/%s.wav" % amb_name)
	if st == null:
		return
	_ambient_player.stream = st
	_apply_volumes()
	_ambient_player.play()


func play_sfx(sfx_name: String) -> void:
	if not _audio_unlocked or muted or DisplayServer.get_name() == "headless":
		return
	var st := _load_wav("res://assets/audio/sfx/%s.wav" % sfx_name)
	if st == null:
		return
	var sp := _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	sp.stream = st
	sp.volume_db = linear_to_db(sfx_volume) if sfx_volume > 0.01 else -80.0
	sp.play()


func _on_music_finished() -> void:
	if _audio_unlocked and _current_music != "":
		_music_player.play()


func _on_ambient_finished() -> void:
	if _audio_unlocked and _current_ambient != "":
		_ambient_player.play()
