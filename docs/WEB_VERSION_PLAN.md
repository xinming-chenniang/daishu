# 《代书》Web 版迁移方案（2026-10-18）

> **状态：方案存档，未执行。** 现在不改任何代码；等"触发条件"（§一）成立再按本方案执行。
> 本方案的每个数字都来自当前仓库实测（行数、词库规模、字体子集体积），估算项已标注"估"。
> 阅读顺序：**§二 分发策略 → §三 技术路线（由分发推导）→ §四 执行方案**。

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

## 二、分发策略

> 先定"给谁、在哪发、怎么验证"，技术路线才有判据。原则：**先让游戏存在 → 再让它被看到 →
> 最后才考虑放大**；用内容能力替代预算能力，用短反馈周期替代长运营周期。

### 2.1 阶段与 Go/No-Go

| 阶段 | 渠道 | 目标 | 成本 | 通过判据 |
|---|---|---|---|---|
| **P0 自测** | 本地 / 局域网 | 核心循环跑通 | 0 | 现有 10 个验证脚本等价物全绿 + 3 人试玩无卡死 |
| **P1 首发验证** | **itch.io（HTML5 项目）** | 验证"拖拽写信用"是否成立，收第一批真实反馈 | 0 上架费；页面 1 天 | ≥30 次游玩、≥5 条有效反馈、**至少 1 人打满 10 天** |
| **P2 曝光** | 内容账号（B站 / 抖音 / 小红书） | 积累受众与素材弹药 | 时间 | 3 条视频，其中 1 条播放 >1 万 |
| **P3 放大**（可选） | 抖音小游戏（或微信小游戏） | 用内容分发放大曝光 | 适配层 3–5 天（需重写视图层，见 §三） | 留存/分享数据达标才继续 |
| **P4 长线**（可选） | Steam（Tauri 套壳） | 沉淀付费与长线价值 | $100 上架费 + 愿望单运营 | 愿望单 ≥1000 再定档期 |

### 2.2 为什么是这个顺序

- **itch.io 零门槛、链接即玩**：本项目最贵的风险是"规则好不好玩"，不是技术。免费、无需下载、
  无需账号，能最快拿到真实反馈。
- **内容账号是弹药库**：本作的规则设计（信型、称谓、落款、辈分）本身就是内容钩子——
  "你能把'贺寿'写对吗"这种挑战式短视频，比任何买量都便宜。
- **小游戏后置**：小游戏环境没有 DOM，做它要重写视图层（§三·3.2）。**玩法没验证前不该付这笔钱。**
- **Steam 后置**：$100 只是门槛之一，真正门槛是内容体量与愿望单；它要的是"完整版"，不是早期验证。

### 2.3 每个阶段的具体动作

**P1（itch.io）**

1. 构建产物 `dist/` 压成 zip，上传为"HTML5 项目"，勾选 *This file will be played in the browser*。
2. 页面当营销页写：标题图 + 前两行讲清"你是明代代笔先生，10 天攒 500 文"；
   **标签（Tags）就是分发渠道**：`historical`、`narrative`、`drag-and-drop`、`point-and-click`、
   `short`、`indie`、`singleplayer`、`paper-like`。
3. 封面/截图用现有素材（`docs/screenshots/ingame/letter_ui.png` 可直接当一张）。
4. 发布后去 r/IndieDev、r/PlayMyGame、相关 Discord **以"开发日志/设计挑战"的形式**分享，不丢裸链接。

**P2（内容账号）**

1. 选题池：三类信型怎么写、称谓的辈分讲究、"蒙对一次有多难"（词库 10×10×10×5 的组合）。
2. 形式：15 秒切片（拖拽落词 → 判定弹窗的爽感）+ 30–60 秒规则讲解。
3. 指标按天看：一条没爆就换选题，爆了就顺着做成系列。

**P3（小游戏，可选）**

- 抖音：内容即分发，算法不看公司规模；但**iOS 端 WebGL 性能约为原生 1/3、内存限制严格**，
  需要资源分包——这是构建层面的工作，玩法代码不动（前提：§三·3.2 的分层做到了）。
- 微信：社交关系链是平台资产，不买量难有自然量；作为"抖音验证有留存后"的补充渠道。

**P4（Steam，可选）**

- Tauri 2 打原生壳（系统 WebView），`dist/` 直接塞进去；后续接 Steam 成就/云存档。
- 发布前数月开始攒愿望单（1 万被视为 modest success 的起点）。

### 2.4 明确不做

- **不做买量**：个人开发者 ROI 算不过来（有"烧掉 43 万后关停"的反面案例）。
- **不同时上多平台**：维护成本翻倍、反馈也分散。
- **不做原生手游**：与 Web/小游戏路线冲突。

---

## 三、技术路线：每一条都由分发策略推导

### 3.1 分发需求 → 技术决定

| 分发需求（§二） | 硬约束 | 技术决定 | 落点 |
|---|---|---|---|
| itch.io 网页即玩 | 纯静态、无后端、相对路径、首屏小 | Vite 静态构建；`base: './'`；**全程无服务端**；字体子集 489 KB；存档走 IndexedDB | §六、§八、§九 |
| 手机浏览器点链接就玩 | 触屏拖拽、响应式、不能依赖 hover | dnd-kit **PointerSensor**（一套代码同时吃鼠标/触屏）；流式布局，不把 1152×648 硬缩放；额外提供"点词 → 点槽位"备选交互 | §八 |
| 内容账号要录屏/切片 | 画面稳定、可复现 | 设计画幅 1152×648 居中；保留"固定种子截图"能力（对应现有 `capture_scene --seed`） | §八 |
| 分享卡片要好看 | 静态 OG meta | `index.html` 写死 OG 图/标题/描述（复用现有结局图） | §十二 |
| 抖音/微信小游戏（P3） | **小游戏环境没有 DOM**；iOS 内存紧、WebGL 约为原生 1/3 | **规则层零 DOM**：`judge / generate / economy / save` 全为纯 TS；视图层可整体替换；资源分包 | §三·3.2、§六 |
| Steam（P4） | 需要原生壳、后续成就/云存档 | **Tauri 2**（系统 WebView，体积远小于 Electron）；存档先 IndexedDB，后接 Steam Cloud | §十二 |
| 长期改内容 | 内容与代码分离、可校验 | `npc.json` + 构建期校验（对应 `verify_content` 的不变量） | §七 |

### 3.2 关键分叉：DOM 还是 Canvas（必须先决定）

| 方案 | 适合 | 不适合 | 现在/将来的代价 |
|---|---|---|---|
| **DOM/CSS（本方案选它）** | Web、itch.io、手机浏览器；竖排文字与纸张排版天然合适 | **小游戏环境没有 DOM** | 若做 P3，需重写视图层（估 1–2 天/界面） |
| Canvas（PixiJS / Phaser） | 小游戏、原生观感一致 | 文本排版、滚动、无障碍都要自己实现 | 现在多花 1–2 天，且 Web 端体验不如 DOM |

**决定：P1/P2 用 DOM/CSS。** 理由：先验证玩法，而"纸张 + 文字 + 拖拽"是 DOM 的最短路径；
用 Canvas 反而要自己实现竖排文本与滚动。

**但架构上强制分层**：

```
core/  ← 纯 TS：判定、生成、经济、存档。零 DOM 依赖，可单测，P3 换渲染层时不动
view/  ← React + DOM：只做渲染与交互
```

这就是"技术路线由分发策略决定"的具体落点——**P3 的代价被压缩到"换 view"**，而不是"重写游戏"。

### 3.3 选型表（含与分发的关系）

| 层 | 选择 | 为什么（对应哪条分发需求） |
|---|---|---|
| 构建 | **Vite 5 + TypeScript** | 纯静态产物可直接 zip 上传 itch.io；`base:'./'` 解决子路径 404 |
| UI | **React 18** | 为了 dnd-kit 的成熟绑定；换 Svelte 也可，core 不受影响 |
| 拖拽 | **dnd-kit** | 官方支持触屏与键盘 → 满足"手机分享链接能玩" |
| 状态 | **Zustand** | 小而够用；规则层不依赖 React，便于单测与将来换视图 |
| 存档 | **idb-keyval**（IndexedDB） | 无后端 → 只能客户端存储；容量远大于 localStorage |
| 样式 | **CSS Modules** | 竖排/纸纹/九宫格全靠 CSS，零运行时 |
| 字体 | **hanchanlongcang 子集** | 首屏 ≤3 MB 预算里字体是大头：4.05 MB → **489 KB**（实测） |
| 音频 | **Howler.js** | 复用现有 wav；处理移动端自动播放限制 |
| 单测 | **Vitest** | core 是纯函数，比 Godot `--script` 更好测 |
| E2E | **Playwright** | 拖拽、存档往返、截图对比 |
| 桌面壳 | **Tauri 2**（P4） | Steam 要求的原生壳；体积比 Electron 小一个量级 |

---

## 四、结论摘要

- **可以不用引擎**：本作是 UI 驱动（纸张、竖排文字、拖拽落词、规则判定），DOM/CSS 比引擎 UI 更自然。
- **分发决定路线**：P1 要"链接即玩" → 必须纯静态 Web；P3 要小游戏 → 必须 core/view 分层；
  P4 要 Steam → Tauri 套壳。**这些决定都不是技术偏好，而是分发倒推的。**
- **但不要现在就重写**：Godot 版已有 1614 行 GDScript、6 个场景、10 个验证脚本，
  且刚完成内容扩充（正文 150 个词位、26 条模板）。**保持 Godot 为唯一真源，直到 Web 版达到等价。**
- **推荐路径**：先做 **1 天竖切**（M1：代写界面 + 判定 + 存档），拿去 itch.io 收反馈；
  手感成立再走 M2–M4；不成立就停在 M1，损失一天。

---

## 五、目标与非目标

### 目标

1. 浏览器打开即玩，桌面/手机均可（鼠标 + 触屏）。
2. 玩法、规则、数值、内容与 Godot 版**逐项等价**（以 `NPCManager` / `JudgeSystem` / `PlayerManager` 为准）。
3. 首次加载 **≤ 3 MB**（字体子集 489 KB + 代码 + 图片，gzip 后更小）。
4. 存档可靠：刷新/关标签页不丢进度，坏档回落新游戏。
5. 构建产物 `dist/` 可直接上传 itch.io（zip 解压即玩）。
6. **P1 能上线**：有页面文案、截图、标签与可玩链接。

### 非目标（本期不做）

- 微信/抖音小游戏适配（P3；且必须先把 core/view 分层做出来，见 §三·3.2）。
- Steam 打包（P4，Tauri）。
- 多语言、账号系统、云存档、排行榜。
- 重做美术：现有 PNG 背景/头像/九宫格素材直接复用。
- 移植 Godot 的 `_draw` 虚线槽位效果——改用 CSS `border` + `background-image` 更简单。

---

## 六、工程结构

```
web/
├─ index.html                 # 含 OG meta（分享卡片）
├─ vite.config.ts             # base: './'（itch.io 子路径必需）
├─ package.json
├─ public/
│  ├─ bg/  avatars/  ui/  audio/      # 直接复制现有素材
│  └─ fonts/daishu.woff2              # 子集产物
├─ src/
│  ├─ main.tsx
│  ├─ core/                   # ★ 纯 TS，零 DOM（P3 换渲染层时不动）
│  │  ├─ types.ts             # NPC / Answers / JudgeResult
│  │  ├─ economy.ts           # 起始 100 / 目标 500 / 摊位 10 / 两个公式
│  │  ├─ judge.ts             # 四档判定与计费
│  │  ├─ generate.ts          # 读 npc.json 生成 NPC
│  │  └─ save.ts              # IndexedDB + schemaVersion
│  ├─ view/                   # React + DOM（P3 时替换这一层）
│  │  ├─ screens/             # Title / Prologue / Main / Letter / End
│  │  ├─ components/          # PaperSlot / WordButton / WordScroll / ResultDialog
│  │  └─ styles/              # *.module.css + global.css
│  └─ data/npc.json           # 由 tools/export_content.py 从 NPCManager.gd 导出
└─ tests/
   ├─ core/                   # Vitest：判定/经济/存档/内容不变量
   └─ e2e/                    # Playwright：拖拽、存档、截图对比
```

---

## 七、数据迁移（内容只迁一次，之后以 JSON 为真源）

1. 写 `tools/export_content.py`：解析 `scripts/NPCManager.gd` 的五组常量
   （`BODY_POOLS` / `SALUTATION_POOL` / `SIGNATURE_POOL` / `STORY_TEMPLATES` / `SLOT_HINTS`），
   输出 `web/src/data/npc.json`。**不要手抄**：150 个词位 + 26 条模板手抄必错。
2. 导出后立刻用同一套不变量校验（见 §十），与 `verify_content` 等价。
3. 规则常量（起始 100、目标 500、摊位 10/天、`base = 12 + floor((day-1)/3)`、
   `bonus = 8 + (day-1)`、判定优先级 WRONG > PERFECT > GOOD > NORMAL）写进 `core/economy.ts`，
   **逐条对照 `JudgeSystem.gd` / `PlayerManager.gd`**。
4. 迁移完成后在 Godot 侧加注释：`内容已在 web/src/data/npc.json 冻结，改动需双写`。

---

## 八、界面复刻要点

| Godot 里怎么做的 | Web 里怎么写 |
|---|---|
| `_to_vertical()` 一字一行 | `.slot { writing-mode: vertical-rl; text-orientation: upright; letter-spacing: .15em }` |
| 信纸槽位（锚定在 12 列格线上）| 百分比定位在同一张 `letter.png` 上：`left: 14.069%`、`width: 6.1%`（数值抄 `scenes/letter.tscn` 的锚点，别重算） |
| 词库区 `ScrollContainer` | `overflow-y: auto` + 自定义滚动条 |
| 正文每槽 10 词自动换行 | `display: flex; flex-wrap: wrap; gap: 4px` |
| 九宫格按钮（`button_frame.png`）| `border-image: url(...) 12 fill / 12px stretch` |
| 拖拽预览（毛笔图 + 词文本）| dnd-kit `<DragOverlay>`，内放 `brush_cursor.png` + 文本 |
| 槽位校验 `_can_drop_data` | `useDroppable({ id, data: { category, bodySlot } })` + `onDragEnd` 比对 |
| 正误高亮 / 判定弹窗 | CSS class + `<dialog>` 或自绘遮罩 |
| 系统光标 | `body { cursor: url(/ui/cursor_brush_tip.png) 32 7, auto }` |

**响应式（手机）**：设计画幅 1152×648 用 CSS `aspect-ratio` 容器 + `transform: scale()` 等比缩放；
触屏下把"拖拽"降级为"点词选中 → 点槽位落词"（dnd-kit 的 KeyboardSensor 可复用同一套焦点逻辑）。

**字体子集命令（实测 489 KB）**：

```bash
pyftsubset assets/fonts/hanchanlongcang.otf --text-file=chars.txt \
  --output-file=web/public/fonts/daishu.woff2 --flavor=woff2 \
  --layout-features='*' --no-hinting
```

汉字集合必须包含 `scripts/` + `scenes/` 里出现的全部汉字（当前 **868** 个），外加 ASCII 与中文标点；
漏字会回落到系统字体，书法观感立刻破功。

---

## 九、状态与规则

```ts
// core/types.ts（节选）
type JudgeCode = 'WRONG' | 'PERFECT' | 'GOOD' | 'NORMAL';

// core/judge.ts：与 JudgeSystem.judge() 一一对应，纯函数
judge(npc: NPC, answers: Answers): { code: JudgeCode; fee: number; formatErrors: string[] }
```

- **判定优先级照抄**：有格式错误（留空或词不在词库）→ WRONG，`fee = -2 × 错误项数`，**不叠加底薪**；
  否则 5/5 → PERFECT（`base + bonus`）、4/5 → GOOD（`base + int(bonus × 0.7)`）、其余 → NORMAL（`int(base × 0.6)`）。
- **存档 schema**：字段以 `scripts/PlayerManager.gd::get_save_data()` 为准（执行时逐项核对，
  本方案不复制字段清单），`version` 沿用 `SAVE_VERSION = 1`；读到更高版本 → 拒绝并回新游戏。
- **破产/结束**：钱 < 0 立即结束；第 10 天结束按 ≥ 500 判成功。
- **store 只放跨界面状态**：money / day / completed / npc / answers / result / muted。

---

## 十、测试与验收

| 层 | 工具 | 覆盖 |
|---|---|---|
| 单测 | Vitest | 四档判定与优先级、`base/bonus` 公式、存档往返、坏档/版本过新、内容不变量（正解⊆词库、同槽无重复、故事含三个正解、字体覆盖 868 字） |
| E2E | Playwright | 标题→新游戏→选委托→拖满 5 槽→提交→PERFECT→返回主界面；返回不消耗委托；刷新后读档恢复；**手机视口下用点选交互完成一单** |
| 视觉 | Playwright `toHaveScreenshot` | 代写界面与 `docs/screenshots/ingame/letter_ui.png` 对比（允许阈值差异） |
| 分发 | 手工 | `dist/` zip 上传 itch.io 后，**换一台没有本地环境的设备**打开链接，能玩到第 10 天 |

**DoD（M2 完成判据）**：三层自动化全绿 + 首屏 ≤ 3 MB + 手机 Chrome 能完成一单。

---

## 十一、里程碑

| 里程碑 | 内容 | 估时 | 交付 |
|---|---|---|---|
| **M0** | 环境确认（node/npm）、导出 `npc.json`、Vitest 跑通内容不变量 | 0.5 天 | JSON + 单测 |
| **M1 竖切** | 代写界面 + 判定 + 存档（固定 NPC，无标题/主界面） | 1–1.5 天 | 可拖拽演示页 |
| **M2 全流程** | 标题/序章/主界面/结局 + 音频 + 光标 + 静音 | 1.5–2 天 | 可玩全流程 |
| **M3 打磨** | 触屏降级交互、响应式、加载优化、视觉对比 | 1 天 | 候选发布版 |
| **M4 上线 P1** | itch.io 页面（文案/截图/标签）、zip、OG meta、发一条开发日志 | 0.5–1 天 | 线上链接 |
| **M5（可选）** | P3 小游戏：重写 view 为 Canvas/Pixi + 平台适配层 | 3–5 天 | 小游戏包 |

**M0–M4 合计 4.5–6 天**（单人、无美术外包）。

---

## 十二、分发执行清单（P1 上线当天）

1. `npm run build` → 检查 `dist/` 无绝对路径（`base:'./'`）。
2. 压缩 `dist/` 为 zip → itch.io 新建项目 → Kind: HTML → 上传 → 勾选浏览器运行。
3. 页面填写：
   - 标题：代书 / *Daishu — Letters for Hire*
   - 前两行：**"你是明代街头的代笔先生。10 天，替 30 个人写信，攒够 500 文进京赶考。"**
   - 标签：`historical` `narrative` `drag-and-drop` `point-and-click` `short` `indie` `singleplayer`
   - 封面：用 `letter_ui.png`；再补 2 张（主界面、判定弹窗）
4. 本地必须 `npm run preview` 验收（**不要双击 `dist/index.html`**：ES module 在 `file://` 下会被 CORS 拦）。
5. 发布后：r/IndieDev、r/PlayMyGame、Discord 社群，以"开发日志/设计挑战"形式分享。
6. 记录指标：游玩次数、平均时长、完成第 10 天的比例、反馈原文。

**Steam（P4）**：Tauri 2 套壳 → `tauri.conf.json` 指向 `dist/` → 打包 `msi`/`exe` → 上传 Steamworks；
账号、成就、云存档按需接。

---

## 十三、风险与对策

| 风险 | 影响 | 对策 |
|---|---|---|
| 触屏拖拽手感差 | 手机上不好玩 | PointerSensor + "点词→点槽"降级；M3 真机测 |
| 字体子集漏字 | 运行时缺字、观感破功 | `collect_chars.py` 自动收集 + 发布前全内容渲染检查 |
| 内容双写漂移 | Godot/Web 答案不一致 | 冻结期只改 `npc.json`；`NPCManager.gd` 加注释指向它 |
| 长期双轨维护 | 两份代码同时改 | M2 验收后 Godot 版归档，不再同步内容 |
| 加载体积 | 首屏慢 | 字体 489 KB + 图片懒加载 + `dist` 控制在 3 MB 内 |
| **P3 需换渲染层** | 小游戏不支持 DOM | 已用 core/view 分层把代价压到"换 view"（估 1–2 天/界面） |
| 本机工具链缺失 | 起不了工程 | M0 先跑环境检查；`npm` 可用性本会话**未验证** |

---

## 十四、回滚与共存

- 迁移期**不动 Godot 仓库结构**：Web 版放 `repos/daishu/web/`，独立 `package.json`；
  `.gitignore` 加 `web/node_modules`、`web/dist`。
- 任一里程碑不达标 → 删除 `web/`，Godot 版不受影响（内容在 git 历史里）。
- 反向回滚（Web → Godot）不需要：Godot 版始终可运行。

---

## 十五、执行前检查清单（M0 当日）

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

---

## 十六、不迁移的东西（避免照搬）

| Godot 里的实现 | 为什么不搬 | Web 替代 |
|---|---|---|
| `letter_slot.gd` 的 `_draw` 虚线边框 | CSS 一行能做，且更好维护 | `border: 2px dashed` + 动画 |
| `daishu_theme.tres` 全局主题 | Web 用 CSS 变量 + 组件样式 | `:root { --paper: ... }` |
| `AudioManager` 交叉淡化播放器池 | Howler 自带 fade + loop | `howl.fade()` |
| `FontFallback` 挂系统字体兜底 | 子集覆盖全部用字后不需要 | 缺失即构建期报错 |
| `NPCManager` / `PlayerManager` 这类 autoload 单例 | Web 里没有"全局节点"，用 store + 纯函数更可测 | `core/generate.ts` + Zustand store |
