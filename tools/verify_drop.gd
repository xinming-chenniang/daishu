# 功能验证：模拟拖拽落词，确认样式改动没有破坏交互
# 用法：godot --path <项目> --script res://tools/verify_drop.gd
extends SceneTree

func _initialize() -> void:
	get_root().size = Vector2i(1152, 648)
	var packed: PackedScene = load("res://scenes/letter.tscn")
	var letter: Node = packed.instantiate()
	get_root().add_child(letter)
	await process_frame
	await process_frame

	var npc_manager: Node = get_root().get_node_or_null("NPCManager")
	if npc_manager == null:
		push_error("找不到 NPCManager")
		quit(1)
		return
	var npcs: Array = npc_manager.get_today_npcs(1)
	if npcs.is_empty():
		push_error("没有生成 NPC")
		quit(1)
		return
	var npc: Dictionary = npcs[0]
	letter.init_with_npc(int(npc.get("npc_id", 0)))
	for i in range(4):
		await process_frame

	var word_panel: Node = letter.get_node("HSplit/WordPanel/WordScroll/WordVBox")
	var correct: Dictionary = npc.get("correct", {})
	var correct_body: Dictionary = correct.get("body_slots", {})
	print("--- NPC: ", npc.get("name", "?"), "  信型: ", npc.get("letter_type", "?"), " ---")
	print("正确答案: ", correct)

	# 从词库容器里找出与正确答案一致的按钮，模拟拖拽数据并投放到对应槽位
	var cases := [
		{"container": "SalutationContainer", "slot": "SalutationSlot", "cat": "salutation", "bs": "",      "expect": str(correct.get("salutation", ""))},
		{"container": "BodyContainer",       "slot": "BodySlot1",      "cat": "body",       "bs": "slot1", "expect": str(correct_body.get("slot1", ""))},
		{"container": "BodyContainer",       "slot": "BodySlot2",      "cat": "body",       "bs": "slot2", "expect": str(correct_body.get("slot2", ""))},
		{"container": "BodyContainer",       "slot": "BodySlot3",      "cat": "body",       "bs": "slot3", "expect": str(correct_body.get("slot3", ""))},
		{"container": "SignatureContainer",  "slot": "SignatureSlot",  "cat": "signature",  "bs": "",      "expect": str(correct.get("signature", ""))},
	]

	var all_ok := true
	for c in cases:
		var container: Node = word_panel.get_node(str(c["container"]))
		var slot: Node = letter.get_node("PaperArea/" + str(c["slot"]))
		var want: String = str(c["expect"])
		# 找到文本匹配的按钮（body 的按钮在 HBoxContainer 里）
		var btn := _find_button(container, want)
		if btn == null:
			print("  [FAIL] 词库里找不到按钮: ", want, "  (", c["container"], ")")
			all_ok = false
			continue

		var data := {
			"type": "word",
			"word": btn.text,
			"category": c["cat"],
			"body_slot": c["bs"],
		}
		var can: bool = slot._can_drop_data(Vector2.ZERO, data)
		if not can:
			print("  [FAIL] 槽位拒绝该词: ", want, " -> ", c["slot"])
			all_ok = false
			continue
		# 拖拽悬停高亮：合法词悬停时该亮，非法词不该亮
		if not slot.is_drag_hover():
			print("  [FAIL] 合法词悬停未高亮: ", want, " -> ", c["slot"])
			all_ok = false
		var wrong := {
			"type": "word",
			"word": "错类词",
			"category": "signature" if str(c["cat"]) != "signature" else "salutation",
			"body_slot": c["bs"],
		}
		if slot._can_drop_data(Vector2.ZERO, wrong) or slot.is_drag_hover():
			print("  [FAIL] 非法词也亮了/被接受: ", c["slot"], " <- ", wrong["category"])
			all_ok = false
		# 重新置为合法悬停，再真正投放
		slot._can_drop_data(Vector2.ZERO, data)
		slot._drop_data(Vector2.ZERO, data)
		await process_frame
		if slot.is_drag_hover():
			print("  [FAIL] 投放后悬停高亮未复位: ", c["slot"])
			all_ok = false

		var label: Label = slot.get_node("TextLabel")
		var shown: String = label.text.replace("\n", "")
		var col: Color = label.get_theme_color("font_color")
		var ok := shown == want
		print("  [%s] %s <- '%s'  显示='%s'  字色=(%.2f, %.2f, %.2f, %.2f)" % [
			"OK" if ok else "FAIL", c["slot"], want, shown, col.r, col.g, col.b, col.a
		])
		if ok and not _check_drag_preview(btn):
			all_ok = false
		if not ok:
			all_ok = false

	# 拖拽预览结构校验（毛笔图 + 词文本）
	print("--- 拖拽预览校验 ---")
	var probe_container: Node = word_panel.get_node("SalutationContainer")
	for child in probe_container.get_children():
		if child is Button:
			_check_drag_preview(child, true)
			break

	# 验证 player_answers 是否同步
	print("--- player_answers ---")
	var pa: Dictionary = letter.player_answers
	for k in pa.keys():
		print("  ", k, " = '", pa[k], "'")

	# 注意：--script 模式下 autoload 不注册，不能用 JudgeSystem 标识符，必须动态取节点
	var judge: Node = get_root().get_node_or_null("JudgeSystem")
	if judge == null:
		print("  [SKIP] 找不到 /root/JudgeSystem，跳过 judge() 验证")
	else:
		var result: Dictionary = judge.call("judge", npc, pa)
		print("--- judge() 结果 ---")
		print("  result_code = ", result.get("result_code", "?"))
		print("  fee         = ", result.get("fee", "?"))

	print("=== 总体: ", "PASS" if all_ok else "FAIL", " ===")

	# 可选：截一张"已填好词"的图（传 --shot <路径> 时）
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--shot" and i + 1 < args.size():
			for j in range(3):
				await process_frame
			var img: Image = get_root().get_texture().get_image()
			if img != null:
				img.save_png(args[i + 1])
				print("[shot] 已保存 ", args[i + 1])

	quit(0 if all_ok else 1)

func _find_button(container: Node, want: String) -> Button:
	for child in container.get_children():
		if child is Button and child.text == want:
			return child
		if child is Node:
			var found := _find_button(child, want)
			if found != null:
				return found
	return null

# 校验拖拽数据 + 预览结构
# 注意：不要直接调 _get_drag_data() —— 没有真实拖拽在进行时 set_drag_preview() 会触发引擎断言。
#       预览构造已抽成 build_drag_preview()，可单独调用。
func _check_drag_preview(btn: Button, verbose: bool = false) -> bool:
	if not btn.has_method("build_drag_preview"):
		print("  [FAIL] 按钮没有 build_drag_preview: ", btn.text)
		return false
	var preview: Control = btn.build_drag_preview()
	if preview == null:
		print("  [FAIL] 预览节点为空: ", btn.text)
		return false
	var tex_count := _count_texture_rects(preview)
	var text_found := _find_label_text(preview)
	var ok := tex_count > 0 and text_found == btn.text
	if verbose or not ok:
		print("  [%s] 拖拽预览 '%s'  毛笔贴图=%d 个  文本='%s'" % [
			"OK" if ok else "FAIL", btn.text, tex_count, text_found
		])
	preview.queue_free()
	return ok

func _count_texture_rects(n: Node) -> int:
	var c := 1 if n is TextureRect else 0
	for child in n.get_children():
		c += _count_texture_rects(child)
	return c

func _find_label_text(n: Node) -> String:
	if n is Label:
		return (n as Label).text
	for child in n.get_children():
		var t := _find_label_text(child)
		if not t.is_empty():
			return t
	return ""
