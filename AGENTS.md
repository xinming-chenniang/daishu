# 《代书》(Daishu) —— 工作区规则与项目约定

> **这是本项目所有规则的唯一入口。** 在本目录下工作时，先读本文件。
>
> - 跨工作区的通用约定在 `~\.dsh\AGENTS.md`，本文件在其后生效、**优先级更高**。
> - 本文件由工作区的 `AGENTS.md` + 原 `CLAUDE.md` **合并而成（2026-10-12）**；
>   此后 `CLAUDE.md` **已删除**（不再使用 Claude Code），**规则只在本文件维护**。
>   合并前的原文可从 git 取回：`git show b2a1095:CLAUDE.md`。
> - 冲突裁决：本文件内部前后矛盾 → 以**后写的**为准；与 `docs\` 下的设计文档冲突 → 以**有实测依据的**为准；
>   若两者都无实测，**先跑一次验证再下结论**（见第 8 节）。

---

## 1. 技能与查证（写代码前）

- **写或审 GDScript / 场景 / 节点 / 信号 / 资源前，先走 `godot-docs` 技能。**
  本地 Godot 4.6 语料（类参考 1066 篇 + 教程）是**第一依据**，不要凭记忆写 API。
- **断言 API 必须给出处**：`godot-docs\classes\class_xxx.rst` + 行号。**查不到就直说"文档里没有"**，
  不要用回忆补全签名（本会话实测踩过：`Image.resize` 我以为是返回 `Error`，实际是 `void`）。
- 语料在 `godot-docs\`（已 gitignore，36 MB）。**它是 `blob:none` 部分克隆**：本地没有 blob 对象，
  `git status` / `checkout` 会去 gitcode.com 取 blob 而本机代理拦 403。**只能当只读文本语料用。**
- 技能判据的**源**是 `docs\AI_PLAYBOOK.md`（受 git 控制）；DSH 实际读的是镜像
  `~\.dsh\skills\godot-docs\SKILL.md`（**在任何 git 仓库之外，换机器会丢**）。
  **改完 playbook 必须同步**：
  ```powershell
  pwsh -File tools\sync-ai-playbook.ps1          # 源 → 镜像
  pwsh -File tools\sync-ai-playbook.ps1 -Check   # 只查漂移，退出码 1 = 不同步
  ```

## 2. 项目是什么

**《代书》** —— 明中期代笔先生模拟器。穷书生 **10 天**内替人代写书信攒 **500 文**进京赶考。
玩法是《Paper, Please》式文书劳作，但反过来：**不是检查别人的文书，而是自己把信组装出来**
（选称谓 → 按信型填正文三空 → 落款署名）。

- **引擎**：Godot **4.6**（本机 4.6.1-stable **mono**），**纯 GDScript**（未用 C#）
- **渲染器**：GL Compatibility（`gl_compatibility`）
- **入口场景**：`res://scenes/title_screen.tscn`
- **视口**：1152×648，**已在 `project.godot` 显式写死**（信纸槽位对齐依赖它，别改）
- **状态**：可玩纵向切片（playable alpha）。现状与剩余项见 `docs\PRE_RELEASE_UI_CHECK.md`
  （**唯一权威进度表**）与 `docs\项目总览.md`（交接摘要）。

## 3. 怎么跑、怎么验

⚠️ **`godot` 不在 PATH，且路径因机器而异**（家机在 `D:\Program Files\Godot_v4.6.1-stable_mono_win64\`，
别的机器可能装在任意位置或还没装）。**不要把路径抄进文档或脚本** —— 先让脚本解析：

```powershell
pwsh -File tools\where-godot.ps1             # 打印可直接粘贴的 $godot / $proj 两行
pwsh -File tools\where-godot.ps1 -Json       # 给其他脚本消费
```

脚本依次查 `-GodotPath` → `$env:GODOT_PATH` → PATH → **工作区 `tools\godot\`** → 仓库 `vendor\godot\`
→ 常见安装位置，并且**只认 `*_console.exe`**（非 console 版在 stdout 被重定向时输出 0 字节，
会静默破坏截图/验证/MCP）。找不到时退出码 1，并打印下载地址与解压位置。

`$proj` 永远是**仓库根**（含 `project.godot` 的那层），所以在仓库根直接 `--path .` 等价：

```powershell
& $godot --path .                                 # 跑游戏
& $godot --headless --path . --import             # 新增/改动资源后必须导入
& $godot --headless --path . --script res://tools/verify_drop.gd
```

> 本机（无 D 盘、PowerShell 是 5.1）实测：引擎解压在 `<工作区>\tools\godot\` 即可被自动发现；
> 脚本带 UTF-8 **BOM** 才能在 5.1 下正确读中文注释（无 BOM 的 UTF-8 会被按 GBK 解码而报语法错）。

**用编辑器跑**：**双击 `tools\open-editor.cmd`**（或 `pwsh -File tools\run-godot.ps1 -Editor`），
在打开的编辑器里按 **F5**。**不要直接双击引擎 exe** —— 见下面这条本机坑。

纯 GDScript 是运行时解释的，**没有构建步骤**；项目**没有 CI、没有测试套件、没有 lint**
—— 所以第 3 节那些 `tools\` 下的验证脚本就是本项目的事实标准，别指望别的闸门。

> ⚠️ **本机硬坑（2026-10-18 实测，影响"能不能跑起来"）**：直接启动 Godot（双击 exe、
> 或用真实 `%APPDATA%` 跑）会在**加载项目之前**崩溃：日志先是
> `Could not create directory: 'user://logs'`，随后 `CrashHandlerException: signal 11`。
> **游戏和编辑器都受影响**。把 `APPDATA` / `LOCALAPPDATA` 指到可写目录后一切正常
> （`run-godot.ps1` 就是干这个的，重定向到 `<工作区>\.godot-userdata`）。
> 实测对照：真实 AppData → `exit=-1073741819`；重定向后 → `exit=0`，编辑器窗口正常打开。
> 具体原因未查明（同目录下 `cmd mkdir` 是成功的），**只把现象与解法记在这里**。
>
> ```powershell
> tools\open-editor.cmd                                   # 双击/命令行都行：开编辑器
> pwsh -File tools\run-godot.ps1 --path .                 # 直接跑游戏（不经过编辑器）
> ```

**改完必须跑验证脚本**（比肉眼看截图可靠）：

| 命令 | 验什么 | 期望 |
|---|---|---|
| `--script res://tools/verify_drop.gd` | 五槽落词 + 拖拽预览 + 判定 | `总体: PASS` |
| `--script res://tools/verify_theme.gd` | 全局 Theme 三查（设置项→资源→控件实际取值）| `结论: PASS` |
| `--script res://tools/verify_avatar.gd` | 头像关系映射 + 缺字段不崩 | `结论: PASS` |
| `--script res://tools/verify_flow.gd` | 代写→结算→回主界面的状态机（返回不提交、重复结算、破产/第 10 天早退）| `结论: PASS` |
| `--script res://tools/verify_audio.gd` | 4 个音效 + 2 条 BGM 加载/播放、静音开关生效并持久化 | `结论: PASS` |
| `--script res://tools/verify_judge.gd` | 四档判定与优先级（留空/词库外词 → WRONG，不叠加底薪）| `结论: PASS` |
| `--script res://tools/verify_save.gd` | 存读档往返 / 坏档 / 版本过新 / 旧档兼容 | `结论: PASS` |
| `--script res://tools/verify_cursor.gd` | 毛笔光标素材（尺寸/透明底/热点）+ 设置调用不报错 | `结论: PASS` |
| `--script res://tools/verify_content.gd` | NPC 数据不变量（正解⊆词库、同槽无重复、故事含正解、报酬公式）+ 字体覆盖 | `结论: PASS` |
| `--script res://tools/verify_letter_layout.gd` | 代写界面词库布局（5 称谓 / 3×10 正文 / 4 落款、可滚动、不横向溢出）| `结论: PASS` |
| `--script res://tools/verify_shell.gd` | 应用身份（名称/版本/图标）+ 六场景可加载 + 标题页「玩法说明」可开可关 | `结论: PASS` |
| `--script res://tools/capture_scene.gd -- --scene <名> --out x.png [--click <按钮>] [--seed N]` | 任意场景截图；`--seed` 固定随机 NPC，供改版前后逐像素对比 | 出图**必须 1152×648**，否则脚本报错 |
| `--script res://tools/probe_geom.gd` | 量贴图绘制区 / 槽位实际矩形 | 判断锚点该写多少 |
| `node tools/md_structure_check.mjs <file.md>` | Markdown 结构（标题重复/孤儿节/表格）| 改完文档后跑 |
| `node tools/art_check.mjs <info\|palette\|grid\|watermark\|crop> <图>` | 美术素材校验 | 见第 6 节 |
| `node tools/balance_sim.mjs` | 数值蒙特卡洛 | 见 `docs\BALANCE_REPORT.md` |
| `node tools/balance_sim.mjs --targets 500,525,550` | 目标金额细扫（也支持 `--stall/--npc/--start/--games/--bonus-mul/--pool`）| 见 `docs\CONTENT_PROPOSAL.md` |
| `python tools/check_content_chars.py` | 候选内容的汉字是否都在项目字体字形表里 | `[OK] 全部覆盖` |

**纪律**：项目文档 > 对话印象。**PPT/结论要先跑验证**；改完先自己验一遍再交付。

## 4. 架构

### 单例（`project.godot` 的 `[autoload]`）

| 单例 | 职责 |
|---|---|
| `PlayerManager` | 金钱（初始 100）、天数（1..10）、已完成委托、每日流水、存读档（`user://save.dat`）、结局判定（≥500 文 = 成功）|
| `NPCManager` | 每日生成委托人：姓名、**关系**、正确答案、词库、反馈文本。**NPC id 为负数** |
| `JudgeSystem` | 判定与计费，四档（PERFECT/GOOD/NORMAL/WRONG）—— **算钱规则见下方「经济数值」** |
| `FontFallback` | 启动时给主题字体挂系统字体兜底（`Font.fallbacks` **无法存进 `.tres`**，见 `docs\AI_PLAYBOOK.md`）|
| `AudioManager` | 全局音频：4 个 UI 音效（播放器池 ×4）+ 2 条循环 BGM（交叉淡化、跨场景延续）+ 静音开关（写 `user://settings.cfg`）。素材由 `tools\gen_sfx.py` / `tools\gen_bgm.py` 合成、可重跑 |
| `CursorManager` | 启动时设一次毛笔系统光标（`cursor_brush_tip.png`，64×64、热点 (32,7)）。素材由 `tools\gen_cursor.py` 生成 |
| `SceneFx` | 全局动效开关 + 淡入：**`--headless` / `--script` / 截图参数下自动跳过**（否则截图会截到半透明帧）；各场景 `_ready()` 用它淡入 |

场景脚本**直接访问单例**（`PlayerManager.add_money(20)`、`get_node("/root/NPCManager")`），
没有依赖注入或服务定位层。

### 场景流

```
title_screen → prologue → main → letter（在 main 之上实例化）→ main → success / gameover
```

- **`title_screen`** —— 新游戏（重置状态）/ 继续（读档）/ 退出；标题「代书」用项目字体渲染
- **`prologue`** —— 剧情开场，一个按钮继续
- **`main`** —— 枢纽：显示钱/天，「开始今日」生成委托列表（**头像 + 按钮**），点委托实例化 `letter.tscn` 并隐藏自己；「结束今日」触发结算
- **`letter`** —— 代写界面：左侧是可拖拽词按钮（`word_button.gd`），右侧是可放置槽位（`letter_slot.gd`，虚线边框 `_draw`）。提交 → `JudgeSystem` → 弹窗 → `PlayerManager` 记录 → 回 `main`
- **`success` / `gameover`** —— 共用 `EndGameScreen.gd`，靠 `@export var is_success: bool` 区分

### 关键数据结构

**NPC 字典**（`NPCManager` 生成）：`npc_id`（负数）、`name`、**`relation`**（父母/子女/夫妻/兄弟/朋友，
决定称谓池与落款池、也驱动头像取字取色）、`request_text`（口述，正解已嵌进句子）、
`correct`（`salutation` / `body_slots.slot1/2/3` / `signature`）、`word_pool`（与 correct 平行的候选数组）、
`base_fee`、`perfect_bonus`、`feedback`、`description`、`avatar`（**恒为空**；`npc_avatar.gd` 会回落到
`assets/images/ui/avatars/<关系>.png` 的真肖像，再回落程序化名帖牌）。

**玩家答案**（传给 `JudgeSystem.judge(npc, answers)`）：
`{salutation, body_slot1, body_slot2, body_slot3, signature}`，全是字符串。

⚠️ **`word_pool` 的正文槽是嵌套的**：`word_pool.body_slots.slot1`（**不是** `word_pool.slot1`）。
`JudgeSystem._check_item()` 对正文键做了嵌套处理。

### 经济数值

| 项 | 值 |
|---|---|
| 起始铜钱 | 100 文 |
| 目标 | 10 天后 ≥ 500 文 |
| 每日摊位费 | 10 文（`STALL_FEE_PER_DAY`），**钱变负立即结束** |
| 基础报酬 | `12 + floor((day-1)/3)` |
| 完美加成 | `8 + (day-1)` |

| 判定 | 条件 | 报酬 |
|---|---|---|
| **WRONG** | **有格式错误**（留空，或用了词库外的词）| **`fee = -2 × 错误项数`（负数）**；**优先级最高** —— 有格式错误就不再看正确数 |
| **PERFECT** | 五项全对 | `base_fee + perfect_bonus` |
| **GOOD** | 五项中四对 | `base_fee + int(perfect_bonus × 0.7)` |
| **NORMAL** | 其余（词库内但非正解）| `int(base_fee × 0.6)` |

判定顺序（`JudgeSystem.gd:63-79`）：`格式错误 > 全对 > 四对 > 其余`。
**注意 WRONG 是"直接判负"**，不是在 `base_fee` 上扣 —— 别把两者叠加理解。
详见 `docs\JUDGE_SYSTEM_LOGIC.md`。

### UI 约定

- 中文竖排用 `_to_vertical()`（一字一行，自上而下）
- 信纸正文用 `assets/fonts/hanchanlongcang.otf`（寒蝉龙藏体，毛笔书法，**个人与企业免费商用**，
  授权说明见 `assets/fonts/寒蝉字体授权说明.txt`）
- **全局 Theme**：`theme\daishu_theme.tres` 由 `project.godot` 的 `gui/theme/custom` 挂载，
  六个场景共用（中文字体 + 按钮九宫格）。**全局字号变了要重截所有含列表的界面**（会撑破容器）
- 可拖拽词：`word_button.gd`（拖拽数据打包 `{type, word, category, body_slot}`）
- **词库区结构**：`WordPanel → WordScroll(ScrollContainer) → WordVBox → 三个分组容器`；
  正文每槽是 `HFlowContainer`（每槽 10 词自动换行）。**改这层结构必须跑 `verify_letter_layout.gd`**，
  并注意 `verify_drop.gd` 里写死了该路径（旧路径会让脚本取不到节点并挂住不退出）。
- 放置槽：`letter_slot.gd`（`_can_drop_data` 校验 `category`/`body_slot`，发出 `word_dropped(slot_key, word)`）

## 5. 美术硬规矩

⚠️ **任何要出货的素材不得含文字/水印/品牌标识**（`docs\ART_PLAN.md` §一）。

**审计结论（2026-10-12 实测，别重复怀疑）**：`tools\art_check.mjs watermark --scan` 会在这几张图上报命中，
**逐张裁出来目视复核后的实际结论**：

| 图 | 检测器 | 目视复核结论 |
|---|---|---|
| `letter.png` | ✅ 未检出 | **干净**。右下角那处"疑似残影"裁出来放大看过：只有像素风阶梯边框，**没有字形**（据此改过一版凭印象写的错误结论）|
| `main.png` | ✅ 未检出 | 已重出为 **1152×648 平涂图**（2026-10-13），不再有 bbox 命中 |
| `main_bg.png` | ⚠️ **报命中** | bbox `[1928,479..1983,516]` 同样是**摊位里的人与货** —— **误报**，但**检测器仍会报**，别当成回归 |

**规则**：检测器报命中时**必须裁出来人眼复核**再决定；**不能只依据退出码**。
三张底图的生成器水印已于 2026-10-12 全部清除（做法见 `docs\ART_PLAN.md` §三）。

**已解决（2026-10-13）**：标题页曾用 `main.png`（水墨风）、主界面用 `main_bg.png`（像素插画风），两者画风不一套。
现在两张都是**平涂插画 + 暖色调** —— `main.png` 已重出为 1152×648，实测暖度差 55→3，并排已成套。
历史处置方案与失败路径见 `docs\ART_PLAN.md` §二·五、`docs\ART_TITLE_SET_ATTEMPT.md`、`docs\ART_TITLE_SET_DONE.md`。

### 素材校验工具（零依赖，只用 node 内置 zlib，**不需要 npm install**）

```bash
node tools/art_check.mjs info      <img>              # 尺寸/格式/亮度
node tools/art_check.mjs palette   <img>              # 色板量化 + 与 ART_PLAN 锚点色对比（色距 >0.30 判偏离）
node tools/art_check.mjs grid      <img> --expect 12  # 竖线像素检测 → 栏位分数表（信纸锚定用）
node tools/art_check.mjs watermark <img> --scan       # 水印排查
node tools/art_check.mjs crop      <img> --box x0,y0,x1,y1 --out f   # 取局部供人眼复核
```

**带网格的底图改锚点必须走三步**：`grid` 量结构 → 写锚点 → **截图后复验**。**禁止目测估结构位置。**

## 6. 文档坐标系（谁是权威）

| 要查什么 | 权威文档 |
|---|---|
| **本文件的规则依据、本机踩坑（条数以文件为准）** | `docs\AI_PLAYBOOK.md`（+ `-DETAILS.md` 完整版）|
| **文档与实现是否一致（一次性审计，2026-10-18）** | `docs\DOC_AUDIT_2026-10-18.md` |
| **发布前进度 / 剩余项** | `docs\PRE_RELEASE_UI_CHECK.md` ← **唯一权威进度表** |
| 交接摘要（现状/历程/怎么跑/怎么验）| `docs\项目总览.md` |
| 美术方向、色板锚点、资产清单、水印与画风实测 | `docs\ART_PLAN.md` |
| 开发计划与里程碑 | `docs\DEV_PLAN.md` |
| 单例职责 / 依赖 / API | `docs\ARCHITECTURE_SINGLETONS.md`、`docs\SINGLETON_APIS.md` |
| 场景节点树与信号 | `docs\SCENE_OVERVIEW.md` |
| 判定与计费 | `docs\JUDGE_SYSTEM_LOGIC.md` |
| NPC 生成规则 | `docs\NPC_GENERATION.md` |
| 存档与数据结构 | `docs\DATA_FORMATS.md` |
| 数值平衡模拟 | `docs\BALANCE_REPORT.md` |
| **内容扩充 / 难度调整提案（已采纳并实施，2026-10-18）** | `docs\CONTENT_PROPOSAL.md` |
| **Web 版迁移方案（含分发策略与技术路线推导；存档，未执行）** | `docs\WEB_VERSION_PLAN.md` |
| 项目蓝图总览 | `docs\readme.md` |
| 仓库页说明 | `README.md` |

⚠️ **已过时的说法**（改动前先看权威文档）：`DEV_PLAN.md` 的"已知问题"段仍写着信纸带水印（**已清除**）；
`README.md` 里也有几处旧状态。**冲突时以 `PRE_RELEASE_UI_CHECK.md` 与 `ART_PLAN.md` 为准。**

## 7. 环境与依赖

```
scripts/          # 所有 .gd（单例 + 场景脚本 + UI 辅助 + npc_avatar.gd）
scenes/           # 6 个 .tscn
theme/            # daishu_theme.tres（全局主题）
assets/
  fonts/          # hanchanlongcang.otf + 授权说明
  images/
    backgrounds/  # main.png（标题）/ main_bg.png（主界面）/ letter.png（信纸）
                  # ending_success.png / ending_gameover.png / prologue_bg.png
    ui/           # button_frame.png（九宫格）/ brush_cursor.png（拖拽预览）
                  # cursor_brush_tip.png（系统光标，tools\gen_cursor.py 生成）
                  # icon.png（应用图标，tools\gen_icon.py 生成）/ avatars/<关系>.png
  audio/sfx/      # ui_click / paper_drop / submit / day_end（tools\gen_sfx.py 生成）
  audio/bgm/      # bgm_title / bgm_letter（23 s 循环，tools\gen_bgm.py 生成）
data/             # art_prompts_round1/2.json（美术生成提示词）
docs/             # 设计文档（见第 6 节）
tools/            # 校验 / 模拟 / 截图 / 环境脚本
godot-docs/       # Godot 4.6 官方文档语料（gitignore，只读）
godot-mcp/        # Godot MCP 服务端，git-clone 依赖（gitignore）
addons/           # Godot 插件（可能为空）
```

- **round1 的 15 张 832×832 候选素材不在仓库里**，归档在 `D:\daishu_asset_archive\`
  （`196001c` 移出，**没丢**，已复检无水印）。**别重新生成。** 见 `docs\ART_PLAN.md` §八。
- **导出**：`export_presets.cfg` 有 `Windows Desktop` 预设；模板已装
  （`%APPDATA%\Godot\export_templates\4.6.1.stable.mono`）。导出产物已 gitignore，**不进仓库**。
- **mono 引擎**会打印 `.NET Sdk not found` —— 纯 GDScript 项目，**这条可忽略**，别去装 .NET SDK。

### MCP 接线（`godot-mcp/`）

`godot-mcp/` 是 git-clone 依赖（被 gitignore），**新克隆没有 MCP 服务端**。一键复现：

```powershell
pwsh -File tools\setup-godot-mcp.ps1
```

脚本做四件事：定位 `*_console.exe` → 克隆并构建 `godot-mcp/` → **打印**接线配置 → 自检
（含**真的向服务端发一次 JSON-RPC `initialize`**，确认它能起来）。
**它不再写任何配置文件** —— 接线要人自己贴（见下一条），避免生成无人读取的残留。

- 必须用 **SSH**（本机 HTTPS 到 github.com 被拦）
- `GODOT_PATH` 必须指向 **`*_console.exe`**（非 console 版重定向 stdout 输出 0 字节，
  会**静默**破坏 `run_project` / `get_debug_output`）
- 服务端暴露 **14 个** `mcp__godot__*` 工具
- **实际生效的接线只有一处**：`~/.dsh/profiles/web/cordis.patch.yml` 的 `mcp-godot` 条目（热监听）。
  脚本会打印该填的 `command` / `args` / `GODOT_PATH`
- **接线状态要现查**（会自己消失）。判据三查：① 文件里有 `mcp-godot` ② 进程表有
  `node.exe … godot-mcp\build\index.js` ③ 新会话工具清单里有 `mcp__godot__*`

## 8. AI 协作纪律

1. **改 GDScript / 场景前先查 `godot-docs`**（第 1 节），别凭记忆。
2. **验完再说"完成"**：跑第 3 节的验证脚本；**"命令没报错"不等于"生效了"**
   （实测：同尺寸改写图片时 Godot **不会**重新导入，`.ctex` 仍是旧像素）。
3. **出图看着不对时，先怀疑工具漏步骤**，用探针打印节点数/尺寸再下结论 ——
   本会话两次误判（"槽位不可见"、"主题把词库按钮弄没了"）**都是观察方式的问题，不是游戏坏了**。
4. **拿"标题行"当 `edit` 锚点会造出孤儿正文**：插入章节时**以正文首行当锚点**（把标题拼进 new_string），
   写完跑 `node tools\md_structure_check.mjs <file.md>`。同一手法在同一个文件里连踩三次。
5. **改 `docs\` 下的文档后跑结构守卫**；改了 playbook 就同步镜像（第 1 节）。
6. **共享目录里不要用 `git add -A`**（会把并行会话的在途改动一起提交）。显式列路径。
7. **`~\.dsh\AGENTS.md` 的「实测陷阱」封顶 12 条**，新增一条 = 同时退役一条（原子操作）；
   详细规则见 `~\.dsh\RULES-PLAN.md`。**本项目的本机踩坑写在 `docs\AI_PLAYBOOK.md`**，不写进用户级。
8. **Godot 编辑器保存 `project.godot` 时，会把「等于引擎默认值」的设置剪掉**（实测 2026-10-18：
   打开一次编辑器后 `window/size/viewport_width=1152` / `viewport_height=648` 两行消失，因为
   1152×648 正是 4.6 的默认值）。**这两行是刻意显式写的**（槽位对齐依赖它，Godot 改默认值就不能默默跟着变）。
   判据：`git status` 里出现 `project.godot` 的这类删除时**恢复它**，别当成有意改动提交。
9. **不要用 PowerShell 的 `.Replace()` 改中文文档**（2026-10-18 实测：替换"31 篇"时实际执行成了
   `'3'→'1'`，把 README 里"每日 3 位委托人""(day-1)/3""31 篇"三处一起改坏，且命令**没有报错**）。
   **改文档内容一律用 `edit` 工具**（UTF-8 安全）；PowerShell 只用来跑只读查询和 `git`。
   判据：改完 `git diff` 必须只剩预期的那几行。
