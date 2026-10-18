---
name: godot-docs
description: 查本地 Godot 4.6 官方文档语料（类参考 1066 篇 + 教程 426 篇）核对 API、节点、信号、属性、注解与引擎用法。写或审 GDScript 前先在这里查证，不要凭记忆写 API。
whenToUse: 任务涉及 Godot 引擎 / GDScript / 场景 / 节点 / 信号 / 资源 / 导出 / 渲染或物理设置 / 报错排查时
---

# 语料（第一依据 —— 别凭记忆写 API）

- `godot-docs\`（**仓库根下**，已 gitignore、不入库）：gitcode 镜像的 godot-docs 仓库，**4.6 分支**（HEAD `b10b7ed`），
  纯文本稀疏检出 1568 篇 `.rst`。**版本锚点 4.6**（引擎 v4.6.1-stable mono 同代）；
  图片与动图**未检出**，正文里的图片链接指向本机访问不了的 `raw.githubusercontent.com` —— **不要追图片**。
  ⚠️ **有的机器克隆后没有这份语料**（它被 gitignore，且是部分克隆）。先 `Test-Path godot-docs\classes`：
  不在了就**明说"本地语料缺失"**，改用 `web_fetch` 查 `docs.godotengine.org`（并说明它可能不是 4.6），
  **别凭记忆补签名**。
- **语料的边界（2026-10-11 实测）**：它是 `blob:none` 的**部分克隆** —— **只能查文档，不能切分支/回滚**
  （`git checkout` 会去 gitcode.com 取 blob，本机代理拦 403、报 `could not fetch … from promisor remote`）。
  机制、恢复图片与切分支的做法见 `DETAILS.md`「语料的边界」。

# 目录地图

| 要查什么 | 去哪 |
|---|---|
| 类参考（属性 / 方法 / 信号 / 枚举 / 常量） | `classes\class_<小写类名>.rst`：`Node2D`→`class_node2d.rst`、`HTTPRequest`→`class_httprequest.rst` |
| GDScript 语言本身（语法、类型、注解） | `classes\class_@gdscript.rst` |
| 全局函数与单例（`print` / `load` / `Input` / `Engine`…） | `classes\class_@globalscope.rst` |
| 教程与最佳实践 | `tutorials\<主题>\` —— 24 个主题目录的清单见 `DETAILS.md`「目录地图」 |
| 入门 / 引擎内部机制 | `getting_started\` / `engine_details\` |

# 检索配方

用 DSH 的 `grep` / `glob` / `read`；**本机 shell 里没有 `rg`**，别在 pwsh 里拼 ripgrep。

1. **查某个类**：先 `grep` 定位行号，再 `read` 该片段（类文件通常 300–3000 行）：
   `grep pattern="move_and_slide|position" path=<仓库根>\godot-docs\classes\class_characterbody2d.rst`
2. **不确定方法/信号/属性属于哪个类**（最有用的起手式）：
   `grep pattern="^\.\. _class_\w+_method_move_and_slide:" path=<仓库根>\godot-docs\classes`
   锚点规则是 `class_<类名>_(method|property|signal|constant|enum)_<名字>`，把 `method` 换成
   `signal`/`property` 即可反查信号与属性。
3. **查主题做法**（拖放 / 存档 / 相机跟随 / 状态机）：
   `grep pattern="drag and drop" path=<仓库根>\godot-docs\tutorials`，命中后读对应 rst。
4. **查废弃与版本迁移**、**类参考结构**（锚点写法 / 章节顺序 / 总览表）：见 `DETAILS.md`。

# 纪律

- **断言 API 必须给出处**：`classes\class_xxx.rst` 文件名 + 行号。查不到就直说"文档里没有"，
  **不要拿 3.x 的旧记忆补齐**。
- 本项目是 4.x：留意 `@export` 注解写法、`Tween`、`Callable`、`Node.owner` 语义、单例访问方式；
  文档里标 `deprecated` 的一律不用。
- **可以联网，但第一依据仍是本地语料**（它锚定 4.6，官网 `/en/stable/` 未必是 4.6）：`web_fetch` 可用、
  `docs.godotengine.org` 实测 200；只在①本地语料确实没有 ②核对某条 API 在 4.6 之后是否变更时用，
  引用官网要说明它可能不是 4.6。

# 项目文档地图（代书，**仓库根 = 含 `project.godot` 的那层**）

写代码前先看项目自己的文档 —— 它们比通用教程更贴近本项目约定：

| 要查什么 | 去哪 |
|---|---|
| 总览 / API 摘要 / 判定规则 | `docs\readme.md` |
| 三单例职责与依赖关系 | `docs\ARCHITECTURE_SINGLETONS.md`、`docs\SINGLETON_APIS.md` |
| 场景节点树与信号连接 | `docs\SCENE_OVERVIEW.md` |
| NPC 字典 / 存档 / 玩家答案字段 | `docs\DATA_FORMATS.md`、`docs\NPC_GENERATION.md` |
| 判定计费逻辑 | `docs\JUDGE_SYSTEM_LOGIC.md` |
| 平衡数值 / 路线图与已知风险 | `docs\BALANCE_REPORT.md`、`docs\DEV_PLAN.md` |
| 美术方向 / 色板 / 生成提示词 / 素材校验 | `docs\ART_PLAN.md`、`docs\ART_BASELINE_ROUND1.md`、`tools\art_check.mjs` |
| **给 AI 助手的项目规则（唯一入口）** | `AGENTS.md` |

**代码为准**：文档与实现冲突时以实际实现为准（`docs\readme.md` 曾长期滞后，2026-09 校正过一次），
并顺手把文档改对。

# 本机踩坑（结论清单 —— 每条都实际踩过）

> 完整场景、命令与数字见 `DETAILS.md`「本机踩坑（完整版）」。这里只留"该怎么判"。

1. **`godot --check-only --script` 不注册 autoload** → 引用单例的脚本一律报 `Identifier not found`，**是假阳性**。
   判据：拿一个没动过、同样引用单例的脚本做对照组（全报＝模式问题）。
2. **整数除法警告**：`int(a / b)` 里的 `int()` 多余且消不掉警告，改用 `floori(a / b.0)`（负数语义不同）；
   该警告只在运行时出现，headless 看不到。
3. **Godot 段错误先怀疑文件权限**：沙箱拦 `user://` 写入时崩在项目加载**之前**（`--check-only` 也崩、
   `--verbose` 无任何资源加载输出）—— 是环境问题，不是代码问题。
4. **`unique_id=` 是 4.6 新语法**（`load_steps` 已废弃）—— 别当错误去"修"。
5. **godot-mcp 接线会"自己消失"，状态必须现查**。**判据三查**：① `cordis.patch.yml` 里有 `mcp-godot`
   ② 进程表有 `node.exe … godot-mcp\build\index.js` ③ 新会话工具清单里有 `mcp__godot__*`。
   `GODOT_PATH` 必须指 `*_console.exe`（**指错不报错、只是静默没有调试输出**；路径失效会静默回落到内置
   默认值，症状是 `spawn … ENOENT`）。console exe 的完整路径见 `DETAILS.md` 第 5 条。
6. **美术素材必须像素级校验，禁止目测**：`tools\art_check.mjs`（零依赖）—— `info` / `palette`（色距 >0.30 判偏离）/
   `grid` / `watermark` / `crop`；带网格的底图改锚点必须走 `grid` → 写锚点 → 截图复验三步。
7. **沙箱拦 `user://` 的确切判据**：崩溃前必有 `Failed to open 'user://logs/godot<时间戳>.log'` + `signal 11`，
   且无任何资源加载输出；放宽权限后同命令 exit 0 零输出。
8. **`--script` 模式不导入新资源**：新加的图片在 `--script` 下 `ResourceLoader.exists()` 返回 **false**、
   **静默加载失败**（贴图为 null，不报错）。判据：新资源先跑一次 `godot --headless --path . --import`，再跑测试。
9. **`_get_drag_data()` 不能直接调**：无真实拖拽时 `set_drag_preview()` 触发引擎断言
   `!get_viewport()->gui_is_dragging()`。判据：**预览构造抽成独立函数**（本项目 `build_drag_preview()`）只调它。
10. **`.tres` 里 stylebox 的键名别手写，让引擎写**：手写 `Button/styles/normal` 这类键猜错会**静默失效**
    （主题挂上了却没样式）。判据：代码建 `Theme` 再 `ResourceSaver.save()`；**改完立即 `load()` 回读会命中
    写入前的缓存**，回读要**读文件文本**，语义校验另起进程。
11. **`Font.fallbacks` 不会进 `.tres`，Godot 也不会自动回退系统字体** —— **只能运行时挂**（本项目
    `scripts/FontFallback.gd` 自启动）。判据：拿一个**主字体确实没有**的字符渲染一张图看是不是方块；
    挂了兜底后字体是 `FontVariation`，取名字要用 `.base_font.font_name`。
12. **命令行 `--resolution` 会连同视口一起改，截图会被缩放**，拿它当像素依据会得出错误结论。
    判据：截图工具自己设窗口尺寸，**写完图断言尺寸**，不符就报错。
13. **全局 Theme 的字号会改变布局、撑破容器**。
    判据：**换全局字号后必须重截所有用了列表/多按钮的界面**，按"按钮数 × 单按钮高"估算是否装得下。
14. **截图工具漏了初始化步骤时，界面会"看着像游戏坏了"**。
    判据：**截图/自动化工具要复刻真实入口的初始化调用链**；出图不对先用探针打印**节点数与尺寸**再下结论。
15. **`--import` 是异步的**：它还没写完就去 `ResourceLoader.exists()` 会得到"资源缺失"的假象。
    判据：**新增资源后先单独跑完一次 `--import`**，再跑依赖它的脚本；报缺失时先 `Test-Path` 核实
    `.import`/`.ctex` 是否真的不在（`--script` 模式根本不会触发导入 —— 见第 8 条）。
16. （小）**GDScript 同作用域不允许变量重名**（哪怕在不同 `if` 分支），报 `There is already a variable
    named …`；这类**解析失败会让 `--script` 既不执行也不 `quit()`**（命令挂住不退出），跑探针要带超时。
17. **改了图片内容但尺寸/字节数没变时，Godot 不会重新导入**。判据：**同尺寸改写图片后删掉
    `.godot/imported/<图>-<哈希>.ctex` 与 `.md5` 再 `--import`**；验证要落到"渲染出来的图变了没有"。
18. **改 Markdown 章节后必须跑结构守卫，别靠眼睛**：**拿"标题行"当 edit 锚点**最容易漏写回旧标题，
    正文就成了"挂在上一节下面"的孤儿（内容都在，肉眼看着正常）。判据：**`node tools/md_structure_check.mjs
    <file.md>`**（本项目工具，带 `--selftest`）；插入章节**以正文首行当锚点**。
19. **想让容器里的子节点"居中"，要改容器的 `alignment`，不是子节点的 `size_flags_vertical`**。
    实测（2026-10-13）：给 `VBoxContainer` 的子节点加 `size_flags_vertical = 4`（`SIZE_SHRINK_CENTER`）
    **完全无效** —— 改前改后截图**逐像素完全相同（0 个不同像素）**；真正生效的是
    容器的 `alignment = 1`（`ALIGNMENT_CENTER`，`classes\class_boxcontainer.rst:94-98,119-130`）。
    判据：内容偏上时先查该容器**有没有 `alignment`**。另：`size_flags_*` 的常量语义见
    `classes\class_control.rst:955-993`（`SIZE_FILL=1` / `EXPAND=2` / `EXPAND_FILL=3` / `SHRINK_CENTER=4`）。
20. **`--script` 探针里 Control 的布局算不出来（size 恒为 0）—— 这是观察方式的问题，不是布局坏了**。
    实测（2026-10-13）：`SceneTree` 默认视口是 **100×100**，`instantiate()` 后所有 `Control`
    报 `size=(0,0)`、`pos` 全是锚点位移，看着像"改动没生效"。判据：探针里**先 `get_root().size =
    Vector2i(1152, 648)`** 再 `add_child`；即便如此，`--script` 下容器仍可能不排布 ——
    **决定性判据是"截图逐像素比差异"**（`ImageChops.difference` 的 `getbbox()` 是否为 `None`），
    而不是靠肉眼估 y 坐标。

21. **`--script` 的 `_initialize()` 里，`/root/xxx` 绝对路径全部返回 null**。
    实测（2026-10-18）：脚本一开头就取单例/实例化场景，`get_node("/root/NPCManager")` 报
    `Can't use get_node() with absolute paths from outside the active scene tree`（或 `Node not found`），
    而 `get_root().get_node_or_null("NPCManager")` 又能拿到 —— 因为 **`_initialize()` 跑在 SceneTree
    激活之前**，此时 `get_root().is_inside_tree()` 还是 `false`。给 `current_scene` 赋值**没用**。
    判据：**`_initialize()` 开头先 `await process_frame`**，之后 root 才进树，
    场景脚本内部（如 `letter.gd` 的 `get_node("/root/NPCManager")`）也才成立。
    症状更隐蔽的一点：不加这一帧时用例会"看起来 PASS"（NPC 没初始化、逻辑分支根本没走到），必须看 stderr。

22. **验证脚本里 `queue_free()` 之后不能再跨 `await` 访问该节点**（2026-10-18 实测）。
    写法 `letter._unhandled_input(esc)` → 内部 `return_to_main()` → `queue_free()`，
    然后 `await process_frame` 再调 `letter.is_queued_for_deletion()`，报
    `Cannot call method 'is_queued_for_deletion' on a previously freed instance`。
    **致命之处不是报错本身，而是 GDScript 报错后停在本帧、不执行后面那句 `quit()`** ——
    命令行看起来像"挂住"（本次跑了 4 分钟才发现，和旧节点路径那次症状一模一样）。
    判据：**在调用后同步断言**（`is_instance_valid(n) and n.is_queued_for_deletion()`），
    不要跨帧再碰它；跑验证脚本一律带超时，超过 30 s 视为失败去查 stderr。

# 维护与导出

- **装导出模板**（没有它无法产出 exe）、**升级引擎切语料分支**、**恢复图片**、**网络可达性**：
  命令见 `DETAILS.md`「维护与导出」。只留一条判据：**slug 与引擎口味不一致不会报错、只会导出失败**
  （mono 引擎要 `mono_export_templates.tpz`；`%APPDATA%\Godot\export_templates\` 默认为空）。

# 源码与同步

- 改 `docs\AI_PLAYBOOK.md`（判据）+ `docs\AI_PLAYBOOK-DETAILS.md`（细则），**改完必须**
  `pwsh -File tools\sync-ai-playbook.ps1` 同步镜像（DSH 读的是 `~\.dsh\skills\godot-docs\`；
  `-Check` 只查漂移）。镜像路径与"为什么必须同步"见 `DETAILS.md`「源码与同步」。
