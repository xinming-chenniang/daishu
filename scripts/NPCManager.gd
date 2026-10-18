extends Node

# 当日生成的 NPC 列表，供 get_npc_by_id 查找
var current_day_npcs: Array = []

## 内容真源：data/npc_content.json（2026-10-18 由硬编码常量迁出，见 docs/NPC_GENERATION.md）。
## 改文案/词库只改 JSON；改完必须跑 tools/verify_content.gd 与 tools/check_content_chars.py。
const CONTENT_PATH := "res://data/npc_content.json"

# ---------- 内容（运行时从 JSON 加载；变量名保持原样，调用点不用改）----------
var FIRST_NAMES: Array = []
var LAST_NAMES: Array = []
var RELATIONS: Array = []
var LETTER_TYPES: Array = []
var SALUTATION_POOL: Dictionary = {}
var SIGNATURE_POOL: Dictionary = {}
var BODY_POOLS: Dictionary = {}
var STORY_TEMPLATES: Dictionary = {}
var SLOT_HINTS: Dictionary = {}
## 信稿结构（每信型的起首语/正文连缀/结尾敬语）+ 落款日期（按天数）
var LETTER_FORM: Dictionary = {}
var LETTER_DATES: Array = []
var FEEDBACK_PERFECT: Array = []
var FEEDBACK_GOOD: Array = []
var FEEDBACK_NORMAL: Array = []
var FEEDBACK_WRONG: Array = []

const DEFAULT_SLOT_HINTS = {"slot1": "其一", "slot2": "其二", "slot3": "其三"}
## 游戏天数上限（与 PlayerManager.TOTAL_DAYS 一致；这里只用于"日期至少要 10 条"的校验）
const TOTAL_DAYS_HINT := 10

## 内容加载失败原因（空字符串 = 加载成功）。verify_content 会断言它为空。
var content_error: String = ""


func _ready() -> void:
	load_content()


## 从 JSON 载入全部内容；结构缺项时视为失败（宁可启动就报错，也不要运行到一半才炸）。
func load_content() -> bool:
	content_error = ""
	if not FileAccess.file_exists(CONTENT_PATH):
		content_error = "找不到内容文件：%s" % CONTENT_PATH
		push_error(content_error)
		return false
	var text := FileAccess.get_file_as_string(CONTENT_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		content_error = "内容文件不是合法 JSON 对象：%s" % CONTENT_PATH
		push_error(content_error)
		return false

	var c: Dictionary = parsed
	FIRST_NAMES = _strings(c.get("first_names", []))
	LAST_NAMES = _strings(c.get("last_names", []))
	RELATIONS = _strings(c.get("relations", []))
	LETTER_TYPES = _strings(c.get("letter_types", []))
	SALUTATION_POOL = _dict_of(c, "salutation")
	SIGNATURE_POOL = _dict_of(c, "signature")
	BODY_POOLS = _dict_of(c, "body")
	STORY_TEMPLATES = _dict_of(c, "templates")
	SLOT_HINTS = _dict_of(c, "slot_hints")
	LETTER_FORM = _dict_of(c, "letter_form")
	LETTER_DATES = _strings(c.get("dates", []))

	var fb: Dictionary = c.get("feedback", {}) if c.get("feedback", {}) is Dictionary else {}
	FEEDBACK_PERFECT = _strings(fb.get("perfect", []))
	FEEDBACK_GOOD = _strings(fb.get("good", []))
	FEEDBACK_NORMAL = _strings(fb.get("normal", []))
	FEEDBACK_WRONG = _strings(fb.get("wrong", []))

	var missing: Array = []
	if FIRST_NAMES.is_empty(): missing.append("first_names")
	if LAST_NAMES.is_empty(): missing.append("last_names")
	if RELATIONS.is_empty(): missing.append("relations")
	if LETTER_TYPES.is_empty(): missing.append("letter_types")
	if SALUTATION_POOL.is_empty(): missing.append("salutation")
	if SIGNATURE_POOL.is_empty(): missing.append("signature")
	if BODY_POOLS.is_empty(): missing.append("body")
	if STORY_TEMPLATES.is_empty(): missing.append("templates")
	if SLOT_HINTS.is_empty(): missing.append("slot_hints")
	if FEEDBACK_PERFECT.is_empty() or FEEDBACK_GOOD.is_empty() \
			or FEEDBACK_NORMAL.is_empty() or FEEDBACK_WRONG.is_empty():
		missing.append("feedback")
	if LETTER_DATES.size() < TOTAL_DAYS_HINT:
		missing.append("dates（至少要 10 条）")
	for t in LETTER_TYPES:
		var form: Dictionary = LETTER_FORM.get(t, {})
		if form.is_empty() or not form.has("opening") or not form.has("body") or not form.has("closing"):
			missing.append("letter_form.%s" % t)
		elif not str(form.get("body", "")).contains("{slot1}") \
				or not str(form.get("body", "")).contains("{slot2}") \
				or not str(form.get("body", "")).contains("{slot3}"):
			missing.append("letter_form.%s.body（缺 {slot1..3}）" % t)
	if not missing.is_empty():
		content_error = "内容文件缺字段：%s" % ", ".join(missing)
		push_error(content_error)
		return false
	return true


func is_content_loaded() -> bool:
	return content_error.is_empty() and not RELATIONS.is_empty()


func _strings(v) -> Array:
	var out: Array = []
	if v is Array:
		for item in v:
			out.append(str(item))
	return out


func _dict_of(d: Dictionary, key: String) -> Dictionary:
	var v = d.get(key, {})
	return v if v is Dictionary else {}


## 单调递增的序号，用来保证 npc_id 在**同一进程内绝不重复**。
## 旧实现是 `-(unix + randi()%10000)`：同一秒内生成的两个 NPC 有 1/10000 概率撞 id，
## 撞了之后 `get_npc_by_id()` 只会返回第一个，完成标记会张冠李戴。
## 现在改成 `-(unix*1e6 + 序号)`：同秒内靠序号区分，跨秒靠 unix 区分；序号**不取模**
## （取模到 1000 时，测试里 1 秒内生成 1200 个 NPC 会绕回撞号 —— 实测踩到过）。
## 取值范围 ~1.7e15，低于 2^53，JSON 往返不会丢精度。
var _npc_id_counter: int = 0


func _next_npc_id() -> int:
	_npc_id_counter += 1
	var stamp := int(Time.get_unix_time_from_system())
	return -(stamp * 1_000_000 + _npc_id_counter)


func generate_random_npc(day: int = 1) -> Dictionary:
	if not is_content_loaded():
		push_error("NPC 内容未加载，无法生成委托：%s" % content_error)
		return {}
	var npc_id: int = _next_npc_id()

	var first: String = FIRST_NAMES[randi() % FIRST_NAMES.size()]
	var last: String = LAST_NAMES[randi() % LAST_NAMES.size()]
	var npc_name: String = first + last

	var relation: String = RELATIONS[randi() % RELATIONS.size()]
	var letter_type: String = LETTER_TYPES[randi() % LETTER_TYPES.size()]

	var salutation_pool: Array = SALUTATION_POOL[relation]
	var signature_pool: Array = SIGNATURE_POOL[relation]
	var body_pool: Dictionary = BODY_POOLS[letter_type]

	var correct_salutation: String = salutation_pool[randi() % salutation_pool.size()]
	var correct_signature: String = signature_pool[randi() % signature_pool.size()]
	var correct_body: Dictionary = {
		"slot1": body_pool["slot1"][randi() % body_pool["slot1"].size()],
		"slot2": body_pool["slot2"][randi() % body_pool["slot2"].size()],
		"slot3": body_pool["slot3"][randi() % body_pool["slot3"].size()]
	}

	var word_pool: Dictionary = {
		"salutation": salutation_pool,
		"body_slots": {
			"slot1": body_pool["slot1"],
			"slot2": body_pool["slot2"],
			"slot3": body_pool["slot3"]
		},
		"signature": signature_pool
	}

	var templates: Array = STORY_TEMPLATES[letter_type]
	var story: String = templates[randi() % templates.size()].format({
		"name": npc_name,
		"relation": relation,
		"slot1": correct_body["slot1"],
		"slot2": correct_body["slot2"],
		"slot3": correct_body["slot3"]
	})

	var feedback: Dictionary = {
		"perfect": FEEDBACK_PERFECT[randi() % FEEDBACK_PERFECT.size()],
		"good": FEEDBACK_GOOD[randi() % FEEDBACK_GOOD.size()],
		"normal": FEEDBACK_NORMAL[randi() % FEEDBACK_NORMAL.size()],
		"wrong": FEEDBACK_WRONG[randi() % FEEDBACK_WRONG.size()]
	}

	# 随天数递增奖励：后期 NPC 更"大方"，给玩家追赶机制
	var scaled_bonus: int = 8 + (day - 1)
	var scaled_base: int = 12 + floori((day - 1) / 3.0)

	var description: String = "一位想给%s写信的%s" % [relation, letter_type]

	return {
		"npc_id": npc_id,
		"name": npc_name,
		"first_day": 1,
		"required_calligraphy": 0,
		"avatar": "",
		"relation": relation,
		"description": description,
		"letter_type": letter_type,
		"request_text": story,
		"correct": {
			"salutation": correct_salutation,
			"body_slots": correct_body,
			"signature": correct_signature
		},
		"word_pool": word_pool,
		"base_fee": scaled_base,
		"perfect_bonus": scaled_bonus,
		"feedback": feedback
	}

func get_today_npcs(day: int) -> Array:
	var result: Array = []
	for i in range(3):
		result.append(generate_random_npc(day))
	current_day_npcs = result
	return result

func get_slot_hints(letter_type: String) -> Dictionary:
	return SLOT_HINTS.get(letter_type, DEFAULT_SLOT_HINTS)

## 信稿结构：{opening, body（含 {slot1..3}）, closing}；未知信型返回空字典
func get_letter_form(letter_type: String) -> Dictionary:
	var f = LETTER_FORM.get(letter_type, {})
	return f if f is Dictionary else {}

## 落款日期：第 day 天对应的节气（越界时夹到首尾）
func get_date_line(day: int) -> String:
	if LETTER_DATES.is_empty():
		return ""
	var idx: int = clampi(day - 1, 0, LETTER_DATES.size() - 1)
	return str(LETTER_DATES[idx])

func get_npc_by_id(npc_id: int) -> Dictionary:
	var id_int := int(npc_id)
	for npc in current_day_npcs:
		if int(npc.get("npc_id", 0)) == id_int:
			return npc
	return {}
