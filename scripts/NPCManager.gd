extends Node

# 当日生成的 NPC 列表，供 get_npc_by_id 查找
var current_day_npcs: Array = []

# ---------- 基础常量 ----------
const FIRST_NAMES = ["张", "王", "李", "刘", "陈", "赵", "周"]
const LAST_NAMES = ["大牛", "二狗", "翠花", "铁柱", "秀英", "有才", "三娘"]
const RELATIONS = ["父母", "子女", "夫妻", "兄弟", "朋友"]

# ---------- 信型 ----------
const LETTER_TYPES := ["家书", "请安", "贺寿", "诉苦", "求荐"]

# 称谓/落款按关系划分（与信型正交：称谓由辈分决定，信型体现在正文与故事）
const SALUTATION_POOL = {
	"父母": ["父母大人膝下", "爹娘亲启", "双亲大人安"],
	"子女": ["吾儿如晤", "吾女见字", "孩儿见字"],
	"夫妻": ["夫君如晤", "贤妻妆次", "良人如晤"],
	"兄弟": ["吾兄亲启", "贤弟如晤", "兄长如晤"],
	"朋友": ["仁兄足下", "好友如面", "某兄台鉴"]
}

const SIGNATURE_POOL = {
	"父母": ["男叩上", "儿拜上", "儿敬禀"],
	"子女": ["父字", "母字", "父手书"],
	"夫妻": ["妾拜上", "夫字", "良人字"],
	"兄弟": ["弟谨启", "兄字", "弟拜上"],
	"朋友": ["友拜上", "弟谨启", "友顿首"]
}

# 正文词库按信型划分（每槽 6 词）
const BODY_POOLS = {
	"家书": {
		"slot1": ["安好", "安康", "平安", "无事", "顺遂", "如意"],
		"slot2": ["勿念", "保重", "加衣", "早归", "节劳", "珍重"],
		"slot3": ["回信", "团聚", "归家", "平安", "相会", "团圆"]
	},
	"请安": {
		"slot1": ["康健", "安泰", "平安", "顺遂", "无恙", "安康"],
		"slot2": ["自珍", "节劳", "添衣", "保重", "宽心", "勿虑"],
		"slot3": ["回音", "相见", "平安", "珍重", "叙话", "团圆"]
	},
	"贺寿": {
		"slot1": ["康健", "福寿", "安康", "矍铄", "延年", "益寿"],
		"slot2": ["添寿", "纳福", "吉祥", "如意", "安康", "顺遂"],
		"slot3": ["团圆", "寿宴", "欢聚", "畅饮", "相见", "福泽"]
	},
	"诉苦": {
		"slot1": ["艰难", "困顿", "拮据", "窘迫", "潦倒", "维艰"],
		"slot2": ["帮衬", "周济", "援手", "照拂", "垂怜", "接济"],
		"slot3": ["相助", "接济", "回信", "脱困", "救急", "扶持"]
	},
	"求荐": {
		"slot1": ["才学", "功名", "志向", "文章", "抱负", "勤学"],
		"slot2": ["举荐", "引荐", "提携", "栽培", "保举", "引路"],
		"slot3": ["相助", "引路", "成全", "提点", "荐引", "疏通"]
	}
}

# 故事模板按信型划分（{name}/{relation}/{slot1}/{slot2}/{slot3} 会被填充）
const STORY_TEMPLATES = {
	"家书": [
		"我是{name}，想给{relation}写封信。家中{slot1}，在外{slot2}，盼{slot3}。",
		"给我{relation}带个话：家里{slot1}，你在外要{slot2}，记得{slot3}。",
		"写封信给{relation}：{slot1}，{slot2}，{slot3}。",
		"久未给{relation}去信，家中{slot1}，只愿{slot2}，还望{slot3}。"
	],
	"请安": [
		"给{relation}请安：近来{slot1}否？望{relation}{slot2}，只盼{slot3}。",
		"{name}给{relation}问安：家中{slot1}，望{relation}{slot2}，得闲{slot3}。",
		"许久未见{relation}，特修书请安：{slot1}，{slot2}，{slot3}。"
	],
	"贺寿": [
		"欣逢{relation}寿辰，{name}特来贺寿：愿{slot1}，{slot2}，{slot3}。",
		"恭祝{relation}寿辰：愿{slot1}，更愿{slot2}，他日{slot3}。",
		"贺{relation}华诞：{slot1}，{slot2}，{slot3}。"
	],
	"诉苦": [
		"家中{slot1}，{name}在外求告无门，恳请{relation}{slot2}，{slot3}。",
		"近来{slot1}，{name}困顿，望{relation}{slot2}，{slot3}。",
		"向{relation}诉苦：{slot1}，{slot2}，盼{slot3}。"
	],
	"求荐": [
		"欲赴科考，苦无门路。{name}有{slot1}之志，{slot2}之望，恳请{relation}{slot3}。",
		"{name}求{relation}荐举：{slot1}，{slot2}，{slot3}。",
		"今有{slot1}，望{relation}{slot2}，{slot3}。"
	]
}

# 正文三槽的界面提示词（按信型）：letter.gd 据此生成词库标签与信纸槽位占位符
const SLOT_HINTS = {
	"家书": {"slot1": "家中", "slot2": "在外", "slot3": "盼"},
	"请安": {"slot1": "近况", "slot2": "珍重", "slot3": "盼音"},
	"贺寿": {"slot1": "福寿", "slot2": "纳福", "slot3": "欢聚"},
	"诉苦": {"slot1": "处境", "slot2": "求援", "slot3": "盼助"},
	"求荐": {"slot1": "才学", "slot2": "引荐", "slot3": "成全"}
}

const DEFAULT_SLOT_HINTS = {"slot1": "其一", "slot2": "其二", "slot3": "其三"}

const FEEDBACK_PERFECT = ["先生写得真好！", "正是我想说的！", "太感谢了！", "妙极，正是此意！"]
const FEEDBACK_GOOD = ["不错，再仔细些就更好了", "大体妥当", "尚可，有几处不妥"]
const FEEDBACK_NORMAL = ["还行吧", "就这样", "可以了", "凑合"]
const FEEDBACK_WRONG = ["不对不对", "这写的啥？", "重写！", "格式都不对！"]

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

func get_npc_by_id(npc_id: int) -> Dictionary:
	var id_int := int(npc_id)
	for npc in current_day_npcs:
		if int(npc.get("npc_id", 0)) == id_int:
			return npc
	return {}
