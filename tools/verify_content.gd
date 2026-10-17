# 回归校验：NPC 内容数据的不变量 + 字体覆盖
#
# 为什么需要：判定、拖拽、UI 都假设 NPCManager 的数据自洽 ——
#   ① 正解的每一项都必须**在对应词库里**（否则玩家永远被判"格式错误"）
#   ② 同一槽位的词库不能有重复（否则界面出现两个一模一样的可拖按钮）
#   ③ 词库不能为空
#   ④ 故事文本里必须能读到三个正文正解（本作核心玩法：读故事 → 选词）
#   ⑤ base_fee / perfect_bonus 必须符合文档公式
#   ⑥ 称谓/正文/落款里出现的每个汉字，项目字体都要有字形
#      （字体 CJK 覆盖率仅 32.4%；缺字会落到系统字体，信纸书法混排会被破坏）
# 扩充词库（docs/CONTENT_PROPOSAL.md 方案 A）之后，这道闸门就是验收标准。
#
# 用法：
#   pwsh -File tools\run-godot.ps1 --headless --script res://tools/verify_content.gd
extends SceneTree

const FONT_PATH := "res://assets/fonts/hanchanlongcang.otf"
const SAMPLE_ROUNDS := 400          # 抽样天数轮数（每轮 3 个 NPC）
const EXPECTED_TYPES := 5
const EXPECTED_RELATIONS := 5

var _fails: Array[String] = []


func _initialize() -> void:
	await process_frame  # --script 的 _initialize 早于 SceneTree 激活（AI_PLAYBOOK 第 21 条）

	var nm = get_root().get_node_or_null("NPCManager")
	if nm == null:
		print("=== 结论: FAIL ===（找不到 NPCManager）")
		quit(1)
		return

	var seen_types := {}
	var seen_relations := {}
	var seen_salutation := {}
	var seen_body := {}          # "type/slot" -> {词: true}
	var seen_signature := {}
	var seen_ids := {}           # npc_id 必须唯一（撞了会让 get_npc_by_id / 完成标记张冠李戴）
	var checked := 0

	for round_i in range(SAMPLE_ROUNDS):
		var day := 1 + (round_i % 10)
		for npc in nm.get_today_npcs(day):
			checked += 1
			var nid := int(npc.get("npc_id", 0))
			_check(nid < 0, "npc_id 为负数（实测 %d）" % nid)
			_check(not seen_ids.has(nid), "npc_id 唯一（冲突值 %d）" % nid)
			seen_ids[nid] = true
			_check_npc(npc, day, seen_types, seen_relations, seen_salutation, seen_body, seen_signature)

	print("=== 覆盖统计 ===")
	print("  抽样 NPC：%d 个" % checked)
	print("  唯一 npc_id：%d 个" % seen_ids.size())
	_check(seen_ids.size() == checked, "npc_id 无重复（唯一 %d / 抽样 %d）" % [seen_ids.size(), checked])
	print("  信型：%s" % str(seen_types.keys()))
	print("  关系：%s" % str(seen_relations.keys()))
	_check(seen_types.size() == EXPECTED_TYPES, "5 种信型都出现过（实测 %d）" % seen_types.size())
	_check(seen_relations.size() == EXPECTED_RELATIONS, "5 种关系都出现过（实测 %d）" % seen_relations.size())

	# 每个「信型+槽位」都收集到了词库，且非空
	var body_slot_keys: Array = seen_body.keys()
	body_slot_keys.sort()
	print("  正文槽位：%s" % str(body_slot_keys))
	_check(body_slot_keys.size() == EXPECTED_TYPES * 3, "正文词库覆盖 5 信型 × 3 槽（实测 %d 组）" % body_slot_keys.size())

	var salutation_words := seen_salutation.keys()
	var signature_words := seen_signature.keys()
	print("  称谓词 %d 个，落款词 %d 个" % [salutation_words.size(), signature_words.size()])

	# ------------------------------------------------------------------
	print("=== 字体覆盖（%s）===" % FONT_PATH)
	var font: Font = null
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH) as Font
	_check(font != null, "项目字体已加载")
	if font != null:
		var all_words: Array = []
		all_words.append_array(salutation_words)
		all_words.append_array(signature_words)
		for k in body_slot_keys:
			all_words.append_array((seen_body[k] as Dictionary).keys())
		var chars := {}
		for w in all_words:
			for i in range(str(w).length()):
				chars[str(w)[i]] = true
		var missing: Array = []
		for ch in chars.keys():
			if not font.has_char(str(ch).unicode_at(0)):
				missing.append(ch)
		print("  待检汉字 %d 个，缺字形 %d 个" % [chars.size(), missing.size()])
		if missing.size() > 0:
			print("  缺字：%s" % str(missing))
		_check(missing.is_empty(), "称谓/正文/落款用字在项目字体里都有字形")

	if _fails.is_empty():
		print("=== 结论: PASS ===")
		quit(0)
	else:
		print("=== 结论: FAIL（%d 项）===" % _fails.size())
		for f in _fails:
			print("  [!] ", f)
		quit(1)


func _check_npc(npc: Dictionary, day: int, seen_types: Dictionary, seen_relations: Dictionary,
		seen_salutation: Dictionary, seen_body: Dictionary, seen_signature: Dictionary) -> void:
	var letter_type := str(npc.get("letter_type", ""))
	var relation := str(npc.get("relation", ""))
	var name := str(npc.get("name", "?"))
	var where := "%s/%s(day %d)" % [name, letter_type, day]

	seen_types[letter_type] = true
	seen_relations[relation] = true

	var correct: Dictionary = npc.get("correct", {})
	var correct_body: Dictionary = correct.get("body_slots", {})
	var pool: Dictionary = npc.get("word_pool", {})
	var pool_body: Dictionary = pool.get("body_slots", {})
	var sal_pool: Array = pool.get("salutation", [])
	var sig_pool: Array = pool.get("signature", [])

	# ① 正解 ⊆ 词库
	_check(sal_pool.has(str(correct.get("salutation", ""))), "%s：称谓正解在词库内" % where)
	for slot in ["slot1", "slot2", "slot3"]:
		var pool_arr: Array = pool_body.get(slot, [])
		_check(pool_arr.has(str(correct_body.get(slot, ""))), "%s：正文 %s 正解在词库内" % [where, slot])
	_check(sig_pool.has(str(correct.get("signature", ""))), "%s：落款正解在词库内" % where)

	# ② 同一槽位词库无重复
	_check(_is_unique(sal_pool), "%s：称谓词库无重复" % where)
	for slot in ["slot1", "slot2", "slot3"]:
		_check(_is_unique(pool_body.get(slot, [])), "%s：正文 %s 词库无重复" % [where, slot])
	_check(_is_unique(sig_pool), "%s：落款词库无重复" % where)

	# ③ 词库非空
	_check(not sal_pool.is_empty() and not sig_pool.is_empty(), "%s：称谓/落款词库非空" % where)
	for slot in ["slot1", "slot2", "slot3"]:
		_check(not (pool_body.get(slot, []) as Array).is_empty(), "%s：正文 %s 词库非空" % [where, slot])

	# ④ 故事文本包含三个正文正解
	var story := str(npc.get("request_text", ""))
	for slot in ["slot1", "slot2", "slot3"]:
		_check(story.contains(str(correct_body.get(slot, ""))), "%s：故事包含正文 %s 正解" % [where, slot])

	# ⑤ 报酬公式
	var base_want := 12 + floori((day - 1) / 3.0)
	var bonus_want := 8 + (day - 1)
	_check(int(npc.get("base_fee", -1)) == base_want, "%s：base_fee = %d" % [where, base_want])
	_check(int(npc.get("perfect_bonus", -1)) == bonus_want, "%s：perfect_bonus = %d" % [where, bonus_want])

	# 收集用字（去重）
	for w in sal_pool:
		seen_salutation[str(w)] = true
	for w in sig_pool:
		seen_signature[str(w)] = true
	for slot in ["slot1", "slot2", "slot3"]:
		var key := "%s/%s" % [letter_type, slot]
		if not seen_body.has(key):
			seen_body[key] = {}
		for w in pool_body.get(slot, []):
			(seen_body[key] as Dictionary)[str(w)] = true


func _is_unique(arr: Array) -> bool:
	var seen := {}
	for v in arr:
		var k := str(v)
		if seen.has(k):
			return false
		seen[k] = true
	return true


func _check(cond: bool, msg: String) -> void:
	if not cond:
		print("  [FAIL] ", msg)
		_fails.append(msg)
