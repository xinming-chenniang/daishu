# 发布壳层校验：应用身份（名称/图标/版本）+ 标题页按钮齐全 + 玩法说明可开可关
#
# 为什么需要：这些是"发布前壳层"的一部分，没有它们 exe/taskbar/标题栏全是 `daishu`，
# 而新玩家第一次打开标题页也没有任何规则说明。它们不会被玩法回归脚本覆盖。
#
# 用法：
#   pwsh -File tools\run-godot.ps1 --headless --script res://tools/verify_shell.gd
extends SceneTree

const TITLE_SCENE := "res://scenes/title_screen.tscn"
const EXPECTED_NAME := "代书"
const ICON_PATH := "res://assets/images/ui/icon.png"
const SCENES := [
	"res://scenes/title_screen.tscn",
	"res://scenes/prologue.tscn",
	"res://scenes/main.tscn",
	"res://scenes/letter.tscn",
	"res://scenes/success.tscn",
	"res://scenes/gameover.tscn",
]

var _fails: Array[String] = []


func _initialize() -> void:
	get_root().size = Vector2i(1152, 648)
	await process_frame  # --script 的 _initialize 早于 SceneTree 激活（AI_PLAYBOOK 第 21 条）

	# --- 1. 应用身份 ---
	var app_name := str(ProjectSettings.get_setting("application/config/name", ""))
	_check(app_name == EXPECTED_NAME, "config/name = 「%s」（实测「%s」）" % [EXPECTED_NAME, app_name])

	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	_check(not version.is_empty(), "config/version 已设置（实测「%s」）" % version)

	var icon_setting := str(ProjectSettings.get_setting("application/config/icon", ""))
	_check(icon_setting == ICON_PATH, "config/icon 指向 %s（实测 %s）" % [ICON_PATH, icon_setting])
	var icon: Texture2D = null
	if ResourceLoader.exists(ICON_PATH):
		icon = load(ICON_PATH) as Texture2D
	_check(icon != null, "图标资源可加载")
	if icon != null:
		var isz := icon.get_size()
		_check(isz.x >= 128 and isz.y >= 128 and isz.x == isz.y,
			"图标为正方形且 ≥128（实测 %dx%d）" % [int(isz.x), int(isz.y)])

	# --- 2. 六个场景都能加载 ---
	for path in SCENES:
		var packed := load(path) as PackedScene
		_check(packed != null, "场景可加载：%s" % path)

	# --- 3. 标题页按钮与玩法说明 ---
	var title = load(TITLE_SCENE).instantiate()
	get_root().add_child(title)
	for i in range(4):
		await process_frame

	for btn_name in ["StartButton", "ContinueButton", "HelpButton", "QuitButton"]:
		var b = title.get_node_or_null("VBoxContainer/" + btn_name)
		_check(b != null and b is Button, "标题页有按钮 %s" % btn_name)

	var help_btn: Button = title.get_node_or_null("VBoxContainer/HelpButton")
	var popup: AcceptDialog = title.get_node_or_null("HelpPopup")
	_check(popup != null, "存在 HelpPopup")
	if help_btn == null or popup == null:
		_finish()
		return

	_check(not popup.visible, "弹窗默认关闭")
	help_btn.emit_signal("pressed")
	for i in range(2):
		await process_frame
	_check(popup.visible, "点「玩法说明」后弹窗打开")

	var text := popup.dialog_text
	print("  说明文本 %d 字" % text.length())
	_check(text.length() > 150, "说明文本足够长（实测 %d 字）" % text.length())
	for kw in ["怎么玩", "判定", "目标", "拖"]:
		_check(text.contains(kw), "说明里包含「%s」" % kw)
	_check(popup.get_ok_button().text == "知道了", "确认按钮文案为「知道了」")

	popup.hide()
	await process_frame
	_check(not popup.visible, "弹窗可关闭")

	_finish()


func _finish() -> void:
	if _fails.is_empty():
		print("=== 结论: PASS ===")
		quit(0)
	else:
		print("=== 结论: FAIL（%d 项）===" % _fails.size())
		for f in _fails:
			print("  [!] ", f)
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  [OK] ", msg)
	else:
		print("  [FAIL] ", msg)
		_fails.append(msg)
