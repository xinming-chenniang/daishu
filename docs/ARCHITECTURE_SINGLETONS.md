## 自动加载单例与模块关系总览

本项目使用 Godot 4 的 **自动加载单例（Autoload）** 管理核心游戏状态与逻辑，主要有三个：

- `PlayerManager`：玩家状态与经济系统
- `NPCManager`：当天 NPC 生成与查询
- `JudgeSystem`：代写判定与计费

另有 **三个不承载游戏状态的辅助单例**（同样在 `project.godot` 的 `[autoload]` 里）：

- `FontFallback`：启动时给全局主题字体挂系统字体兜底（`Font.fallbacks` 存不进 `.tres`，只能运行时挂）
- `AudioManager`：全局音频（4 个音效 + 2 条 BGM + 静音；切场景不截断、BGM 跨场景延续）
- `CursorManager`：启动时设一次毛笔系统光标（全局状态，跨场景不重置）

> 调用方写 `get_node_or_null("/root/AudioManager")` 而不是裸全局名 `AudioManager` ——
> `--script` 模式不注册 autoload，裸名会让 `tools/verify_*.gd` 报 `Identifier not found`（假阳性）。

围绕这三个单例，前端场景脚本（`title_screen.gd`、`prologue.gd`、`main.gd`、`letter.gd`、`EndGameScreen.gd` 等）组成了一条从“标题 → 主界面 → 代写 → 结算 → 结局”的完整数据流。

### 模块关系图（Mermaid）

```mermaid
graph TD
    %% 单例
    PlayerManager[PlayerManager\n(玩家与经济)]
    NPCManager[NPCManager\n(NPC/委托生成)]
    JudgeSystem[JudgeSystem\n(判定系统)]

    %% 场景 / UI
    Title[title_screen.gd\n标题菜单]
    Prologue[prologue.gd\n剧情说明]
    Main[main.gd\n主界面]
    Letter[letter.gd\n代写信纸]
    EndGame[EndGameScreen.gd\n结局界面]

    %% 入口与流程
    Title -->|开始游戏: reset/save| PlayerManager
    Title -->|开始游戏: 切场景| Prologue
    Title -->|继续游戏: has_save/load| PlayerManager
    Title -->|继续游戏: 切场景| Main

    Prologue -->|确认: 切场景| Main

    Main -->|监听 money_changed/day_changed| PlayerManager
    Main -->|显示 金钱/天数/目标| PlayerManager
    Main -->|开始今日: get_today_npcs(day)| NPCManager
    Main -->|生成按钮 & 过滤已完成| PlayerManager
    Main -->|点击 NPC: init_with_npc(id)| Letter

    Letter -->|获取 NPC 数据: get_npc_by_id| NPCManager
    Letter -->|提交: judge(npc, answers)| JudgeSystem
    JudgeSystem -->|返回 判定结果+fee| Letter
    Letter -->|record_entry/add_money| PlayerManager
    Letter -->|完成后回主界面\non_npc_completed| Main

    Main -->|结束今日: get_day_summary| PlayerManager
    Main -->|确认结算: apply_end_of_day_costs\n+ next_day + reset_day_ledger\n+ reset_completed_npcs| PlayerManager

    PlayerManager -->|day > TOTAL_DAYS\n或 money < 0| EndGame
    EndGame -->|重玩: reset + 回标题| PlayerManager
    EndGame -->|退出游戏| Title
```

---

## 单例职责与接口

### PlayerManager.gd —— 玩家状态与时间/经济系统

**角色**：全局唯一的“玩家管理器”，负责：

- 玩家基础状态：
  - `money`：当前金钱，带 `money_changed` 信号。
  - `day`：当前天数（第几日），带 `day_changed` 信号。
  - `completed_npcs`：当日已完成的 NPC id 列表。
  - `day_ledger`：当日收支明细（`record_entry()` 记录）。
- 经济与时间推进：
  - `add_money(amount)`：修改金钱；若结果 `< 0`，立即触发失败结局。
  - `get_day_summary()`：汇总当日收入、支出、摊位/房租成本和净收益。
  - `apply_end_of_day_costs()`：每天结束时扣除固定支出（`STALL_FEE_PER_DAY`）。
  - `next_day()`：天数 +1，若 `day > TOTAL_DAYS`，调用 `check_endgame()`。
- 结局判定：
  - 常量：`TOTAL_DAYS = 10`、`TARGET_MONEY = 500`。
  - `check_endgame()`：
    - 若 `money >= TARGET_MONEY` 且 `money >= 0` → `show_success_scene()`。
    - 否则 → `show_failure_scene()`。
  - `show_success_scene()` / `show_failure_scene()`：切到 `success.tscn` / `gameover.tscn`，由 `EndGameScreen` 负责后续交互。
- 存档系统：
  - `get_save_data()` / `apply_save_data(data)`：序列化/恢复 `money`、`day`、`completed_npcs`、`day_ledger`。
  - `save_game()` / `load_game()`：读写 `user://save.dat`。
  - 对外友好接口：`save()`、`load()`、`has_save()`。
- 重置：
  - `reset()`：重置为新游戏状态（金钱=100、day=1、清空完成 NPC 和流水）。
  - `reset_completed_npcs()`、`reset_day_ledger()`：用于每日结束后的刷新。

**被谁调用？**

- `title_screen.gd`：
  - 新游戏：`PlayerManager.reset()` → `PlayerManager.save()`。
  - 继续：`PlayerManager.has_save()` + `PlayerManager.load()`。
- `main.gd`：
  - 监听 `money_changed`、`day_changed` 刷新 UI。
  - 显示：`PlayerManager.money`、`PlayerManager.day`、`PlayerManager.TOTAL_DAYS`。
  - 每日结束弹窗：`get_day_summary()`。
  - 确认结算：`apply_end_of_day_costs()`、`next_day()`、`reset_day_ledger()`、`reset_completed_npcs()`。
  - 存档退出：`save()`。
- `letter.gd`：
  - 结算时：`record_entry("commission", fee, desc, meta)`，再 `add_money(fee)`。
- `EndGameScreen.gd`：
  - “重玩”：`reset()` 后回标题。

---

### NPCManager.gd —— 当日 NPC 与委托生成

**角色**：负责“今天有哪些 NPC”、“每个 NPC 的词库与正确答案是什么”。

- 状态：
  - `current_day_npcs: Array`：当前天随机生成的 NPC 列表，供 `get_npc_by_id` 使用。
- 配置常量：
  - 姓名、关系枚举：`FIRST_NAMES`、`LAST_NAMES`、`RELATIONS`。
  - 称谓/落款词库：`SALUTATION_POOL`、`SIGNATURE_POOL`（按关系分类）。
  - 正文三个槽位可选词：`BODY_SLOT1_WORDS`、`BODY_SLOT2_WORDS`、`BODY_SLOT3_WORDS`。
  - 反馈语：`FEEDBACK_PERFECT`、`FEEDBACK_NORMAL`、`FEEDBACK_WRONG`。
- 核心方法：
  - `generate_random_npc() -> Dictionary`：
    - 随机生成一个 NPC：
      - `npc_id`（负数，用时间戳+随机数构造）。
      - `name`、`relation`。
      - 文本故事 `request_text`，将随机选出的正文正确词 `slot1/2/3` 格式化进模板中。
      - `correct`：包含 `salutation`、`body_slots.slot1/2/3`、`signature`。
      - `word_pool`：前端 UI 用来生成左侧词库；JudgeSystem 用来校验答案是否合法。
      - 报酬：`base_fee = 12`、`perfect_bonus = 8`。
  - `get_today_npcs(day) -> Array`：
    - 当前实现中忽略 `day`，每次生成 3 个随机 NPC，保存到 `current_day_npcs` 并返回。
  - `get_npc_by_id(npc_id) -> Dictionary`：
    - 在 `current_day_npcs` 中查找对应 id，用于 `letter.gd` 初始化。

**被谁调用？**

- `main.gd`：
  - `_on_start_day_pressed()`：`get_node("/root/NPCManager")` 取单例，调用 `get_today_npcs(PlayerManager.day)`，然后渲染 NPC 列表按钮。
- `letter.gd`：
  - `init_with_npc(npc_id)`：通过 `get_node("/root/NPCManager")` 调用 `get_npc_by_id()`，拿到当前 NPC 的完整数据（story/word_pool/correct 等）。

---

### JudgeSystem.gd —— 判定与计费规则

**角色**：根据 NPC 的 `correct` 配置和玩家答案 `answers`，判断对错、计算报酬/惩罚，并生成反馈。

- 内部状态结构：
  - `_check_item()` 累积：
    - `format_errors`：为空或答案不在词库内的次数。
    - `content_mismatch`：格式正确但内容不等于正确答案的次数。
    - `correct_count`：完全正确的项数（总共 5 项：称谓+3 正文+落款）。
- 核心方法：
  - `_check_item(safe_answers, word_pool, answer_key, pool_key, correct_value, state)`：
    - 空或不在对应词库（正文三槽用 `word_pool.body_slots.slot1/2/3`，称谓/落款用顶层词库） → 记为 `format_errors`。
    - 在词库内但不等于 `correct_value` → `content_mismatch`。
    - 完全匹配 → `correct_count`。
  - `judge(npc, answers) -> Dictionary`：
    - 从 `npc` 中读取：
      - `word_pool`（校验合法词）。
      - `correct`（正确答案）。
      - 报酬配置：`base_fee`、`perfect_bonus`。
      - 反馈文本 `feedback.normal/perfect/wrong`。
    - 对 5 项依次 `_check_item()` 后，根据统计结果：
      - `format_errors > 0`：结果 `WRONG`，报酬 `fee = -2 * format_errors`（按格式错误次数扣钱），反馈 `feedback.wrong`。
      - 否则如有 `content_mismatch > 0`：结果 `NORMAL`，`fee = base_fee`，反馈 `feedback.normal`。
      - 否则 5 项全对：结果 `PERFECT`，`fee = base_fee + perfect_bonus`，反馈 `feedback.perfect`。
    - 额外返回：
      - `correct_answers`：五项的正确答案（供界面显示和高亮）。
      - `item_correct`：每项答案是否完全正确（布尔字典）。

**被谁调用？**

- `letter.gd`：
  - `_on_submit_pressed()`：调用 `JudgeSystem.judge(current_npc, player_answers)`，拿到 `fee`、`feedback_text`、正确答案等，用于：
    - 构造结算弹窗文本；
    - 决定传给 `PlayerManager` 的金额变动。

---

## 关键数据流向

### 1. 启动与存档加载

1. 玩家启动游戏 → `title_screen.tscn`：
   - 若点“继续游戏”：`PlayerManager.has_save()` 检查 `user://save.dat` → `PlayerManager.load()` 恢复 `money/day/completed_npcs/day_ledger`，然后切到 `main.tscn`。
   - 若点“开始游戏”：`PlayerManager.reset()` 初始化状态 → `PlayerManager.save()` 存一份初始档 → 切到 `prologue.tscn`（剧情说明） → 再由 `prologue.gd` 切到 `main.tscn`。

### 2. 主界面与每日 NPC 流程

1. `main.gd` `_ready()`：
   - 监听 `PlayerManager.money_changed`、`day_changed`，随时刷新“铜钱/日数”显示。
   - 初始化 UI（调用 `update_ui()` 和 `clear_npc_list()`）。
2. 点击“开始今日”：
   - `main.gd` 通过 `get_node("/root/NPCManager")` 取得单例，调用 `get_today_npcs(PlayerManager.day)` 生成今天的 3 个 NPC。
   - 遍历结果，为每个未完成 NPC 创建一个按钮；按钮 meta 中记录 `npc_id`，用于后续打开代写界面。

### 3. 代写信纸与判定

1. 在主界面点击某个 NPC 按钮：
   - `main.gd`：
     - `preload("res://scenes/letter.tscn")` 实例化代写界面。
     - 调用 `letter_instance.init_with_npc(int(npc_id))`。
     - 把 `Letter` 加到 `SceneTree.root` 下，并 `hide()` 掉 `Main`。
2. `letter.gd.init_with_npc(npc_id)`：
   - 通过 `get_node("/root/NPCManager")` 拿到 `NPCManager`，调用 `get_npc_by_id(npc_id)` 拿到这位 NPC 的完整数据：
     - `request_text`：设置到 `RequestLabel`（被 `_to_vertical()` 处理成竖排）。
     - `word_pool`：用于构建左侧词库按钮（称谓/正文/落款）。
     - `correct`：用于后续判定（内部只传回给 `JudgeSystem`）。
   - 调用 `_build_word_pools()` 创建可拖拽的 `word_button`（按钮脚本 `word_button.gd`）。
   - 调用 `reset_answers()` 清空信纸槽位和 `player_answers`。
3. 玩家拖拽词语到信纸槽位：
   - 左侧 `word_button.gd` 在 `_get_drag_data()` 里打包 `{ type="word", word, category, body_slot }`。
   - 右侧槽位 `letter_slot.gd`：
     - `_can_drop_data()` 校验 `category` 和 `body_slot` 是否匹配。
     - `_drop_data()` 将拖来的 `word` 竖排显示，并发出 `word_dropped(slot_key, word)` 信号。
   - `letter.gd` 在 `_ready()` 中监听五个槽位的 `word_dropped`，在 `_on_slot_word_dropped()` 里同步更新 `player_answers`（`salutation/body_slot1/2/3/signature`）。
4. 点击“提交”：
   - `letter.gd._on_submit_pressed()`：
     - 调用 `JudgeSystem.judge(current_npc, player_answers)` 得到：
       - `fee`：本次任务的收入（或扣款）。
       - `feedback_text`：NPC 反馈。
       - `correct_answers`：五项正确答案。
       - `item_correct`：每项是否答对。
     - 构造结算文案（收入/扣钱 + NPC 反馈 + 高亮正确答案），显示在 `ResultPopup` 中。

### 4. 结算与记账

1. 玩家在结算弹窗点“确认”：
   - `letter.gd._on_result_popup_confirmed()`：
     - 读取 `_pending_result.fee` 与当前 `NPC` 名字。
     - 调用 `PlayerManager.record_entry("commission", fee, desc, meta)` 记入当日流水。
     - 调用 `PlayerManager.add_money(fee)` 更新金钱：
       - 若更新后 `money < 0`，会触发 `PlayerManager.show_failure_scene()`，直接进入失败结局。
     - 调用 `return_to_main()`：
       - 通过 `get_tree().root.get_node_or_null("Main")` 找回主界面。
       - 若存在 `on_npc_completed`，则告知该 NPC 已完成，主界面会从列表中移除对应按钮。
       - 刷新主界面 UI 后销毁 `Letter` 场景。

### 5. 每日结束与天数推进

1. 在主界面点击“结束今日”：
   - `main.gd._on_end_day_pressed()`：
     - 通过 `PlayerManager.get_day_summary()` 生成当日收入/支出/净收益说明。
     - 显示在 `EndDayPopup` 弹窗中。
2. 弹窗中点击“确认”：
   - `main.gd._on_end_day_popup_confirmed()`：
     - 调用 `PlayerManager.apply_end_of_day_costs()`：扣除固定支出。
     - 调用 `PlayerManager.next_day()`：天数 +1，若超出 `TOTAL_DAYS`（10 天），触发 `check_endgame()`：
       - 若 `money >= TARGET_MONEY` 且为非负 → 胜利结局；
       - 否则 → 失败结局。
     - 重置 `day_ledger` 与 `completed_npcs`，清空 NPC 列表，并刷新 UI。

### 6. 结局与重玩

1. `PlayerManager.show_success_scene()` / `show_failure_scene()` 切到：
   - `success.tscn` 或 `gameover.tscn`（两者共用 `EndGameScreen.gd` 脚本，通过导出的 `is_success` 区分）。
2. `EndGameScreen.gd`：
   - `_ready()` 根据 `is_success` 设置不同文案。
   - “重玩”按钮：`PlayerManager.reset()` → 切回 `title_screen.tscn`。
   - “退出游戏”按钮：`get_tree().quit()`。

---

## 非自动加载模块间调用说明

项目中除了三个自动加载单例外，其余脚本都按场景挂载，不通过 Autoload：

- `title_screen.gd`：挂在 `title_screen.tscn` 根节点 `TitleScreen` 上，通过直接调用 `PlayerManager` 控制新游戏/续档。
- `prologue.gd`：挂在 `prologue.tscn`，只负责按钮切场景，不直接使用任何单例。
- `main.gd`：挂在 `main.tscn` 根节点 `Main`，通过：
  - `get_node("/root/NPCManager")` 调用单例；
  - 直接访问 `PlayerManager` 接口。
- `letter.gd`：挂在 `letter.tscn` 根节点 `Letter`，通过：
  - `get_node("/root/NPCManager")` 获取 NPC 数据；
  - `JudgeSystem.judge()` 进行判定；
  - `PlayerManager.record_entry()`、`add_money()` 更新经济。
- `letter_slot.gd`、`word_button.gd`：作为通用 UI 控件脚本，被 `letter.tscn` 组合使用，不直接依赖单例。
- `EndGameScreen.gd`：挂在 `success.tscn`、`gameover.tscn`，通过 `PlayerManager.reset()` 重置并回标题。

**未通过自动加载但存在的模块间调用：**

- `main.gd` 通过普通场景路径 `preload("res://scenes/letter.tscn")` 实例化 `Letter` 场景，并直接调用其实例方法 `init_with_npc(id)`。这是典型的场景间协作，不走 Autoload。
- `EndGameScreen.gd`、`prologue.gd` 和 `title_screen.gd` 之间通过 `get_tree().change_scene_to_file()` 进行场景切换，这同样是常规场景导航，而非单例调用。

整体来看，**所有跨模块的全局状态共享均集中在三个 Autoload 单例上（PlayerManager / NPCManager / JudgeSystem）**，其它模块间相互作用主要是：

- 通过场景实例调用（`letter_instance.init_with_npc()`）；
- 通过 `SceneTree` 切换场景（`change_scene_to_file()`），没有引入额外的全局单例。

