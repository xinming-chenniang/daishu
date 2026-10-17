# 校验代写界面的词库布局（内容扩充方案 A 的验收：5 称谓 / 每槽 10 词 / 4 落款 + 可滚动）
#
# 为什么要有这个脚本：词库从 6→10 后左栏必然超出一屏，必须靠 ScrollContainer；
# 但"能滚动"和"按钮没溢出"是两回事，都要量。
#
# 用法：
#   pwsh -File tools\run-godot.ps1 --headless --script res://tools/verify_letter_layout.gd
#   pwsh -File tools\run-godot.ps1 -ArgLine "--path . --script res://tools/verify_letter_layout.gd -- --shot out.png --scroll bottom"
#   （--shot 需要非 headless；--scroll bottom 会把词库滚到底再截图）
extends SceneTree

const LETTER_SCENE := "res://scenes/letter.tscn"
const SALUTATION_EXPECT := 5
const BODY_EXPECT := 10
const SIGNATURE_EXPECT := 4

var _fails: Array[String] = []


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	get_root().size = Vector2i(1152, 648)
	await process_frame  # --script 的 _initialize 早于 SceneTree 激活（AI_PLAYBOOK 第 21 条）

	var shot_path := ""
	var scroll_mode := "top"
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		match args[i]:
			"--shot":
				if i + 1 < args.size():
					shot_path = args[i + 1]
			"--scroll":
				if i + 1 < args.size():
					scroll_mode = args[i + 1]

	seed(20261018)
	var nm = get_root().get_node_or_null("NPCManager")
	if nm == null:
		print("=== 结论: FAIL ===（找不到 NPCManager）")
		quit(1)
		return
	var npcs: Array = nm.get_today_npcs(1)
	if npcs.is_empty():
		print("=== 结论: FAIL ===（没有生成 NPC）")
		quit(1)
		return

	var letter = load(LETTER_SCENE).instantiate()
	get_root().add_child(letter)
	letter.init_with_npc(int(npcs[0].get("npc_id", 0)))
	for i in range(6):
		await process_frame

	var scroll: ScrollContainer = letter.get_node_or_null("HSplit/WordPanel/WordScroll")
	var salutation: VBoxContainer = letter.get_node_or_null("HSplit/WordPanel/WordScroll/WordVBox/SalutationContainer")
	var body: VBoxContainer = letter.get_node_or_null("HSplit/WordPanel/WordScroll/WordVBox/BodyContainer")
	var signature: VBoxContainer = letter.get_node_or_null("HSplit/WordPanel/WordScroll/WordVBox/SignatureContainer")
	var panel: Panel = letter.get_node_or_null("HSplit/WordPanel")

	_check(scroll != null, "WordVBox 外有 ScrollContainer")
	_check(salutation != null and body != null and signature != null, "三个词库分组容器都在（新路径）")
	if scroll == null or salutation == null or body == null or signature == null or panel == null:
		_finish()
		return

	# --- 数量 ---
	_check(salutation.get_child_count() == SALUTATION_EXPECT,
		"称谓按钮 %d 个（期望 %d）" % [salutation.get_child_count(), SALUTATION_EXPECT])
	_check(signature.get_child_count() == SIGNATURE_EXPECT,
		"落款按钮 %d 个（期望 %d）" % [signature.get_child_count(), SIGNATURE_EXPECT])

	# BodyContainer 每个槽：1 个 Label + 1 个 HFlowContainer
	var flow_rows: Array = []
	for child in body.get_children():
		if child is HFlowContainer:
			flow_rows.append(child)
	_check(flow_rows.size() == 3, "正文三槽各有 1 个 Flow 行（实测 %d）" % flow_rows.size())
	for i in range(flow_rows.size()):
		var n := (flow_rows[i] as HFlowContainer).get_child_count()
		_check(n == BODY_EXPECT, "正文槽 %d 按钮 %d 个（期望 %d）" % [i + 1, n, BODY_EXPECT])

	# --- 滚动 ---
	var max_scroll: int = int(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)
	print("  词库可视高 %d，内容高 %d，最大滚动 %d" % [int(scroll.size.y), int(scroll.get_v_scroll_bar().max_value), max_scroll])
	_check(max_scroll > 0, "内容超出一屏、可纵向滚动（最大滚动 %d）" % max_scroll)

	# --- 横向不溢出：所有按钮右边缘都在面板内 ---
	var panel_right := panel.get_global_rect().end.x
	var worst := 0.0
	var worst_text := ""
	for container in [salutation, body, signature]:
		for child in container.get_children():
			var nodes: Array = []
			if child is HFlowContainer:
				nodes = (child as HFlowContainer).get_children()
			elif child is Button:
				nodes = [child]
			for b in nodes:
				if b is Button:
					var r: Rect2 = (b as Button).get_global_rect()
					if r.end.x > worst:
						worst = r.end.x
						worst_text = (b as Button).text
	print("  最右按钮「%s」右缘 %.1f，面板右缘 %.1f" % [worst_text, worst, panel_right])
	_check(worst <= panel_right + 0.5, "按钮没有横向溢出面板（最右 %.1f ≤ %.1f）" % [worst, panel_right])

	# --- 滚到底：落款按钮必须真的进入可视区 ---
	scroll.scroll_vertical = max_scroll
	for i in range(4):
		await process_frame
	var view: Rect2 = scroll.get_global_rect()
	var last_btn: Button = signature.get_child(signature.get_child_count() - 1)
	var last_rect: Rect2 = last_btn.get_global_rect()
	print("  滚到底后：落款末按钮 y %.1f..%.1f，可视区 y %.1f..%.1f" % [last_rect.position.y, last_rect.end.y, view.position.y, view.end.y])
	_check(last_rect.position.y >= view.position.y - 1 and last_rect.end.y <= view.end.y + 1,
		"滚到底后最后一个落款按钮完整可见")

	if not shot_path.is_empty():
		if scroll_mode == "top":
			scroll.scroll_vertical = 0
			for i in range(3):
				await process_frame
		var img: Image = get_root().get_texture().get_image()
		if img != null:
			img.save_png(shot_path)
			print("[shot] 已保存 ", shot_path, "  ", img.get_width(), "x", img.get_height())
		else:
			print("[shot] 取不到视口图像（headless 下正常）")

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
