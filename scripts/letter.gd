extends Control

# 左侧词库
@onready var request_label: Label = $HSplit/LetterPanel/LetterVBox/RequestLabel
@onready var salutation_container: VBoxContainer = $HSplit/WordPanel/WordVBox/SalutationContainer
@onready var body_container: VBoxContainer = $HSplit/WordPanel/WordVBox/BodyContainer
@onready var signature_container: VBoxContainer = $HSplit/WordPanel/WordVBox/SignatureContainer

# 右侧信纸槽位（锚定在底纸栏位上）
@onready var salutation_slot = $PaperArea/SalutationSlot
@onready var body_slot1 = $PaperArea/BodySlot1
@onready var body_slot2 = $PaperArea/BodySlot2
@onready var body_slot3 = $PaperArea/BodySlot3
@onready var signature_slot = $PaperArea/SignatureSlot

# 底部按钮与结算弹窗
@onready var submit_btn: Button = $ButtonBar/SubmitBtn
@onready var reset_btn: Button = $ButtonBar/ResetBtn
@onready var back_btn: Button = $ButtonBar/BackBtn
@onready var result_popup: AcceptDialog = $ResultPopup
@onready var result_label: RichTextLabel = $ResultPopup/ResultLabel
# 用路径查找而不是裸全局名：--script 模式不注册 autoload（AI_PLAYBOOK 第 1 条）
@onready var _audio: Node = get_node_or_null("/root/AudioManager")

const WORD_BUTTON_SCRIPT := preload("res://scripts/word_button.gd")
# 信纸毛笔字体：与全局 Theme 同一个字体，但信纸用更大的字号与纯墨色
# （全局 Theme 的字号/字色偏 UI，信纸要更像"写在纸上的字"）
const LETTER_FONT_PATH := "res://assets/fonts/hanchanlongcang.otf"
const LETTER_FONT_SIZE := 22
const LETTER_FONT_COLOR := Color.BLACK

# 当前NPC数据
var current_npc: Dictionary = {}
var current_npc_id: int = 0
var _npc_initialized := false
var _pending_result: Dictionary = {}
# 是否已完成结算（钱已记账、委托已计入完成）。
# 之前 return_to_main() 无条件把委托标记完成，导致"点返回主界面、没提交"也会把这单算掉 ——
# 玩家白跑一趟且拿不到钱。现在只有确认过结算弹窗才置 true（见 tools/verify_flow.gd）。
var _settled := false
# 正文三槽界面提示词，随信型变化（由 NPCManager.get_slot_hints 提供）
var _slot_hints: Dictionary = {"slot1": "其一", "slot2": "其二", "slot3": "其三"}

# 当前填写的答案（与判定系统兼容）
var player_answers := {
	"salutation": "",
	"body_slot1": "",
	"body_slot2": "",
	"body_slot3": "",
	"signature": ""
}

func _ready() -> void:
	if _audio != null:
		_audio.play_music("bgm_letter")   # 代写界面换一条更安静的氛围
	submit_btn.pressed.connect(_on_submit_pressed)
	reset_btn.pressed.connect(_on_reset_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	result_popup.confirmed.connect(_on_result_popup_confirmed)
	result_popup.get_ok_button().text = "确认"

	# 槽位接收拖拽后，更新 player_answers
	for slot in [salutation_slot, body_slot1, body_slot2, body_slot3, signature_slot]:
		slot.word_dropped.connect(_on_slot_word_dropped)

	# 信纸区域使用毛笔字体（assets/fonts/hanchanlongcang.otf，见 LETTER_FONT_PATH）
	_apply_letter_font()
	# 口述文本用系统小字，便于横向阅读
	request_label.remove_theme_font_override("font")
	request_label.remove_theme_font_size_override("font_size")
	request_label.remove_theme_color_override("font_color")
	request_label.remove_theme_constant_override("outline_size")
	request_label.remove_theme_color_override("font_outline_color")
	request_label.add_theme_font_size_override("font_size", 14)

# 为右侧信纸区域所有 Label 应用毛笔字体与墨色
func _apply_letter_font() -> void:
	if not ResourceLoader.exists(LETTER_FONT_PATH):
		return
	var font: Font = load(LETTER_FONT_PATH) as Font
	if font == null:
		return
	_apply_font_to_labels($PaperArea, font)

func _apply_font_to_labels(control: Control, font: Font) -> void:
	if control is Label:
		control.add_theme_font_override("font", font)
		control.add_theme_font_size_override("font_size", LETTER_FONT_SIZE)
		control.add_theme_color_override("font_color", LETTER_FONT_COLOR)
		# 轻微描边模拟墨迹
		control.add_theme_constant_override("outline_size", 1)
		control.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	for child in control.get_children():
		if child is Control:
			_apply_font_to_labels(child, font)

# 竖排：每字一行，自上而下（中国古代书写习惯）
func _to_vertical(s: String) -> String:
	if s.is_empty():
		return ""
	var lines: PackedStringArray = []
	for i in range(s.length()):
		lines.append(s[i])
	return "\n".join(lines)

# 初始化界面，由主界面调用
func init_with_npc(npc_id: int) -> void:
	_npc_initialized = false
	_settled = false
	_pending_result = {}
	current_npc_id = int(npc_id)
	var npc_manager = get_node("/root/NPCManager")
	current_npc = npc_manager.get_npc_by_id(current_npc_id)

	if current_npc.is_empty():
		print("错误：找不到NPC ID ", npc_id, "，current_day_npcs 数量: ", npc_manager.current_day_npcs.size())
		return

	request_label.text = str(current_npc.get("request_text", ""))

	_slot_hints = npc_manager.get_slot_hints(str(current_npc.get("letter_type", "")))
	_apply_slot_placeholders()
	_build_word_pools()
	reset_answers()
	_npc_initialized = true

# 信纸槽位占位符随信型变化：避免 5 种信型共用家书语义（家中/在外/盼）造成误导
func _apply_slot_placeholders() -> void:
	var slots := {"slot1": body_slot1, "slot2": body_slot2, "slot3": body_slot3}
	for slot_name in slots.keys():
		var slot = slots[slot_name]
		if slot == null:
			continue
		slot.placeholder = "%s ______" % str(_slot_hints.get(slot_name, slot_name))
		slot.clear_slot()

func _build_word_pools() -> void:
	# 清空旧的词库按钮
	for c in [salutation_container, body_container, signature_container]:
		for child in c.get_children():
			child.queue_free()

	var word_pool: Dictionary = current_npc.get("word_pool", {})

	# 称谓词库
	for text in word_pool.get("salutation", []):
		_add_word_button(salutation_container, str(text), "salutation", "")

	# 正文词库（body_slots.slot1/2/3），每行加标签对应右侧槽位
	var body_slots: Dictionary = word_pool.get("body_slots", {})
	var slot_labels: Dictionary = _slot_hints
	for slot_name in ["slot1", "slot2", "slot3"]:
		var label := Label.new()
		label.text = "· " + slot_labels.get(slot_name, slot_name)
		label.add_theme_font_size_override("font_size", 12)
		# 深灰在暖褐面板上几乎读不出来，改用与底板同族的暖褐（比 Labels 略浅一点做层级区分）
		label.add_theme_color_override("font_color", Color(0.42, 0.31, 0.18, 1.0))
		body_container.add_child(label)
		var row := HBoxContainer.new()
		body_container.add_child(row)
		for text in body_slots.get(slot_name, []):
			_add_word_button(row, str(text), "body", slot_name)

	# 落款词库
	for text in word_pool.get("signature", []):
		_add_word_button(signature_container, str(text), "signature", "")

func _add_word_button(parent: Node, text: String, category: String, body_slot: String) -> void:
	var btn := Button.new()
	btn.set_script(WORD_BUTTON_SCRIPT)
	btn.text = text
	btn.category = category
	btn.body_slot = body_slot
	# 外观不再在此处硬编码：全局 Theme（theme/daishu_theme.tres）提供
	# 九宫格按钮样式与墨色字，词库按钮与其他场景按钮保持同一套观感。
	parent.add_child(btn)

func _on_slot_word_dropped(slot_key: String, word: String) -> void:
	match slot_key:
		"salutation":
			player_answers["salutation"] = word
		"body_slot1":
			player_answers["body_slot1"] = word
		"body_slot2":
			player_answers["body_slot2"] = word
		"body_slot3":
			player_answers["body_slot3"] = word
		"signature":
			player_answers["signature"] = word

# 提交按钮：弹出结算结果，确认后再结算并返回
func _on_submit_pressed() -> void:
	if not _npc_initialized or current_npc.is_empty():
		return
	if _audio != null:
		_audio.play_sfx("submit")
	var result: Dictionary = JudgeSystem.judge(current_npc, player_answers)
	_pending_result = result
	var fee := int(result.get("fee", 0))
	var feedback_text := str(result.get("feedback_text", ""))
	var line1 := ""
	if fee < 0:
		line1 = "扣钱：%d 文" % abs(fee)
	else:
		line1 = "获得：%d 文" % fee
	var correct_answers: Dictionary = result.get("correct_answers", {})
	var item_correct: Dictionary = result.get("item_correct", {})
	var answer_block := _build_answer_highlight(correct_answers, item_correct)
	result_label.text = line1 + "\n\n" + feedback_text + answer_block
	result_popup.popup_centered()

# 生成带高亮的“正确答案”区块（BBCode：绿色=正确，错项旁显示玩家所填）
func _build_answer_highlight(correct_answers: Dictionary, item_correct: Dictionary) -> String:
	if correct_answers.is_empty():
		return ""
	var c := correct_answers
	var ok := item_correct
	var slot1 := str(c.get("body_slot1", ""))
	var slot2 := str(c.get("body_slot2", ""))
	var slot3 := str(c.get("body_slot3", ""))
	var sal := str(c.get("salutation", ""))
	var sig := str(c.get("signature", ""))
	var lines: Array[String] = []
	lines.append("\n\n——— [color=#27ae60]正确答案[/color] ———")
	var sal_extra := " （你填：%s）" % player_answers.get("salutation", "") if not ok.get("salutation", true) else ""
	lines.append("称谓：[color=#27ae60]%s[/color]%s" % [sal, sal_extra])
	# 正文提示词必须跟信型走（家书=家中/在外/盼，贺寿=福寿/纳福/欢聚……）。
	# 之前这里硬编码"家中/在外/盼"，贺寿/诉苦/求荐的结算面板会给出语义错误的答案块。
	var hint1 := str(_slot_hints.get("slot1", "其一"))
	var hint2 := str(_slot_hints.get("slot2", "其二"))
	var hint3 := str(_slot_hints.get("slot3", "其三"))
	lines.append("正文：%s[color=#27ae60]%s[/color]%s，%s[color=#27ae60]%s[/color]%s，%s[color=#27ae60]%s[/color]%s。" % [
		hint1, slot1, " （你填：%s）" % player_answers.get("body_slot1", "") if not ok.get("body_slot1", true) else "",
		hint2, slot2, " （你填：%s）" % player_answers.get("body_slot2", "") if not ok.get("body_slot2", true) else "",
		hint3, slot3, " （你填：%s）" % player_answers.get("body_slot3", "") if not ok.get("body_slot3", true) else ""
	])
	var sig_extra := " （你填：%s）" % player_answers.get("signature", "") if not ok.get("signature", true) else ""
	lines.append("落款：[color=#27ae60]%s[/color]%s" % [sig, sig_extra])
	return "\n".join(lines)

func _on_result_popup_confirmed() -> void:
	if _audio != null:
		_audio.play_sfx("ui_click")
	# 防重复结算：连点确认、或弹窗被再次触发时，同一单不能再记一次账
	if _pending_result.is_empty():
		return
	var fee := int(_pending_result.get("fee", 0))
	_pending_result = {}
	var npc_name := str(current_npc.get("name", "未知NPC"))
	PlayerManager.record_entry("commission", fee, "%s 委托结算" % npc_name, {"npc_id": current_npc_id, "npc_name": npc_name})
	if PlayerManager.add_money(fee):
		# 这笔钱把余额扣成负数 → 失败结局已请求切换（帧末生效）。
		# 此时**不能**再回主界面：Main 马上会被释放，继续操作它会踩空。把自己摘掉即可。
		queue_free()
		return
	_settled = true
	return_to_main()

# 重新填写按钮
func _on_reset_pressed() -> void:
	if _audio != null:
		_audio.play_sfx("ui_click")
	reset_answers()

func reset_answers() -> void:
	# 清空槽位显示
	salutation_slot.clear_slot()
	body_slot1.clear_slot()
	body_slot2.clear_slot()
	body_slot3.clear_slot()
	signature_slot.clear_slot()

	# 清空答案记录
	player_answers = {
		"salutation": "",
		"body_slot1": "",
		"body_slot2": "",
		"body_slot3": "",
		"signature": ""
	}

# 返回主界面（显示主界面并移除代写界面，保留主界面状态）
func _on_back_pressed() -> void:
	return_to_main()

func return_to_main() -> void:
	if _audio != null:
		_audio.play_music("bgm_title")   # 回主界面切回标题那条（同一条则 no-op）
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		# ⚠️ 只有**真结算过**才把委托标记完成。
		# 之前这里无条件调用 on_npc_completed()，导致"点返回主界面、没提交"也把这单算掉：
		# 委托从列表消失、玩家一分钱拿不到（等价于白跑一趟）。
		if _settled and main.has_method("on_npc_completed"):
			main.on_npc_completed(current_npc_id)
		main.show()
		if main.has_method("update_ui"):
			main.update_ui()
	queue_free()


## 供回归脚本断言：这一单是否已结算（tools/verify_flow.gd）
func is_settled() -> bool:
	return _settled
