extends Control

@onready var confirm_btn: Button = $TextBacking/VBoxContainer/ConfirmButton
@onready var _audio: Node = get_node_or_null("/root/AudioManager")

func _ready() -> void:
	if _audio != null:
		_audio.play_music("bgm_title")   # 序章沿用标题氛围，不打断
	confirm_btn.pressed.connect(_on_confirm_pressed)

func _on_confirm_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

