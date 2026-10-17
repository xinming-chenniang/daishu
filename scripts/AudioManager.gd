extends Node
## 全局音频：UI 音效 + BGM + 静音开关（单例，见 project.godot 的 [autoload]）。
##
## 为什么是"单例 + 播放器池"而不是每个场景各挂一个 AudioStreamPlayer：
## 场景切换（title → prologue → main → letter …）会连带销毁场景节点，声音会被截断；
## 挂在 /root 下则音频生命周期与场景解耦。BGM 也因此能**跨场景延续**（主界面→代写→主界面
## 不会每次都从头播）。
##
## 为什么调用方写 `get_node_or_null("/root/AudioManager")` 而不是直接用全局名 `AudioManager`：
## `--script` 模式**不注册 autoload**（AI_PLAYBOOK 第 1 条）。用裸全局名时，
## tools\verify_drop.gd 这类探针一走到播放代码就报 `Identifier not found` —— 假阳性。
## 用路径查找则 null 时静默跳过，探针照常跑。
##
## 素材全部是**程序化合成**的（无第三方来源、可重跑、参数即文档）：
##   tools\gen_sfx.py  → assets/audio/sfx/*.wav   （短音效）
##   tools\gen_bgm.py  → assets/audio/bgm/*.wav   （23 s 循环，首尾交叉淡化）

const SFX_DIR := "res://assets/audio/sfx/"
const BGM_DIR := "res://assets/audio/bgm/"
const SFX_NAMES := ["ui_click", "paper_drop", "submit", "day_end"]
const BGM_NAMES := ["bgm_title", "bgm_letter"]
const POOL_SIZE := 4

## 底噪以下：UI 音效不应盖过读信。需要更响时调用方传 volume_offset_db。
const BASE_DB := -8.0
## BGM 压得更低：它是背景，不能抢读字的注意力。
const MUSIC_DB := -20.0
const MUSIC_FADE_SEC := 1.2
const SILENT_DB := -60.0

## 静音状态落在这个文件里（与存档分开：读档失败不该影响音频设置）
const SETTINGS_PATH := "user://settings.cfg"

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _missing: Array[String] = []

var _music_streams: Dictionary = {}
var _missing_music: Array[String] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: int = 0     # 0 = a 是当前轨，1 = b
var _current_music: String = ""
var _muted: bool = false


func _ready() -> void:
	# 暂停/切场景时仍要能播 UI 音
	process_mode = Node.PROCESS_MODE_ALWAYS

	for sfx_name in SFX_NAMES:
		var path := "%s%s.wav" % [SFX_DIR, sfx_name]
		var stream: AudioStream = null
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
		if stream == null:
			_missing.append(sfx_name)
		else:
			_streams[sfx_name] = stream

	if _missing.size() > 0:
		# 缺素材不该让游戏起不来：只警告，播放时静默跳过
		push_warning("[AudioManager] 音效缺失（已跳过）：%s —— 先跑 `godot --headless --path . --import`" % ", ".join(_missing))

	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % (i + 1)
		player.bus = "Master"
		player.volume_db = BASE_DB
		add_child(player)
		_players.append(player)

	for bgm_name in BGM_NAMES:
		var path := "%s%s.wav" % [BGM_DIR, bgm_name]
		var stream: AudioStream = null
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
		if stream == null:
			_missing_music.append(bgm_name)
		else:
			_music_streams[bgm_name] = stream

	if _missing_music.size() > 0:
		push_warning("[AudioManager] BGM 缺失（已跳过）：%s —— 先跑 `godot --headless --path . --import`" % ", ".join(_missing_music))

	# 两条 BGM 播放器用于交叉淡化
	_music_a = _make_music_player("Music A")
	_music_b = _make_music_player("Music B")

	_load_settings()


func _make_music_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = "Master"
	player.volume_db = SILENT_DB
	player.finished.connect(_on_music_finished.bind(player))
	add_child(player)
	return player


## BGM 循环：WAV 导入默认不循环，这里在"自然播完"后手动重开。
## 只对**当前轨**生效 —— 交叉淡化过程中被换下的那条不要再续。
func _on_music_finished(player: AudioStreamPlayer) -> void:
	if player == _active_music_player() and player.stream != null and not _muted:
		player.play()


# ---------------- 音效 ----------------

## 播放一个音效。名字不存在时静默返回（缺素材不报错、不打断流程）。
func play_sfx(sfx_name: String, volume_offset_db: float = 0.0) -> void:
	if not _streams.has(sfx_name) or _players.is_empty():
		return
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[sfx_name]
	player.volume_db = BASE_DB + volume_offset_db
	player.play()


## 供探针断言：这个音效是否真的加载到了
func has_sfx(sfx_name: String) -> bool:
	return _streams.has(sfx_name)


func loaded_sfx() -> Array:
	return _streams.keys()


func missing_sfx() -> Array:
	return _missing.duplicate()


# ---------------- BGM ----------------

## 播放某条 BGM。**同一条重复调用是 no-op**（跨场景延续，不会从头重播）。
func play_music(track: String, fade_sec: float = MUSIC_FADE_SEC) -> void:
	if track == _current_music:
		return
	if not _music_streams.has(track):
		push_warning("[AudioManager] 没有这条 BGM：%s" % track)
		return

	var from := _active_music_player()
	_music_active = 1 - _music_active
	var to := _active_music_player()

	_current_music = track
	to.stream = _music_streams[track]
	to.volume_db = SILENT_DB
	to.play()

	var tween := create_tween()
	tween.tween_property(to, "volume_db", MUSIC_DB, maxf(fade_sec, 0.01))
	if from.playing:
		var fade_out := create_tween()
		fade_out.tween_property(from, "volume_db", SILENT_DB, maxf(fade_sec, 0.01))
		fade_out.tween_callback(from.stop)


func stop_music(fade_sec: float = MUSIC_FADE_SEC) -> void:
	_current_music = ""
	var player := _active_music_player()
	if player.playing:
		var tween := create_tween()
		tween.tween_property(player, "volume_db", SILENT_DB, maxf(fade_sec, 0.01))
		tween.tween_callback(player.stop)


func current_music() -> String:
	return _current_music


func has_bgm(track: String) -> bool:
	return _music_streams.has(track)


func missing_bgm() -> Array:
	return _missing_music.duplicate()


func _active_music_player() -> AudioStreamPlayer:
	return _music_a if _music_active == 0 else _music_b


# ---------------- 静音 ----------------

## 静音（同时作用于音效与 BGM：走 Master 总线），并写入设置文件。
func set_muted(muted: bool) -> void:
	_muted = muted
	AudioServer.set_bus_mute(0, _muted)
	_save_settings()


func is_muted() -> bool:
	return _muted


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_muted = bool(cfg.get_value("audio", "muted", false))
	AudioServer.set_bus_mute(0, _muted)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "muted", _muted)
	cfg.save(SETTINGS_PATH)
