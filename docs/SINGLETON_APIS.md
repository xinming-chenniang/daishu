## PlayerManager.gd API

| 名称 | 类型 | 参数 | 返回值 | 简要说明 |
| --- | --- | --- | --- | --- |
| money_changed | 信号 | new_money: int | - | 金钱变化时发出，传递当前金钱值 |
| day_changed | 信号 | new_day: int | - | 天数变化时发出，传递当前天数 |
| day_ledger_changed | 信号 | - | - | 每日流水变更时发出（新增或重置） |
| STALL_FEE_PER_DAY | 常量 | - | int | 每日固定支出（摊位+房租+米钱等） |
| SAVE_PATH | 常量 | - | String | 存档文件默认路径 `user://save.dat` |
| SAVE_VERSION | 常量 | - | int | **存档格式版本**（当前 1）。改字段语义/结构时必须 +1，并给 `apply_save_data()` 补迁移分支 |
| TOTAL_DAYS | 常量 | - | int | 总天数上限（赶考期限，当前为 10 天） |
| TARGET_MONEY | 常量 | - | int | 目标金额（进京路费，当前为 500 文） |
| completed_npcs | 属性 | - | Array[int] | 当前天已完成的 NPC id 列表 |
| money | 属性 | - | int | 当前金钱；赋值时会触发 `money_changed` 信号 |
| day | 属性 | - | int | 当前天数（第几日）；赋值时会触发 `day_changed` 信号 |
| day_ledger | 属性 | - | Array[Dictionary] | 当日收支流水明细 |
| save_path | 属性 | - | String | **实际读写的存档路径**，默认 `SAVE_PATH`；回归脚本（`tools/verify_save.gd`）改它以免覆盖玩家存档 |
| add_money | 方法 | amount: int | bool | 增加/减少金钱；返回 **true = 这次调用把钱扣成负数**（已请求切到失败结局），调用方应停止后续 UI 操作 |
| next_day | 方法 | - | bool | 天数加一；返回 **true = 已触发结局**（第 10 天之后），调用方应停止后续 UI 操作 |
| is_npc_completed | 方法 | npc_id: int | bool | 判断指定 NPC id 在当前天是否已完成 |
| mark_npc_completed | 方法 | npc_id: int | void | 将指定 NPC 标记为已完成，避免重复接同一委托 |
| reset_completed_npcs | 方法 | - | void | 清空当日已完成 NPC 列表（通常在结束当日时调用） |
| record_entry | 方法 | kind: String, amount: int, desc: String, meta: Dictionary = {} | void | 向每日流水中追加一条收支记录并发出 `day_ledger_changed` |
| get_day_summary | 方法 | - | Dictionary | 汇总当日收入、支出、摊位费和净收益，并返回包含这些字段的字典 |
| apply_end_of_day_costs | 方法 | - | bool | 按 `STALL_FEE_PER_DAY` 扣除固定支出；返回 true = 交完就破产（调用方应立即停止结算流程） |
| reset_day_ledger | 方法 | - | void | 清空当日流水并发出 `day_ledger_changed` 信号 |
| reset | 方法 | - | void | 重置为新游戏状态（钱=100、天数=1，清空完成 NPC 和流水） |
| check_endgame | 方法 | - | void | 根据当前 `money` 与 `TARGET_MONEY` 判定胜负并切换到成功/失败场景 |
| show_success_scene | 方法 | - | void | 切换到胜利结局场景 `success.tscn` |
| show_failure_scene | 方法 | - | void | 切换到失败结局场景 `gameover.tscn` |
| get_save_data | 方法 | - | Dictionary | 序列化当前玩家状态（**version**、钱、天数、完成 NPC、流水）为字典 |
| apply_save_data | 方法 | data: Dictionary | bool | 应用存档；**返回 false = 拒绝加载**（版本比程序新）。旧存档没有 `version` 字段按 1 处理 |
| save_game | 方法 | - | bool | 写入 `save_path`；返回 false = 打不开文件 |
| load_game | 方法 | - | bool | 读取并解析 `save_path`；**返回 false = 没有存档 / JSON 损坏 / 版本过新**。失败时**不改动当前状态** |
| has_save | 方法 | - | bool | 检查存档文件（`save_path`）是否存在 |
| save | 方法 | - | bool | 友好封装，内部调用 `save_game` |
| load | 方法 | - | bool | 友好封装，内部调用 `load_game`；标题界面据此回落"新游戏" |

---

## NPCManager.gd API

| 名称 | 类型 | 参数 | 返回值 | 简要说明 |
| --- | --- | --- | --- | --- |
| current_day_npcs | 属性 | - | Array | 当日生成的 NPC 列表，供 `get_npc_by_id` 查找 |
| FIRST_NAMES | 常量 | - | Array[String] | NPC 名字可选的姓氏列表 |
| LAST_NAMES | 常量 | - | Array[String] | NPC 名字可选的名列表 |
| RELATIONS | 常量 | - | Array[String] | 与收信人的关系枚举（父母、子女等） |
| SALUTATION_POOL | 常量 | - | Dictionary | 按关系划分的称谓候选词库 |
| SIGNATURE_POOL | 常量 | - | Dictionary | 按关系划分的落款候选词库 |
| BODY_SLOT1_WORDS | 常量 | - | Array[String] | 正文第一个槽位（家中…）的候选词列表 |
| BODY_SLOT2_WORDS | 常量 | - | Array[String] | 正文第二个槽位（在外…）的候选词列表 |
| BODY_SLOT3_WORDS | 常量 | - | Array[String] | 正文第三个槽位（盼…）的候选词列表 |
| FEEDBACK_PERFECT | 常量 | - | Array[String] | 完美完成时 NPC 的好评反馈候选文本 |
| FEEDBACK_NORMAL | 常量 | - | Array[String] | 一般完成时 NPC 的普通反馈候选文本 |
| FEEDBACK_WRONG | 常量 | - | Array[String] | 格式或内容出错时 NPC 的负面反馈候选文本 |
| generate_random_npc | 方法 | - | Dictionary | 随机生成一个 NPC，包括姓名、关系、故事文本、正确答案、词库与报酬配置 |
| get_today_npcs | 方法 | _day: int | Array | 生成当日的 NPC 列表（当前固定为 3 个），保存到 `current_day_npcs` 并返回 |
| get_npc_by_id | 方法 | npc_id: int | Dictionary | 在 `current_day_npcs` 中查找指定 id 的 NPC 数据，未找到则返回空字典 |

---

## JudgeSystem.gd API

| 名称 | 类型 | 参数 | 返回值 | 简要说明 |
| --- | --- | --- | --- | --- |
| RESULT_PERFECT | 常量 | - | String | 判定结果常量，表示五项全对的完美结果 `"PERFECT"` |
| RESULT_NORMAL | 常量 | - | String | 判定结果常量，表示格式正确但有内容不匹配 `"NORMAL"` |
| RESULT_WRONG | 常量 | - | String | 判定结果常量，表示存在格式错误 `"WRONG"` |
| judge | 方法 | npc: Dictionary, answers: Dictionary | Dictionary | 对给定 NPC 与玩家答案进行判定，返回报酬、反馈文本、结果码以及每项正确性等信息 |

> 说明：`_check_item` 为内部辅助方法，以 `_` 开头视为私有，未在此表中列出。

---

## AudioManager.gd API

| 名称 | 类型 | 参数 | 返回值 | 简要说明 |
| --- | --- | --- | --- | --- |
| SFX_DIR | 常量 | - | String | 音效目录，`res://assets/audio/sfx/` |
| SFX_NAMES | 常量 | - | Array | 四个音效名：`ui_click` / `paper_drop` / `submit` / `day_end` |
| BASE_DB | 常量 | - | float | 基准音量（−8 dB）；调用方可传偏移量微调 |
| play_sfx | 方法 | sfx_name: String, volume_offset_db: float = 0.0 | void | 播放一个音效；名字不存在或素材缺失时**静默跳过**，不报错 |
| has_sfx | 方法 | sfx_name: String | bool | 该音效是否已成功加载（供探针断言） |
| loaded_sfx | 方法 | - | Array | 已加载的音效名列表 |
| missing_sfx | 方法 | - | Array | 加载失败的音效名列表（缺素材时用来报警） |

> 素材由 `tools/gen_sfx.py` 程序化合成（16-bit 单声道 44.1 kHz，固定随机种子可重跑）；
> 校验脚本 `tools/verify_audio.gd`。

