# 代书（Daishu）

> **明中期 · 代笔先生模拟器**
> 你是个穷书生，要在 **10 天**里靠替人代写书信攒够 **500 文**进京赶考。
> 《Paper, Please》式的文书劳作 —— 只是这回，文书得你自己写出来。

---

## 这是什么游戏

明朝成化年间，你在市井摆了个代书摊。每天来三位委托人：想让远方的儿子回家的老妇、要给恩师贺寿的学徒、不好意思自己开口诉苦的妇人……他们不识字，你说他们写。

你要做的不是判断别人写的对不对，而是**亲手把信组装出来**：

- 从词库里挑**称谓**（爹娘 / 恩师 / 贤弟……）
- 按信型填**正文三个空**（家书 / 请安 / 贺寿 / 诉苦 / 求荐，各有专属词库）
- 落下**署名与敬语**

竖排信纸上，填错格式要扣钱，填错内容只拿六成，全对才有满额与加成。

> 当天结算要扣 10 文摊位费。钱变成负数，游戏立刻结束。

## 现在能玩到什么程度

**可玩纵向切片（playable alpha）** —— 核心循环端到端跑通：

```
标题存档 → 序章 → 每日 3 位委托人 → 拖拽代写 → 四档判定计费
        → 当日结算 → 10 天结局（≥500 文成功 / 否则失败）
```

已完成：随机 NPC 生成、五信型词库、四档判定、每日结算与流水、存档读档（带版本号与坏档拒绝）、双结局、
全局 UI 主题（中文字体 + 按钮九宫格）、三张主界底图去水印、结局/序章背景、NPC 关系肖像、
**4 个 UI 音效 + 2 条循环 BGM**（`AudioManager`，标题页右下角可静音）。

**仍缺**：标题书法大字、首个 Release。
剩下多是"加东西"的工作，逐项清单见 [`docs/PRE_RELEASE_UI_CHECK.md`](docs/PRE_RELEASE_UI_CHECK.md)。

美术与提示词见 [`docs/ART_PLAN.md`](docs/ART_PLAN.md)，开发路线见 [`docs/DEV_PLAN.md`](docs/DEV_PLAN.md)。

## 核心机制

**四档判定**（`JudgeSystem`）：

| 结果 | 条件 | 报酬 |
|---|---|---|
| 完美 PERFECT | 五项全对 | 基础报酬 + 完美加成 |
| 优良 GOOD | 五项中四对 | 基础报酬 + 70% 加成 |
| 一般 NORMAL | 用词在词库内但与正确答案不符 | 60% 基础报酬 |
| 格式错误 WRONG | 留空、或用了词库以外的词 | 每项扣 2 文 |

**难度随天数上升**：`base_fee = 12 + (day-1)/3`，`perfect_bonus = 8 + (day-1)`。

详细规则见 [`docs/JUDGE_SYSTEM_LOGIC.md`](docs/JUDGE_SYSTEM_LOGIC.md) 与 [`docs/NPC_GENERATION.md`](docs/NPC_GENERATION.md)。

## 怎么跑起来

需要 **Godot 4.6**。

```bash
git clone git@github.com:284022719/daishu.git
cd daishu
godot --path . # 或用 Godot 编辑器打开本目录，F5 运行
```

> **Windows 可执行版**：本地已能通过 `export_presets.cfg` 的 `Windows Desktop` 预设导出（`daishu.exe` + `daishu.pck`）。**首个 Release 尚未发布** —— 等美术替换完成、画面能见人了再发。

## 项目结构

```
daishu/
├─ project.godot          Godot 4.6 工程；主场景 scenes/title_screen.tscn
├─ scenes/                6 个场景：标题 / 序章 / 主界面 / 信纸 / 成功 / 失败
├─ scripts/               GDScript；七个全局单例 + 各场景脚本
│   ├─ PlayerManager.gd   金钱、天数、流水、存档、结局判定
│   ├─ NPCManager.gd      每日 3 位委托人、随机 NPC 构造、词库
│   ├─ JudgeSystem.gd     代写判定、计费规则、反馈文本
│   ├─ AudioManager.gd    音效 + BGM + 静音（素材由 tools/gen_sfx.py、gen_bgm.py 合成）
│   ├─ CursorManager.gd   毛笔系统光标（素材由 tools/gen_cursor.py 生成）
│   ├─ SceneFx.gd         动效开关（截图/验证模式下自动关闭）
│   └─ FontFallback.gd    运行时给主题字体挂系统字体兜底
├─ data/                  美术生成提示词（art_prompts_round1/2.json）
├─ docs/                  32 篇设计与实现文档
├─ tools/                 资产校验、数值模拟、环境复现脚本
└─ assets/                字体与图片（字体为免费商用授权）
```

架构与单例 API 见 [`docs/ARCHITECTURE_SINGLETONS.md`](docs/ARCHITECTURE_SINGLETONS.md)、[`docs/SINGLETON_APIS.md`](docs/SINGLETON_APIS.md)。

## 文档

| 文档 | 内容 |
|---|---|
| [`docs/项目总览.md`](docs/项目总览.md) | **交接摘要**：现状、历程、怎么跑、怎么验、踩坑、下一步 |
| [`docs/readme.md`](docs/readme.md) | 项目蓝图总览（系统架构、数据格式、核心机制） |
| [`docs/DEV_PLAN.md`](docs/DEV_PLAN.md) | 开发计划与当前基线 |
| [`docs/SCENE_OVERVIEW.md`](docs/SCENE_OVERVIEW.md) | 各场景节点树与信号连接 |
| [`docs/JUDGE_SYSTEM_LOGIC.md`](docs/JUDGE_SYSTEM_LOGIC.md) | 判定逻辑详述 |
| [`docs/NPC_GENERATION.md`](docs/NPC_GENERATION.md) | 随机 NPC 生成规则 |
| [`docs/DATA_FORMATS.md`](docs/DATA_FORMATS.md) | 存档与 NPC 数据结构 |
| [`docs/ART_PLAN.md`](docs/ART_PLAN.md) | 美术方向、色板、资产清单与水印实测 |
| [`docs/PRE_RELEASE_UI_CHECK.md`](docs/PRE_RELEASE_UI_CHECK.md) | 发布前界面诊断：资产缺口与必须替换的清单 |
| [`docs/BALANCE_REPORT.md`](docs/BALANCE_REPORT.md) | 数值平衡蒙特卡洛模拟报告 |
| [`docs/AI_PLAYBOOK.md`](docs/AI_PLAYBOOK.md) | AI 协作流程与工具链说明 |

## 关于字体

信纸上的称谓 / 正文 / 落款使用 **寒蝉龙藏体**（毛笔书法）。该字体个人与企业均可免费商用，授权声明见 [`assets/fonts/寒蝉字体授权说明.txt`](assets/fonts/寒蝉字体授权说明.txt)。

## 开发方式

本项目在 AI 编程助手（Cursor / Claude / DeepSeek Harness）协作下开发，人负责玩法设计、内容、数值判断与验收，AI 负责实现。协作规范与踩坑记录沉淀在 [`docs/AI_PLAYBOOK.md`](docs/AI_PLAYBOOK.md)。
