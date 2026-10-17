extends Node
## 全局音效播放器（单例，见 project.godot 的 [autoload]）。
##
## 为什么是"单例 + 播放器池"而不是每个场景各挂一个 AudioStreamPlayer：
## 场景切换（title → prologue → main → letter …）会连带销毁场景节点，声音会被截断；
## 挂在 /root 下则音频生命周期与场景解耦。
##
## 为什么调用方写 `get_node_or_null("/root/AudioManager")` 而不是直接用全局名 `AudioManager`：
## `--script` 模式**不注册 autoload**（AI_PLAYBOOK 第 1 条）。用裸全局名时，
## tools\verify_drop.gd 这类探针一走到播放代码就报 `Identifier not found` —— 假阳性。
## 用路径查找则 null 时静默跳过，探针照常跑。
##
## 素材是 `tools\gen_sfx.py` 程序化合成的（无第三方来源，可重跑、参数即文档）。

const SFX_DIR := "res://assets/audio/sfx/"
const SFX_NAMES := ["ui_click", "paper_drop", "submit", "day_end"]
const POOL_SIZE := 4
## 底噪以下：UI 音效不应盖过读信。需要更响时调用方传 volume_offset_db。
const BASE_DB := -8.0

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _missing: Array[String] = []


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
