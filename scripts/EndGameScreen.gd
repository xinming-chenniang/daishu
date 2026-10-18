extends Control

@export var is_success: bool = false

@onready var message_label: Label = $TextBacking/VBoxContainer/MessageLabel
@onready var restart_button: Button = $TextBacking/VBoxContainer/Buttons/RestartButton
@onready var quit_button: Button = $TextBacking/VBoxContainer/Buttons/QuitButton
@onready var _audio: Node = get_node_or_null("/root/AudioManager")

func _ready() -> void:
	# 结局段落用静默收束：这里不接第三条 BGM，直接淡出更干净
	if _audio != null:
		_audio.stop_music()
	if is_success:
		message_label.text = "恭喜！你凑齐了进京的路费，得以赶赴科考。金榜题名，从此改变命运……"
	else:
		message_label.text = "路费不足，你错过了今年的科考。壮志难酬，只得回乡另谋生计……"
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	# 结局淡入；截图/验证模式下 SceneFx 会自动跳过（见 scripts/SceneFx.gd）
	var fx := get_node_or_null("/root/SceneFx")
	if fx != null:
		fx.fade_in(self, 0.5)

func _on_restart_pressed() -> void:
	PlayerManager.reset()
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

