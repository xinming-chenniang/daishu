# 校验"信稿"：把五个词组装成明代书信格式（称谓 → 启事语 → 正文 → 结尾敬语 → 署名 → 日期）
#
# 为什么需要：信的核心交付物是"一封像样的信"，而不是五个词落在纸上。
# 这里同时守住三件事：
#   ① 每种信型都有完整的 letter_form（起首语/正文连缀/结尾敬语，正文含三个占位符）
#   ② 组装出的信包含玩家填的五个词、日期按天数取节气、未填处显示占位
#   ③ 信稿里每个字都在项目字体里（否则竖排会出现系统字体混排）
#
# 用法：
#   pwsh -File tools/run-godot.ps1 --headless --script res://tools/verify_letter_text.gd
extends SceneTree

const LETTER_SCENE := "res://scenes/letter.tscn"
const FONT_PATH := "res://assets/fonts/hanchanlongcang.otf"

var _fails: Array[String] = []


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	get_root().size = Vector2i(1152, 648)
	await process_frame  # --script 的 _initialize 早于 SceneTree 激活（AI_PLAYBOOK 第 21 条）

	var nm = get_root().get_node_or_null("NPCManager")
	if nm == null:
		print("=== 结论: FAIL ===（找不到 NPCManager）")
		quit(1)
		return
	_check(nm.is_content_loaded(), "内容已加载")

	# 可选：截一张"信稿弹窗"图（--shot-draft <path>，需要非 headless）
	var shot_draft := ""
	var user_args := OS.get_cmdline_user_args()
	for i in range(user_args.size()):
		if user_args[i] == "--shot-draft" and i + 1 < user_args.size():
			shot_draft = user_args[i + 1]

	# --- ① 五种信型的信稿结构 ---
	for t in nm.LETTER_TYPES:
		var form: Dictionary = nm.get_letter_form(str(t))
		_check(not form.is_empty(), "%s 有信稿结构" % t)
		for key in ["opening", "body", "closing"]:
			_check(not str(form.get(key, "")).is_empty(), "%s.%s 非空" % [t, key])
		var body := str(form.get("body", ""))
		for slot in ["{slot1}", "{slot2}", "{slot3}"]:
			_check(body.contains(slot), "%s.body 含 %s" % [t, slot])
	print("  日期条数：%d（第 1 日 = %s，第 10 日 = %s）" % [
		nm.LETTER_DATES.size(), nm.get_date_line(1), nm.get_date_line(10)])
	_check(nm.LETTER_DATES.size() >= 10, "日期至少 10 条")

	# --- ② 组装一封信 ---
	seed(20261018)
	var npcs: Array = nm.get_today_npcs(1)
	var letter = load(LETTER_SCENE).instantiate()
	get_root().add_child(letter)
	letter.init_with_npc(int(npcs[0].get("npc_id", 0)))
	for i in range(4):
		await process_frame

	var npc: Dictionary = npcs[0]
	var correct: Dictionary = npc.get("correct", {})
	var body_correct: Dictionary = correct.get("body_slots", {})
	letter.player_answers = {
		"salutation": str(correct.get("salutation", "")),
		"body_slot1": str(body_correct.get("slot1", "")),
		"body_slot2": str(body_correct.get("slot2", "")),
		"body_slot3": str(body_correct.get("slot3", "")),
		"signature": str(correct.get("signature", "")),
	}
	var parts: Array = letter.build_letter_paragraphs()
	var text: String = letter.build_letter_text()
	print("  信型：%s　段落：%d　字数：%d" % [npc.get("letter_type", "?"), parts.size(), text.length()])
	_check(parts.size() == 6, "信稿 6 段（称谓/启事/正文/结尾/署名/日期），实测 %d" % parts.size())
	for key in ["salutation"]:
		_check(text.contains(str(correct.get(key, ""))), "信稿含称谓「%s」" % correct.get(key, ""))
	for slot in ["slot1", "slot2", "slot3"]:
		_check(text.contains(str(body_correct.get(slot, ""))), "信稿含正文词「%s」" % body_correct.get(slot, ""))
	_check(text.contains(str(correct.get("signature", ""))), "信稿含署名「%s」" % correct.get("signature", ""))
	var form0: Dictionary = nm.get_letter_form(str(npc.get("letter_type", "")))
	_check(text.contains(str(form0.get("opening", ""))), "信稿含起首语")
	_check(text.contains(str(form0.get("closing", ""))), "信稿含结尾敬语")
	_check(text.contains(nm.get_date_line(1)), "信稿含第 1 日日期「%s」" % nm.get_date_line(1))
	_check(text.contains("旅次灯下谨书"), "信稿含落款套语")

	# --- 未填槽位的占位 ---
	letter.player_answers = {}
	_check(letter.build_letter_text().contains("＿＿＿"), "未填槽位显示占位符")

	# --- ③ 字体覆盖 ---
	var font = load(FONT_PATH)
	_check(font != null, "字体可加载")
	if font is Font:
		var supported: String = (font as Font).get_supported_chars()
		var missing := {}
		var full: String = str(letter.build_letter_text())
		for i in range(full.length()):
			var ch: String = full[i]
			if ch == "\n":
				continue
			if not supported.contains(ch):
				missing[ch] = true
		if not missing.is_empty():
			print("  缺字：", "".join(missing.keys()))
		_check(missing.is_empty(), "信稿用字都有字形（缺 %d 个）" % missing.size())

	# --- ④ 弹窗能开、列数与段落一致 ---
	letter.player_answers = {
		"salutation": str(correct.get("salutation", "")),
		"body_slot1": str(body_correct.get("slot1", "")),
		"body_slot2": str(body_correct.get("slot2", "")),
		"body_slot3": str(body_correct.get("slot3", "")),
		"signature": str(correct.get("signature", "")),
	}
	letter._on_draft_pressed()
	await process_frame
	var popup: AcceptDialog = letter.get_node("LetterDraftPopup")
	var cols: HBoxContainer = popup.get_node("Scroll/Columns")
	_check(popup.visible, "点「信稿」弹窗打开")
	_check(cols.get_child_count() == 6, "竖排列数 6（实测 %d）" % cols.get_child_count())
	if not shot_draft.is_empty():
		for j in range(3):
			await process_frame
		var img: Image = get_root().get_texture().get_image()
		if img != null:
			img.save_png(shot_draft)
			print("[shot] 已保存 ", shot_draft)
		else:
			print("[shot] 取不到视口图像（headless 下正常）")
	popup.hide()
	await process_frame

	letter.queue_free()
	await process_frame

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
