extends Control

@onready var start_btn: Button = $VBoxContainer/StartButton
@onready var continue_btn: Button = $VBoxContainer/ContinueButton
@onready var quit_btn: Button = $VBoxContainer/QuitButton
@onready var mute_check: CheckButton = $MuteCheck
# 用路径查找而不是裸全局名：--script 模式不注册 autoload（AI_PLAYBOOK 第 1 条）
@onready var _audio: Node = get_node_or_null("/root/AudioManager")

func _ready() -> void:
	start_btn.pressed.connect(_on_start_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	
	# 没有存档时可以考虑禁用“继续游戏”按钮
	continue_btn.disabled = not PlayerManager.has_save()

	if _audio != null:
		# 静音开关：摆在标题页右下角，状态写进 user://settings.cfg
		mute_check.button_pressed = _audio.is_muted()
		mute_check.toggled.connect(_on_mute_toggled)
		_audio.play_music("bgm_title")
	else:
		mute_check.hide()

func _on_mute_toggled(pressed: bool) -> void:
	if _audio != null:
		_audio.set_muted(pressed)

func _on_start_pressed() -> void:
	if _audio != null:
		_audio.play_sfx("ui_click")
	PlayerManager.reset()
	PlayerManager.save()
	get_tree().change_scene_to_file("res://scenes/prologue.tscn")

func _on_continue_pressed() -> void:
	if _audio != null:
		_audio.play_sfx("ui_click")
	if PlayerManager.has_save() and PlayerManager.load():
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		# 读不出（损坏 / 版本比程序新）时**不要**带着半套状态进主界面：
		# 明确回落到新游戏，并保留原存档文件（不删，留给人工排查）。
		print("无有效存档，开始新游戏")
		_on_start_pressed()

func _on_quit_pressed() -> void:
	get_tree().quit()

