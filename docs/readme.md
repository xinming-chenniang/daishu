📚 代书项目综合文档（截至2026年9月12日）
本文档汇总了当前项目的核心设计、系统架构、数据格式、场景结构及后续计划，旨在为新参与开发者（或未来的你）提供一份清晰完整的项目蓝图。

一、项目简介
游戏名称：代书（暂名）
一句话概括：像素风、明中期代笔先生模拟器，在《Paper, Please》式的日常劳作中，通过代写书信见证市井悲欢。
核心玩法：玩家扮演贫寒书生，在10天内通过代写书信攒够500文进京路费。每日随机出现3位委托人，玩家需在竖排信纸上拖拽词库中的词语填充称谓、正文三空及落款，提交后由系统判定格式与内容准确度，获得相应报酬。
游戏背景：明朝成化年间，市井生活与赶考压力交织。
当前状态：已完成核心循环、随机NPC生成、判定系统、存档系统、结局触发及基础UI，进入美术素材优化阶段。

二、系统架构概览
游戏基于 Godot 4.x 开发，采用 三个自动加载单例 管理全局状态：

单例	职责
PlayerManager	玩家金钱、天数、当日完成NPC、收支流水、存档、结局判定
NPCManager	当日NPC生成（3个/日）、随机NPC数据构造、NPC查询
JudgeSystem	代写判定：格式/内容错误计数、计费规则、反馈文本生成
其余场景脚本（main.gd、letter.gd 等）通过 get_node("/root/单例名") 访问这些单例，完成界面交互与数据流转。

模块关系图（简化版）：

text
标题菜单 → 剧情说明 → 主界面 → 代写界面 → 判定系统 → 玩家管理 → 结局
详细依赖关系见 ARCHITECTURE_SINGLETONS.md（由Cursor生成）。

三、核心模块API（摘要）
PlayerManager
信号：money_changed, day_changed, day_ledger_changed

常量：STALL_FEE_PER_DAY = 10, TOTAL_DAYS = 10, TARGET_MONEY = 500

核心方法：

add_money(amount)：增减金钱，若结果为负触发失败结局

next_day()：天数+1，超限时检查结局

record_entry(kind, amount, desc, meta)：记录当日流水

save() / load() / has_save()：存档管理

reset()：重置为新游戏

NPCManager
常量：姓名池、关系枚举、称谓/落款/正文词库、反馈语池

核心方法：

generate_random_npc()：生成一个完整的随机NPC字典

get_today_npcs(day)：返回当日3个NPC，奖励随天数递增

get_npc_by_id(id)：在当日列表中查找NPC

JudgeSystem
常量：RESULT_PERFECT, RESULT_GOOD, RESULT_NORMAL, RESULT_WRONG

核心方法：

judge(npc, answers)：根据玩家答案返回判定结果，包含：

fee：本次报酬（可为负）

feedback_text：NPC反馈

result_code：结果类型

correct_answers / item_correct：正确答案及每项对错

完整API列表见 SINGLETON_APIS.md。

四、数据格式说明
存档文件（user://save.dat）
json
{
  "money": 120,
  "day": 3,
  "completed_npcs": [-123456, -123789],
  "day_ledger": [{"kind": "commission", "amount": 20, "desc": "张大牛 委托结算", "meta": {...}}]
}
completed_npcs：当日已完成委托的NPC ID（随机NPC为负值）

day_ledger：收支流水，用于结算界面展示

随机NPC数据格式
NPC字典包含：

npc_id：负数唯一ID

name：随机姓名

request_text：口述文本（已嵌入正确答案）

correct：正确答案（称谓、正文三空、落款）

word_pool：词库（称谓、正文三槽候选、落款）

base_fee / perfect_bonus：报酬（基准 12 文 / 8 文，随天数递增）

feedback：四种结果的反馈文本（perfect / good / normal / wrong）

详细字段说明见 DATA_FORMATS.md 及 NPC_GENERATION.md。

五、场景结构与界面逻辑
场景文件	功能
title_screen.tscn	启动菜单（新游戏/继续/退出）
prologue.tscn	剧情说明（10天500文）
main.tscn	主界面：金钱/天数显示、NPC列表、开始/结束今日、保存并退出
letter.tscn	代写界面：左侧词库按钮（可拖拽），右侧竖排信纸槽位，提交/重置/返回
success.tscn / gameover.tscn	结局界面（共用 EndGameScreen.gd）
关键界面协作：

main.gd 监听 PlayerManager 信号实时更新UI。

点击NPC按钮 → 实例化 letter.tscn，调用 init_with_npc(id) 传入数据。

letter.gd 根据 word_pool 动态生成可拖拽按钮，拖拽后更新 player_answers。

提交 → 调用 JudgeSystem.judge → 弹窗显示结果 → 确认后调用 PlayerManager.record_entry 和 add_money → 返回主界面并标记NPC完成。

结束今日 → 弹出结算汇总 → 确认后扣除固定支出、天数+1、重置当日状态。

各场景节点树及信号连接详见 SCENE_OVERVIEW.md。

六、核心机制详述
随机NPC生成规则
姓名：从 FIRST_NAMES + LAST_NAMES 随机组合。

关系：从 ["父母","子女","夫妻","兄弟","朋友"] 随机选取。

称谓/落款：根据关系从对应词库中随机选一项作为正确答案，整个词库作为 word_pool。

正文三空：按信型从 BODY_POOLS[信型] 的 slot1/2/3 各随机选一词作为正确答案，该信型的整个词库作为候选。

反馈：从四个反馈池各随机选一条。

报酬随天数递增：base_fee = 12 + (day-1)/3，perfect_bonus = 8 + (day-1)。

生成算法伪代码见 NPC_GENERATION.md。

判定规则
格式错误：答案为空或不在对应 word_pool 中 → 每项扣2文，结果码 WRONG。

内容错误：答案在词库中但与 correct 不符 → 得 60% 基础报酬，结果码 NORMAL。

优良：五项中四对 → 基础报酬 + 70% 完美加成，结果码 GOOD。

完美：五项全对 → 基础+完美加成，结果码 PERFECT。

判定同时返回正确答案字典及每项对错布尔值，供UI高亮。

详细逻辑及代码示例见 JUDGE_SYSTEM_LOGIC.md。

七、开发状态总结
✅ 已完成
启动菜单、剧情说明、主界面、代写界面、结局界面

随机NPC生成系统（五种信型：家书/请安/贺寿/诉苦/求荐）

判定系统（格式/内容/计费/反馈）

每日结算（固定支出、天数推进、流水记录）

存档系统（保存/加载/重置）

结局触发（10天后金钱≥500则胜利，否则失败）

🟡 待办与优化
美术素材（**2026-10 更新：底图 / NPC 头像 / 结局图已替换为生成图，水印已清；下面几条是原始计划，仍缺的只剩毛笔光标与书法字库**）：

毛笔光标动画（AI生成帧序列 + Godot实现实时墨迹）

信纸背景（AI生成宣纸纹理）

书法字库（AI生成常用词PNG）

NPC头像（AI生成系列头像）

平衡性调整：验证10天500文是否合理，可调整报酬或支出。

扩展玩法：读书/练字系统、暗语/江湖声望、更多文书类型（契约、情书、讼状）。

剧情深度：加入固定NPC及连续支线故事。

音效与音乐：购买或制作书写声、铜钱声、背景音乐。

八、后续开发建议
立即启动美术素材生成（参考之前讨论的本地AI方案）：

用万象熔炉或Z-Image生成信纸背景、毛笔光标帧、书法字PNG。

建立资产清单，按优先级分批替换占位图。

邀请测试：让朋友试玩，收集反馈，调整数值和UI易用性。

逐步实现扩展系统：可先实现“练字”系统（解锁高级委托），丰富成长感。

持续更新文档：随着代码变化同步更新上述文档，特别是新增功能需补充说明。
