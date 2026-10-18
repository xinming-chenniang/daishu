# 回归校验：代写 → 结算 → 回主界面的状态机，以及"钱变负 / 第 10 天"两条切场景早退。
#
# 覆盖 docs/DOC_AUDIT_2026-10-18.md §三 的 4 个 bug：
#   ① 点"返回主界面"（未提交）不得把委托标记完成   → 之前无条件 on_npc_completed()
#   ② 结算面板的正文提示词必须跟信型走             → 之前硬编码"家中/在外/盼"
#   ③ 扣钱扣成负数时不再回主界面（失败场景已接管） → 之前 add_money 后仍 return_to_main()
#   ④ 交摊位费可能破产 / 第 10 天进结局时早退     → 之前继续改已释放的 Main
#
# 用法：
#   pwsh -File tools\run-godot.ps1 --headless --script res://tools/verify_flow.gd
#
# ⚠️ 最后一条用例会**请求切换场景**（帧末才生效）。所以断言后立刻 quit()，
#    之后再也不要 await，否则 root 会被换成 gameover/success，后续用例全乱。
extends SceneTree

const LETTER_SCENE := "res://scenes/letter.tscn"
const STUB_MAIN := "res://tools/flow_stub_main.gd"

var _fails: Array[String] = []


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	get_root().size = Vector2i(1152, 648)

	# ⚠️ 必须等一帧再动：`--script` 的 `_initialize()` 跑在 SceneTree 激活之前，
	# 此时 root 还不在树内，**任何 `/root/xxx` 绝对路径都会返回 null**
	# （报 "Can't use get_node() with absolute paths from outside the active scene tree"）。
	# 一帧之后 root.is_inside_tree() 才为 true，letter.gd 内部的 get_node("/root/NPCManager") 才成立。
	await process_frame

	var pm = get_root().get_node_or_null("PlayerManager")
	var nm = get_root().get_node_or_null("NPCManager")
	if pm == null or nm == null:
		print("=== 结论: FAIL ===（找不到 PlayerManager / NPCManager）")
		quit(1)
		return

	# 自动存档会写 save_path：测试必须指向临时文件，**绝不能碰玩家真实存档**
	var original_save_path: String = pm.save_path
	var test_save_path := "user://save_flow_test.dat"
	pm.save_path = test_save_path
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))

	var main = _make_stub_main()

	print("=== ① 未提交就返回主界面：不许消耗委托 ===")
	await _case_back_without_submit(pm, nm, main)

	print("=== ② 结算面板的正文提示词随信型变化 ===")
	await _case_highlight_hints(pm, nm)

	print("=== ③ 提交并确认：记完成 + 记账 + 通知主界面 ===")
	await _case_settle_marks_completed(pm, nm, main)

	print("=== ④ 结束今日：正常推进（直接打 main.gd 的处理器）===")
	await _case_end_day_normal(pm)

	print("=== ⑤ 破产与第 10 天：必须早退（本轮不等帧）===")
	_case_bankruptcy_and_endgame(pm, nm, main)

	# 还原真实存档路径并清掉临时档
	pm.save_path = original_save_path
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
	print("  [OK] 已还原存档路径并清理临时档")

	if _fails.is_empty():
		print("=== 结论: PASS ===")
		quit(0)
	else:
		print("=== 结论: FAIL（%d 项）===" % _fails.size())
		for f in _fails:
			print("  [!] ", f)
		quit(1)


# ---------- 用例 ----------

func _case_back_without_submit(pm, nm, main) -> void:
	pm.reset()
	main.completed.clear()
	var npc: Dictionary = nm.get_today_npcs(1)[0]
	var letter = await _spawn_letter(npc)

	letter._on_back_pressed()
	await process_frame
	await process_frame

	_check(not pm.is_npc_completed(int(npc["npc_id"])), "未提交时委托未被标记完成")
	_check(main.completed.is_empty(), "未提交时未通知主界面")
	_check(not is_instance_valid(letter), "返回后代写界面已释放")


func _case_highlight_hints(pm, nm) -> void:
	pm.reset()
	var npc: Dictionary = nm.get_today_npcs(1)[0]
	var letter = await _spawn_letter(npc)
	letter._slot_hints = nm.get_slot_hints("贺寿")

	var correct := {
		"salutation": "祖母大人膝下",
		"body_slot1": "康健",
		"body_slot2": "纳福",
		"body_slot3": "欢聚",
		"signature": "孙拜上",
	}
	var item_ok := {
		"salutation": true,
		"body_slot1": false,
		"body_slot2": true,
		"body_slot3": true,
		"signature": true,
	}
	var text: String = letter._build_answer_highlight(correct, item_ok)
	print("  贺寿答案块：", text.replace("\n", " / "))
	_check(text.contains("福寿"), "贺寿正文提示词取到『福寿』")
	_check(not text.contains("家中"), "答案块不含家书专用的『家中』")
	letter.queue_free()
	await process_frame


func _case_settle_marks_completed(pm, nm, main) -> void:
	pm.reset()
	main.completed.clear()
	var npc: Dictionary = nm.get_today_npcs(2)[0]
	var letter = await _spawn_letter(npc)

	var correct: Dictionary = npc["correct"]
	var body: Dictionary = correct["body_slots"]
	letter.player_answers = {
		"salutation": correct["salutation"],
		"body_slot1": body["slot1"],
		"body_slot2": body["slot2"],
		"body_slot3": body["slot3"],
		"signature": correct["signature"],
	}

	var money_before: int = pm.money
	letter._on_submit_pressed()
	var fee := int(letter._pending_result.get("fee", 0))
	letter._on_result_popup_confirmed()

	_check(fee > 0, "全对时报酬为正（实测 %d）" % fee)
	_check(pm.money == money_before + fee, "钱按报酬增加（%d → %d）" % [money_before, pm.money])
	_check(pm.is_npc_completed(int(npc["npc_id"])), "结算后委托已标记完成")
	_check(main.completed.has(int(npc["npc_id"])), "结算后已通知主界面移除该委托")
	_check(letter.is_settled(), "is_settled() 结算后为 true")

	# 自动存档：完成一单后立刻落盘（旧实现只在"保存并退出"时写，关窗口会丢进度）
	var npc_id := int(npc["npc_id"])
	_check(FileAccess.file_exists(pm.save_path), "完成委托后自动写盘：%s" % pm.save_path)
	if FileAccess.file_exists(pm.save_path):
		var raw := FileAccess.get_file_as_string(pm.save_path)
		_check(raw.contains(str(npc_id)), "自动存档里含刚完成的委托 id（%d）" % npc_id)


func _case_end_day_normal(pm) -> void:
	# 直接调 main.gd 的结算处理器：验证"正常这一天"确实会推进（早退逻辑不能误伤正常路径）
	pm.reset()
	pm.mark_npc_completed(-12345)
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main_scene = packed.instantiate()
	get_root().add_child(main_scene)
	await process_frame

	main_scene._on_end_day_popup_confirmed()

	_check(pm.money == 90, "结算后余额为 90（100 − 10 摊位费）")
	_check(pm.day == 2, "结算后进入第 2 日")
	_check(not pm.is_npc_completed(-12345), "结算后当日完成列表已清空")
	main_scene.queue_free()
	await process_frame


func _case_bankruptcy_and_endgame(pm, nm, main) -> void:
	pm.reset()
	main.completed.clear()
	var npc: Dictionary = nm.get_today_npcs(3)[0]

	# 真实 letter 实例走一遍"扣钱扣成负数"（不 await：场景切换留在帧末）
	var packed: PackedScene = load(LETTER_SCENE)
	var letter = packed.instantiate()
	get_root().add_child(letter)
	letter.init_with_npc(int(npc["npc_id"]))
	pm.money = 5
	letter._pending_result = {"fee": -50}
	letter._on_result_popup_confirmed()

	_check(pm.money == -45, "破产用例余额为 -45")
	_check(main.completed.is_empty(), "破产时未通知主界面（不再白跑一单）")

	pm.money = 5
	_check(pm.apply_end_of_day_costs() == true, "摊位费致破产时 apply_end_of_day_costs() 返回 true")
	_check(pm.money == -5, "摊位费扣除后余额为 -5")

	pm.money = 600
	pm.day = 10
	_check(pm.next_day() == true, "第 10 天之后 next_day() 返回 true")
	_check(pm.day == 11, "next_day() 之后 day 为 11")


# ---------- 工具 ----------

func _spawn_letter(npc: Dictionary) -> Node:
	var packed: PackedScene = load(LETTER_SCENE)
	var inst: Node = packed.instantiate()
	get_root().add_child(inst)
	inst.init_with_npc(int(npc["npc_id"]))
	await process_frame
	return inst


func _make_stub_main() -> Node:
	var stub = load(STUB_MAIN).new()
	stub.name = "Main"
	get_root().add_child(stub)
	return stub


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  [OK] ", msg)
	else:
		print("  [FAIL] ", msg)
		_fails.append(msg)
