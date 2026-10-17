# 《代书》Web 版迁移方案（2026-10-18）

> **状态：方案存档，未执行。** 现在不改任何代码；等"触发条件"（§一）成立再按本方案执行。
> 本方案的每个数字都来自当前仓库实测（行数、词库规模、字体子集体积），估算项已标注"估"。

---

## 一、触发条件：什么时候值得换

**触发任一即启动：**

1. 主战场确定为 **Web / itch.io / 小游戏**（需要"点开链接就能玩"）。
2. 需要在**手机**上玩或分享给非 PC 用户。
3. Godot 桌面版的分发/启动继续成为阻塞（本机已出现：直接启动引擎会 `signal 11`，必须走
   `tools\open-editor.cmd` 重定向 `APPDATA`；Godot 的 **Web 导出同样依赖 ~1 GB 导出模板**，
   而用户已决定不装 mono 模板）。
4. 需要高频调 UI/规则（内容与规则在 Web 里是热更新，改一行即刻生效）。

**不触发（继续用 Godot）：**

- 目标只是 **Steam 桌面单机**，且现有 Godot 版本已能满足。
- 只是想要"再美化一点"，不涉及分发形态。

---

## 二、结论摘要

- **可以不用引擎**：本作是 UI 驱动（纸张、竖排文字、拖拽落词、规则判定），DOM/CSS 比引擎 UI 更自然。
- **但不要现在就重写**：Godot 版已有 1614 行 GDScript、6 个场景、10 个验证脚本，
  且刚完成内容扩充（正文 150 个词位、26 条模板）。**保持 Godot 为唯一真源，直到 Web 版达到等价。**
- **推荐路径**：先做 **1 天竖切**（M1：代写界面 + 判定 + 存档），拿去 itch.io 收反馈；
  手感成立再走 M2–M4 全量迁移；不成立就停在 M1，损失一天。
- **不要长期双轨**：M3 完成、Web 版通过验收后，Godot 版转入归档（保留仓库历史，不再同步内容）。

---

## 三、目标与非目标

### 目标

1. 浏览器打开即玩，桌面/手机均可（鼠标 + 触屏）。
2. 玩法、规则、数值、内容与 Godot 版**逐项等价**（以 `NPCManager` / `JudgeSystem` / `PlayerManager` 为准）。
3. 首次加载 **≤ 3 MB**（字体子集 489 KB + 代码 + 图片，gzip 后更小）。
4. 存档可靠：刷新/关标签页不丢进度，坏档回落新游戏。
5. 构建产物 `dist/` 可直接上传 itch.io（zip 解压即玩）。

### 非目标（本期不做）

- 微信/抖音小游戏适配（🕒 后置，见 §十一）。
- 多语言、账号系统、云存档、排行榜。
- 重做美术：现有 PNG 背景/头像/九宫格素材直接复用。
- 移植 Godot 的 `_draw` 虚线槽位效果——改用 CSS `border` + `background-image` 更简单。

---

## 四、技术选型

| 层 | 选择 | 理由 / 备选 |
|---|---|---|
| 构建 | **Vite 5 + TypeScript** | 零配置、秒级 HMR；产物纯静态 |
| UI | **React 18** | 仅为拿到 dnd-kit 的成熟绑定；备选 Svelte + `svelte-dnd-action` |
| 拖拽 | **dnd-kit**（`@dnd-kit/core` + `@dnd-kit/modifiers`） | `DragOverlay` 做跟随光标的毛笔预览；`useDroppable` 做槽位校验；官方支持触屏/键盘 |
| 状态 | **Zustand** | 全局状态只有 money/day/当前 NPC/答案；`persist` 中间件接 IndexedDB |
| 存档 | **idb-keyval**（IndexedDB） | 比 localStorage 容量大；单键存 JSON，带 `version` 字段 |
| 样式 | **原生 CSS（CSS Modules）** | 竖排、纸张质感全靠 CSS，无需框架 |
| 字体 | **hanchanlongcang 子集** | `pyftsubset` 实测 868 字 → **489 KB**（原 4.05 MB） |
| 音频 | **Howler.js**（或浏览器原生 Audio） | 复用现有 wav；BGM 循环、静音开关 |
| 单测 | **Vitest** | 判定/经济/存档是纯函数，比 Godot `--script` 更好测 |
| E2E | **Playwright** | 拖拽落词、四档判定、存档往返 |
| 桌面分发 | **Tauri 2**（后置） | Web 版要上 Steam 时套壳；不用 Electron（体积大一个量级） |

> ⚠️ **本机前置**：`node` 不在 PATH，只有 DSH 自带运行时
> （`C:\Users\Administrator\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\node\bin\node.exe`）。
> **`npm` / `pnpm` 是否可用本会话未验证**——执行第一天先跑 `node -v && npm -v`，不行就先解决包管理器。

---

## 五、工程结构

```
web/
├─ index.html
├─ vite.config.ts            # base: './'（itch.io 子路径必需）
├─ package.json
├─ public/
│  ├─ bg/main.png  main_bg.png  letter.png  prologue_bg.png  ending_success.png  ending_gameover.png
│  ├─ avatars/<关系>.png      # 直接复制现有素材
│  ├─ ui/brush_cursor.png  button_frame.png  cursor_brush_tip.png
│  ├─ audio/sfx/*.wav  audio/bgm/*.wav
│  └─ fonts/daishu.woff2      # pyftsubset 产物（woff2 更小）
├─ src/
│  ├─ main.tsx
│  ├─ data/
│  │  ├─ npc.json            # 由 tools/export_content.py 从 NPCManager.gd 导出
│  │  └─ economy.ts          # 常量：起始 100 / 目标 500 / 摊位 10 / 公式
│  ├─ game/
│  │  ├─ judge.ts            # 纯函数，四档判定与计费
│  │  ├─ generate.ts         # NPC 生成（读 npc.json）
│  │  ├─ save.ts             # IndexedDB + schemaVersion
│  │  └─ store.ts            # Zustand：money/day/npc/answers/结局
│  ├─ screens/
│  │  ├─ Title.tsx  Prologue.tsx  Main.tsx  Letter.tsx  End.tsx
│  ├─ components/
│  │  ├─ PaperSlot.tsx       # 可放置槽（竖排文本）
│  │  ├─ WordButton.tsx      # 可拖拽词（dnd-kit useDraggable）
│  │  ├─ WordScroll.tsx      # 词库滚动区
│  │  └─ ResultDialog.tsx    # 判定弹窗
│  └─ styles/                # *.module.css + global.css（竖排、纸纹、按钮九宫格）
└─ tests/
   ├─ judge.test.ts  economy.test.ts  save.test.ts
   └─ e2e/letter.spec.ts
```

---

## 六、数据迁移（关键：内容只迁一次，之后以 JSON 为真源）

1. 写 `tools/export_content.py`：用 `ast`/正则解析 `scripts/NPCManager.gd` 的四组常量
   （`BODY_POOLS` / `SALUTATION_POOL` / `SIGNATURE_POOL` / `STORY_TEMPLATES` / `SLOT_HINTS`），
   输出 `web/src/data/npc.json`。
   - **不要手抄**：150 个词位 + 26 条模板手抄必错。
   - 导出后立刻用同一套不变量校验（见 §九），与 `verify_content` 等价。
2. 规则常量（起始 100 文、目标 500、摊位 10/天、`base = 12 + floor((day-1)/3)`、
   `bonus = 8 + (day-1)`、判定优先级 WRONG > PERFECT > GOOD > NORMAL）写进 `economy.ts`，
   **逐条对照 `JudgeSystem.gd` / `PlayerManager.gd`**，别凭记忆。
3. 迁移完成后在 Godot 侧加一句注释：`内容已在 web/src/data/npc.json 冻结，改动需双写`。

---

## 七、界面复刻要点

| Godot 里怎么做的 | Web 里怎么写 |
|---|---|
| `_to_vertical()` 一字一行 | `.slot { writing-mode: vertical-rl; text-orientation: upright; letter-spacing: .15em }` |
| 信纸槽位（锚定在 12 列格线上）| 用**百分比定位**在同一张 `letter.png` 上：`left: 14.069%`、`width: 6.1%`（数值抄 `scenes/letter.tscn` 的锚点） |
| 词库区 `ScrollContainer` | `overflow-y: auto` + 自定义滚动条样式 |
| 正文每槽 10 词自动换行 | `display: flex; flex-wrap: wrap; gap: 4px` |
| 九宫格按钮（`button_frame.png`）| `border-image: url(...) 12 fill / 12px stretch` |
| 拖拽预览（毛笔图 + 词文本）| dnd-kit `<DragOverlay>`，内放 `brush_cursor.png` + 文本 |
| 槽位校验 `_can_drop_data` | `useDroppable({ id, data: { category, bodySlot } })` + `onDragEnd` 里比对 |
| 正误高亮 / 判定弹窗 | CSS class + `<dialog>` 或自绘遮罩 |
| 系统光标 | `body { cursor: url(/ui/cursor_brush_tip.png) 32 7, auto }` |

**字体子集命令（实测 489 KB）**：

```bash
pyftsubset assets/fonts/hanchanlongcang.otf \
  --text-file=<(python tools/collect_chars.py) \
  --output-file=web/public/fonts/daishu.woff2 --flavor=woff2 \
  --layout-features='*' --no-hinting
```

> 汉字集合要包含 `scripts/` + `scenes/` 里出现的全部汉字（当前 **868** 个），
> 并把 ASCII 与中文标点一起带上；否则运行时会缺字回落到系统字体，书法观感立刻破功。

---

## 八、状态与规则

```ts
// store 只放"跨界面需要的东西"，判定逻辑保持纯函数
type GameState = {
  money: number;            // 起始 100
  day: number;              // 1..10
  completed: number[];      // 已完成的 npc_id（负数）
  npc: NPC | null;          // 当前委托
  answers: Answers;         // {salutation, slot1..3, signature}
  result: JudgeResult | null;
  muted: boolean;
};

// judge.ts：与 JudgeSystem.judge() 一一对应
judge(npc, answers): { code: 'WRONG'|'PERFECT'|'GOOD'|'NORMAL', fee: number, formatErrors: string[] }
```

- **判定优先级照抄**：有格式错误（留空或词不在词库）→ WRONG，`fee = -2 × 错误项数`，**不叠加底薪**；
  否则 5/5 → PERFECT（`base + bonus`）、4/5 → GOOD（`base + int(bonus × 0.7)`）、其余 → NORMAL（`int(base × 0.6)`）。
- **存档 schema**：字段以 `scripts/PlayerManager.gd::get_save_data()` 为准（执行时逐项核对，本方案不复制字段清单），
  `version` 沿用现有 `SAVE_VERSION = 1`；读到更高版本 → 拒绝并回新游戏（与 Godot 行为一致）。
- **破产/结束**：钱 < 0 立即结束；第 10 天结束按 ≥ 500 判成功。

---

## 九、测试与验收

| 层 | 工具 | 覆盖 |
|---|---|---|
| 单测 | Vitest | 四档判定与优先级、`base/bonus` 公式、存档往返、坏档/版本过新、内容不变量（正解⊆词库、同槽无重复、故事含三个正解、字体覆盖 868 字） |
| E2E | Playwright | 标题→新游戏→选委托→拖满 5 槽→提交→PERFECT 弹窗→返回主界面；中途返回不消耗委托；刷新后读档恢复 |
| 视觉 | Playwright `toHaveScreenshot` | 代写界面与 `docs/screenshots/ingame/letter_ui.png` 对比（允许阈值差异） |

**DoD（M2 完成判据）**：上述三层全绿 + 首次加载 ≤ 3 MB + 手机 Chrome 上能完成一单。

---

## 十、里程碑

| 里程碑 | 内容 | 估时 | 交付 |
|---|---|---|---|
| **M0** | 环境确认（node/npm）、导出 `npc.json`、Vitest 跑通内容不变量 | 0.5 天 | JSON + 单测 |
| **M1 竖切** | 代写界面 + 判定 + 存档（无标题/主界面，直接用固定 NPC） | 1–1.5 天 | 可拖拽演示页 |
| **M2 全流程** | 标题/序章/主界面/结局 + 音频 + 光标 + 静音 | 1.5–2 天 | 可玩全流程 |
| **M3 打磨** | 触屏适配、响应式、加载优化、视觉对比 | 1 天 | 候选发布版 |
| **M4 分发** | itch.io 页面（文案/截图/标签）、zip 产物、（可选）Tauri 套壳 | 0.5–1 天 | 线上链接 |

**总估时 4.5–6 天**（单人、无美术外包）。

---

## 十一、分发与后置项

- **itch.io**：`npm run build` → 把 `dist/` 压成 zip 上传（HTML5 项目，需勾选 "This file will be played in the browser"）。
  `vite.config.ts` 必须 `base: './'`，否则 itch.io 的嵌套路径会 404。
- **本地预览**：`npm run preview`（**不要双击 `dist/index.html`** —— ES module 在 `file://` 下会被 CORS 拦，
  必须走 HTTP；这是 Web 版最常见的"我这儿打不开"）。
- **Steam**（后置）：Tauri 2 套壳，`tauri.conf.json` 指向 `dist/`；打包体积远小于 Electron。
- **小游戏**（后置）：抖音/微信需要适配层（Canvas/WebGL 环境差异），属独立工程，不在本方案范围。

---

## 十二、风险与对策

| 风险 | 影响 | 对策 |
|---|---|---|
| 触屏拖拽手感差 | 手机上不好玩 | dnd-kit 用 Pointer Events；M3 阶段在真机测，必要时加"点选词语→点槽位"的备选交互 |
| 字体子集漏字 | 运行时缺字、观感破功 | 构建期用 `collect_chars.py` 自动收集 + 发布前跑一遍"全内容渲染无缺字"检查 |
| 内容双写漂移 | Godot 与 Web 答案不一致 | 冻结期只允许改 `npc.json`，`NPCManager.gd` 加注释指向它 |
| 长期双轨维护 | 两份代码同时改 | M3 验收后 Godot 版归档，不再同步 |
| 加载体积 | 首屏慢 | 字体 woff2 子集 489 KB；图片按需懒加载；`dist` 控制在 3 MB 内 |
| 本机工具链缺失 | 起不了工程 | 先跑 M0 的环境检查；`npm` 不可用就先解决包管理器 |

---

## 十三、回滚与共存

- 迁移期**不动 Godot 仓库结构**：Web 版放在 `repos/daishu/web/`，独立 `package.json`，
  `.gitignore` 加 `web/node_modules`、`web/dist`。
- 任一里程碑不达标 → 删除 `web/`，Godot 版不受影响（内容已在 git 历史里）。
- 反向回滚（Web → Godot）不需要：Godot 版始终可运行。

---

## 十四、执行前检查清单（M0 当日）

1. **工具链**：`node -v && npm -v`。本机 node 不在 PATH，需用 DSH 运行时路径或先装 Node LTS。

2. **内容导出**（干跑，不写文件）：

    ```powershell
    python tools\export_content.py --dry-run --stats
    ```

    期望：5 信型 × 3 槽 × 10 词、26 模板、称谓 25、落款 20。

3. **字体子集**（干跑）：

    ```powershell
    python tools\collect_chars.py | wc -m
    ```

    期望 ≥ 868 个汉字。

4. **现有 Godot 版仍绿**（作为对照基线）：

    ```powershell
    pwsh -File tools\run-godot.ps1 --headless --script res://tools/verify_content.gd
    pwsh -File tools\run-godot.ps1 --headless --script res://tools/verify_letter_layout.gd
    ```

> 本方案引用的 Godot 侧事实（词库规模、判定规则、锚点数值、字体字数）以
> `scripts/NPCManager.gd`、`scripts/JudgeSystem.gd`、`scenes/letter.tscn`、`tools/verify_content.gd` 为准；
> 执行时若这些文件已变，先更新本方案再动手。
