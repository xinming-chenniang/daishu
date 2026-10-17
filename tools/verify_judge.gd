# 回归校验：JudgeSystem 的四档判定与优先级（此前只有 verify_drop 覆盖"全对"一条路）
#
# 判据来自 docs/JUDGE_SYSTEM_LOGIC.md 与 AGENTS.md「经济数值」：
#   格式错误（留空 / 词库外词）> 五项全对 > 四对 > 其余
#   WRONG = -2 × 错误项数（**直接判负，不叠加底薪**）
#   GOOD  = base + int(bonus × 0.7)
#   NORMAL = int(base × 0.6)
#
# 用法：
#   pwsh -File tools\run-godot.ps1 --headless --script res://tools/verify_judge.gd
extends SceneTree

var _fails: Array[String] = []


func _initialize() -> void:
	await process_frame  # --script 的 _initialize 早于 SceneTree 激活，见 AI_PLAYBOOK 第 21 条

	var judge = get_root().get_node_or_null("JudgeSystem")
	if judge == null:
		print("=== 结论: FAIL ===（找不到 JudgeSystem）")
		quit(1)
		return

	# 一份固定 NPC：底薪 12、完美加成 8 → PERFECT=20 / GOOD=12+5=17 / NORMAL=int(12*0.6)=7
	var npc := {
		"base_fee": 12,
		"perfect_bonus": 8,
		"correct": {
			"salutation": "贤弟如晤",
			"body_slots": {"slot1": "康健", "slot2": "如意", "slot3": "畅饮"},
			"signature": "弟拜上",
		},
		"word_pool": {
			"salutation": ["贤弟如晤", "吾兄亲启"],
			"body_slots": {
				"slot1": ["康健", "安泰"],
				"slot2": ["如意", "吉祥"],
				"slot3": ["畅饮", "欢聚"],
			},
			"signature": ["弟拜上", "兄字"],
		},
		"feedback": {"perfect": "p", "good": "g", "normal": "n", "wrong": "w"},
	}

	var perfect := _answers()
	_case(judge, npc, perfect, "PERFECT", 20, "五项全对 → PERFECT / 20 文")

	var good := _answers()
	good["signature"] = "兄字"  # 词库内但非正解
	_case(judge, npc, good, "GOOD", 17, "四对一错（词库内）→ GOOD / 12+int(8×0.7)=17")

	var normal := _answers()
	normal["body_slot2"] = "吉祥"
	normal["body_slot3"] = "欢聚"
	_case(judge, npc, normal, "NORMAL", 7, "三对两错（词库内）→ NORMAL / int(12×0.6)=7")

	var one_empty := _answers()
	one_empty["body_slot1"] = ""
	_case(judge, npc, one_empty, "WRONG", -2, "留空 1 项（其余全对）→ WRONG / -2（格式错误优先于正确数）")

	var two_out_of_pool := _answers()
	two_out_of_pool["salutation"] = "不在词库里的称谓"
	two_out_of_pool["body_slot3"] = "不在词库里的词"
	_case(judge, npc, two_out_of_pool, "WRONG", -4, "词库外 2 项 → WRONG / -4")

	# 优先级交叉验证：4 项全对 + 1 项留空，必须 WRONG 而不是 GOOD
	var four_correct_one_blank := _answers()
	four_correct_one_blank["signature"] = ""
	var r = judge.judge(npc, four_correct_one_blank)
	_check(r["result_code"] == "WRONG", "4 对 + 1 空 → WRONG（不是 GOOD）")
	_check(int(r["format_error_count"]) == 1, "format_error_count = 1")
	_check(int(r["perfect_count"]) == 4, "perfect_count = 4")
	_check(int(r["fee"]) == -2, "fee = -2（不叠加底薪）")

	# 返回结构：正确答案 + 每项对错（结算面板依赖）
	var item_ok: Dictionary = r["item_correct"]
	var correct_answers: Dictionary = r["correct_answers"]
	_check(item_ok["signature"] == false, "item_correct.signature = false")
	_check(item_ok["salutation"] == true, "item_correct.salutation = true")
	_check(str(correct_answers["body_slot2"]) == "如意", "correct_answers.body_slot2 = 如意")

	# 空 NPC / 空答案不应崩
	var empty_npc := {}
	var r2 = judge.judge(empty_npc, _answers())
	_check(r2["result_code"] == "WRONG", "空 NPC（无词库）→ 全部按格式错误判 WRONG")
	_check(int(r2["fee"]) == -10, "空 NPC 五项全空 → fee = -2×5 = -10")

	if _fails.is_empty():
		print("=== 结论: PASS ===")
		quit(0)
	else:
		print("=== 结论: FAIL（%d 项）===" % _fails.size())
		for f in _fails:
			print("  [!] ", f)
		quit(1)


func _answers() -> Dictionary:
	return {
		"salutation": "贤弟如晤",
		"body_slot1": "康健",
		"body_slot2": "如意",
		"body_slot3": "畅饮",
		"signature": "弟拜上",
	}


func _case(judge, npc: Dictionary, answers: Dictionary, want_code: String, want_fee: int, msg: String) -> void:
	var r: Dictionary = judge.judge(npc, answers)
	var got_code := str(r.get("result_code", ""))
	var got_fee := int(r.get("fee", 0))
	if got_code == want_code and got_fee == want_fee:
		print("  [OK] %s（%s / %d 文）" % [msg, got_code, got_fee])
	else:
		print("  [FAIL] %s —— 期望 %s/%d，实得 %s/%d" % [msg, want_code, want_fee, got_code, got_fee])
		_fails.append(msg)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  [OK] ", msg)
	else:
		print("  [FAIL] ", msg)
		_fails.append(msg)
