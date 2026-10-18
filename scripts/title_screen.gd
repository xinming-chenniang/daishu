extends Control

@onready var start_btn: Button = $VBoxContainer/StartButton
@onready var continue_btn: Button = $VBoxContainer/ContinueButton
@onready var help_btn: Button = $VBoxContainer/HelpButton
@onready var quit_btn: Button = $VBoxContainer/QuitButton
@onready var mute_check: CheckButton = $MuteCheck
@onready var help_popup: AcceptDialog = $HelpPopup
# 用路径查找而不是裸全局名：--script 模式不注册 autoload（AI_PLAYBOOK 第 1 条）
@onready var _audio: Node = get_node_or_null("/root/AudioManager")

## 玩法说明。
## 写在这里而不是 .tscn：多行中文塞进场景文件要转义，改文案也更容易。
## 注意别写成游戏没实现的东西（例如"点词再点槽位"目前不存在，只有拖拽）。
const HELP_TEXT := """【怎么玩】
1. 点「开始今日」，主界面会列出今天的 3 位委托人，选一位。
2. 读他/她的口述：三个正文正解都念在话里了，只是混在诱饵词中间。
3. 左侧词库分四组：称谓、正文三槽（按信型给出提示词）、落款。
   把词语拖到信纸右侧对应的虚线槽位上。
4. 五个槽位填满后点「提交」，等对方评理。

【判定】
· 五项全对：完美，得「基础报酬 + 完美加成」。
· 五项对四项：良好，加成按七成算。
· 用了词库以外的词，或留空：格式错误。每处扣 2 文，此时不看对了几项。
· 其余（词都在库里但不对）：按基础报酬的六成算。

【目标】
10 天内攒够 500 文。每天收摊扣 10 文摊位费；钱一旦变负，立刻结束。

【提示】
· 中途点「返回主界面」不会消耗这次委托，可以反复对照口述。
· 越到后面报酬越高，但完美加成的绝对值也在涨 —— 前期多攒一点更稳。
· 没把握时，至少把五个槽位填满：留空是格式错误，扣得比随便填更狠。"""


func _ready() -> void:
	start_btn.pressed.connect(_on_start_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	help_btn.pressed.connect(_on_help_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

	# 没有存档时可以考虑禁用“继续游戏”按钮
	continue_btn.disabled = not PlayerManager.has_save()

	# 玩法说明弹窗：内容来自 HELP_TEXT，按钮文案改成"知道了"
	help_popup.dialog_text = HELP_TEXT
	help_popup.get_ok_button().text = "知道了"

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

func _on_help_pressed() -> void:
	if _audio != null:
		_audio.play_sfx("ui_click")
	help_popup.popup_centered()

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

