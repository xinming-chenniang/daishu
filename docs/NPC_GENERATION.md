## NPCManager.generate_random_npc() 生成逻辑说明

本文档基于 `scripts/NPCManager.gd` 的 `generate_random_npc()` 方法，总结随机 NPC 的常量池配置和生成算法。

> **内容真源已迁到 JSON（2026-10-18）**：所有词库/模板/称谓/落款/提示词/反馈都在
> `data/npc_content.json`，运行时由 `NPCManager.load_content()` 读入（`CONTENT_PATH`）。
> **改内容只改 JSON**，改完跑 `tools/verify_content.gd` + `tools/check_content_chars.py`。
> 本文下半部分的具体列表是**最初的硬编码快照**，只作设计记录，数值以 JSON 为准。

> ⚠️ **数据规模（2026-10-18，内容方案 A）**：
> 称谓 **5 条/关系**、落款 **4 条/关系**、正文 **10 词/槽**（5 信型 × 3 槽 = 150 个词位）、
> 故事模板 **26 条**（家书 6 / 请安 5 / 贺寿 5 / 诉苦 5 / 求荐 5）。
>
> **生成算法本身未变**：随机选取正解 → 把正解嵌进故事模板 → 构造与正解平行的 `word_pool`。
> 扩充的完整记录与验收见 `docs/CONTENT_PROPOSAL.md`。

---

## 一、常量池配置

### 1. 姓名与关系

| 名称 | 类型 | 内容 |
| --- | --- | --- |
| `FIRST_NAMES` | `Array[String]` | `["张", "王", "李", "刘", "陈", "赵", "周"]` |
| `LAST_NAMES` | `Array[String]` | `["大牛", "二狗", "翠花", "铁柱", "秀英", "有才", "三娘"]` |
| `RELATIONS` | `Array[String]` | `["父母", "子女", "夫妻", "兄弟", "朋友"]` |

> 说明：NPC 姓名由 `FIRST_NAMES` 与 `LAST_NAMES` 拼接而成，例如 `"张大牛"`；  
> `RELATIONS` 表示与收信人的关系，用于选取对应的称谓与落款池。

### 2. 称谓池 `SALUTATION_POOL`

按关系划分的称谓候选列表：

| 关系 key | 类型 | 值（称谓候选） |
| --- | --- | --- |
| `"父母"` | `Array[String]` | `["父母大人膝下", "爹娘亲启"]` |
| `"子女"` | `Array[String]` | `["吾儿如晤", "吾女见字"]` |
| `"夫妻"` | `Array[String]` | `["夫君如晤", "贤妻妆次"]` |
| `"兄弟"` | `Array[String]` | `["吾兄亲启", "贤弟如晤"]` |
| `"朋友"` | `Array[String]` | `["仁兄足下", "好友如面"]` |

### 3. 落款池 `SIGNATURE_POOL`

同样按关系划分的落款候选列表：

| 关系 key | 类型 | 值（落款候选） |
| --- | --- | --- |
| `"父母"` | `Array[String]` | `["男叩上", "儿拜上"]` |
| `"子女"` | `Array[String]` | `["父字", "母字"]` |
| `"夫妻"` | `Array[String]` | `["妾拜上", "夫字"]` |
| `"兄弟"` | `Array[String]` | `["弟谨启", "兄字"]` |
| `"朋友"` | `Array[String]` | `["友拜上", "弟谨启"]` |

### 4. 正文三槽词库

三个正文槽位各自的候选词：

| 名称 | 类型 | 候选词列表 |
| --- | --- | --- |
| `BODY_SLOT1_WORDS` | `Array[String]` | `["安好", "安康", "平安", "无事"]` |
| `BODY_SLOT2_WORDS` | `Array[String]` | `["勿念", "保重", "加衣", "早归"]` |
| `BODY_SLOT3_WORDS` | `Array[String]` | `["回信", "团聚", "归家", "平安"]` |

> 这些候选词会同时用于：
> - 随机选出本 NPC 的“正确答案” `correct_body.slot1/2/3`；
> - 构造 `word_pool.body_slots`，作为代写界面左侧词库与判定合法输入的来源。

### 5. 反馈池（评价语）

根据判定结果不同，NPC 使用不同反馈语：

| 名称 | 类型 | 内容 |
| --- | --- | --- |
| `FEEDBACK_PERFECT` | `Array[String]` | `["先生写得真好！", "正是我想说的！", "太感谢了！"]` |
| `FEEDBACK_NORMAL` | `Array[String]` | `["还行吧", "就这样", "可以了"]` |
| `FEEDBACK_WRONG` | `Array[String]` | `["不对不对", "这写的啥？", "重写！"]` |

> 最终生成的 `feedback` 字典中，会从各自数组中随机挑一条作为 NPC 本次使用的反馈文本。

---

## 二、生成算法伪代码

`generate_random_npc() -> Dictionary` 的算法可概括为：

```pseudo
function generate_random_npc():
    # 1. 生成唯一 npc_id（负数，基于当前时间戳和随机数）
    npc_id = -int(Time.get_unix_time_from_system() + random_int(0, 9999))

    # 2. 随机姓名
    first = random_choice(FIRST_NAMES)
    last  = random_choice(LAST_NAMES)
    npc_name = first + last

    # 3. 随机关系，并选取对应的称谓/落款池
    relation        = random_choice(RELATIONS)
    salutation_pool = SALUTATION_POOL[relation]
    signature_pool  = SIGNATURE_POOL[relation]

    # 4. 从池中选出本 NPC 的“正确称谓”和“正确落款”
    correct_salutation = random_choice(salutation_pool)
    correct_signature  = random_choice(signature_pool)

    # 5. 为正文三个槽位随机选出正确词
    correct_body = {
        "slot1": random_choice(BODY_SLOT1_WORDS),
        "slot2": random_choice(BODY_SLOT2_WORDS),
        "slot3": random_choice(BODY_SLOT3_WORDS)
    }

    # 6. 构造词库 word_pool，供 UI 和判定系统使用
    word_pool = {
        "salutation": salutation_pool,
        "body_slots": {
            "slot1": BODY_SLOT1_WORDS,
            "slot2": BODY_SLOT2_WORDS,
            "slot3": BODY_SLOT3_WORDS
        },
        "signature": signature_pool
    }

    # 7. 生成 NPC 的口述故事文本（request_text）
    template = random_choice(story_templates)  # 共 3 条模板句
    story = template.format({
        "name": npc_name,
        "relation": relation,
        "slot1": correct_body["slot1"],
        "slot2": correct_body["slot2"],
        "slot3": correct_body["slot3"]
    })

    # 8. 随机挑选本 NPC 使用的三类反馈文本
    feedback = {
        "perfect": random_choice(FEEDBACK_PERFECT),
        "normal":  random_choice(FEEDBACK_NORMAL),
        "wrong":   random_choice(FEEDBACK_WRONG)
    }

    # 9. 返回 NPC 字典
    return {
        "npc_id": npc_id,
        "name": npc_name,
        "first_day": 1,
        "required_calligraphy": 0,
        "avatar": "",
        "description": "一位普通的路人",
        "letter_type": "家书",
        "request_text": story,
        "correct": {
            "salutation": correct_salutation,
            "body_slots": correct_body,
            "signature": correct_signature
        },
        "word_pool": word_pool,
        "base_fee": 12,
        "perfect_bonus": 8,
        "feedback": feedback
    }
```

---

## 三、最终 NPC 字典字段说明

生成出的 NPC 是一个结构固定的 `Dictionary`，用于：

- 主界面展示 NPC 名字与委托入口；
- 代写界面展示故事文本和构建词库；
- 判定系统使用 `correct` 和 `word_pool` 进行判分与计费；
- 记录流水和存档时写入 `meta` 信息。

下面以 JSON 形式示例，并逐字段说明：

```json
{
  "npc_id": -123456789,
  "name": "张大牛",
  "first_day": 1,
  "required_calligraphy": 0,
  "avatar": "",
  "description": "一位普通的路人",
  "letter_type": "家书",
  "request_text": "我是张大牛，想给父母写封信。家中安好，在外保重，盼团聚。",
  "correct": {
    "salutation": "父母大人膝下",
    "body_slots": {
      "slot1": "安好",
      "slot2": "保重",
      "slot3": "团聚"
    },
    "signature": "男叩上"
  },
  "word_pool": {
    "salutation": ["父母大人膝下", "爹娘亲启"],
    "body_slots": {
      "slot1": ["安好", "安康", "平安", "无事"],
      "slot2": ["勿念", "保重", "加衣", "早归"],
      "slot3": ["回信", "团聚", "归家", "平安"]
    },
    "signature": ["男叩上", "儿拜上"]
  },
  "base_fee": 12,
  "perfect_bonus": 8,
  "feedback": {
    "perfect": "先生写得真好！",
    "normal": "还行吧",
    "wrong": "不对不对"
  }
}
```

### 1. 基本信息字段

| 字段名 | 类型 | 说明 |
| --- | --- | --- |
| `npc_id` | `int` | NPC 的唯一标识符。当前使用负数，基于时间戳与随机数构造，用于当天查询与存档。 |
| `name` | `String` | NPC 名称，由 `FIRST_NAMES` 与 `LAST_NAMES` 拼接，如 `"张大牛"`。 |
| `first_day` | `int` | NPC 最早出现的天数，目前恒为 `1`，为将来解锁式 NPC 留有扩展空间。 |
| `required_calligraphy` | `int` | 要求书法等级，目前恒为 `0`，预留给未来书法系统。 |
| `avatar` | `String` | 头像路径（当前为空字符串，未使用）。 |
| `description` | `String` | NPC 的简短描述，如 `"一位普通的路人"`，可用于角色信息展示。 |
| `letter_type` | `String` | 信件类型，目前为 `"家书"`，未来可扩展为其他类型（如书札、公文等）。 |
| `request_text` | `String` | NPC 的口述需求文本，已将当前 NPC 的正文正确词填入故事模板中，供代写界面展示。 |

### 2. 正确答案字段 `correct`

| 字段名 | 类型 | 说明 |
| --- | --- | --- |
| `correct.salutation` | `String` | 正确称谓，从 `SALUTATION_POOL[relation]` 中随机选取，用于信纸顶部称谓槽位的判定。 |
| `correct.body_slots` | `Dictionary` | 正文三个槽位的正确答案字典，键为 `"slot1"` / `"slot2"` / `"slot3"`。 |
| `correct.body_slots.slot1` | `String` | 第一句 “家中 …” 的正确词，从 `BODY_SLOT1_WORDS` 中选取。 |
| `correct.body_slots.slot2` | `String` | 第二句 “在外 …” 的正确词，从 `BODY_SLOT2_WORDS` 中选取。 |
| `correct.body_slots.slot3` | `String` | 第三句 “盼 …” 的正确词，从 `BODY_SLOT3_WORDS` 中选取。 |
| `correct.signature` | `String` | 正确落款，从 `SIGNATURE_POOL[relation]` 中随机选取，用于信纸底部落款槽位的判定。 |

> `JudgeSystem` 会将 `correct` 与玩家答案逐项比较，以确定每项是否完全正确，并据此统计 `correct_count`。

### 3. 词库字段 `word_pool`

| 字段名 | 类型 | 说明 |
| --- | --- | --- |
| `word_pool.salutation` | `Array[String]` | 当前关系下的称谓候选列表，前端左侧“称谓词库”按钮的来源。 |
| `word_pool.body_slots` | `Dictionary` | 正文三槽位的候选词库字典。 |
| `word_pool.body_slots.slot1` | `Array[String]` | 槽位 1（家中 …）的所有候选词，供 UI 构建按钮与判定格式合法性。 |
| `word_pool.body_slots.slot2` | `Array[String]` | 槽位 2（在外 …）的候选词。 |
| `word_pool.body_slots.slot3` | `Array[String]` | 槽位 3（盼 …）的候选词。 |
| `word_pool.signature` | `Array[String]` | 当前关系下的落款候选列表，前端左侧“落款词库”按钮的来源。 |

> `JudgeSystem` 使用 `word_pool` 检查玩家答案是否在对应词库中，否则视为“格式错误”；`letter.gd` 使用该词库创建可拖拽的词按钮。

### 4. 报酬与反馈字段

| 字段名 | 类型 | 说明 |
| --- | --- | --- |
| `base_fee` | `int` | 完成委托的基础报酬（当无格式错误且存在内容错误时给出）。当前为 12 文。 |
| `perfect_bonus` | `int` | 在 `base_fee` 基础上，五项全对时额外奖励的金额。当前为 8 文。 |
| `feedback.perfect` | `String` | 完美结果 `"PERFECT"` 时显示的 NPC 反馈文本，从 `FEEDBACK_PERFECT` 随机选取。 |
| `feedback.normal` | `String` | 一般结果 `"NORMAL"` 时显示的 NPC 反馈文本，从 `FEEDBACK_NORMAL` 随机选取。 |
| `feedback.wrong` | `String` | 错误结果 `"WRONG"`（存在格式错误）时显示的 NPC 反馈文本，从 `FEEDBACK_WRONG` 随机选取。 |

> 报酬逻辑由 `JudgeSystem` 决定：`base_fee` 与 `perfect_bonus` 决定了 NORMAL 与 PERFECT 结果下的收益上限，而 WRONG 则会根据格式错误数量反向扣费。

