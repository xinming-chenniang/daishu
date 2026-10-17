extends Control
## NPC 头像（真肖像 + 程序化"名帖牌"兜底）
##
## 现状（2026-10-18 核对）：`assets/images/ui/avatars/<关系>.png` 已放真肖像，
## `set_relation()` 会自动加载；**素材缺失时**才回落到下面的程序化名帖牌（圆底 + 关系字）。
## 所以本文件现在有两套画法：有贴图 → 贴图 + 右下角关系色角标；无贴图 → 名帖牌。
##
## 早期注释里"本机没有图像生成工具、真图只能人用豆包生成"的说法已过时 ——
## 那批图已于 2026-10-13 由生成工具链补齐（见 docs/ART_NPC_AVATARS.md）。
## 视觉设计（取色全部落在 docs/ART_PLAN.md §二 的户内色板，不引入新颜色）：
##   圆形"名帖"底 + 双环描边 + 一个书法体汉字。
##
## 汉字取 **关系**（父母/子女/夫妻/兄弟/朋友）而不是姓氏，理由见下 —— 注意
## **不要**用"关系比姓氏更不容易重复"来论证它，那是错的：
##   实测（tools/verify_avatar.gd）：三名委托人里
##     姓氏撞的概率 38.8%（7 个姓）、关系撞的概率 52.0%（5 个关系）—— 关系反而更容易撞；
##     而 `姓名` 有 49 种组合，撞名概率仅约 5.9%，且姓名本来就印在按钮上。
##   真正成立的理由有两条：
##     ① **关系是玩法信息**：称谓池与落款池都按关系划分（见 NPCManager.SALUTATION_POOL /
##        SIGNATURE_POOL），玩家读关系是有用的，读姓氏没有；
##     ② **字与色的集合小且受控**：5 个字 + 5 个色，不会出现字库缺字
##        （这 5 个字都在项目已验证的 594 字覆盖内），也不必随姓名池扩张而加素材。
##   所以头像的职责是"一眼给出关系类别"，**不是**唯一标识某个人 —— 唯一标识交给姓名。
##
## 用法：
##   var av := NPCAvatar.new()
##   av.setup(npc)          # 传 NPC 字典
##   hbox.add_child(av)

const FONT_PATH := "res://assets/fonts/hanchanlongcang.otf"
## 肖像目录：按 `<关系>.png` 放这里即自动生效（缺失则回落程序化名帖牌）
const AVATAR_DIR := "res://assets/images/ui/avatars/"
const SIZE := 44.0
const FONT_SIZE := 26

# 关系 → 字（5 个值必然互斥，绝不撞）
const RELATION_GLYPH := {
	"父母": "父",
	"子女": "子",
	"夫妻": "夫",
	"兄弟": "兄",
	"朋友": "友",
}

# 关系 → 主色（取自 ART_PLAN §二：木构 #9c5424 / #b46c3c、朱砂 #a43c2c、户外 #6c846c / #846c54）
const RELATION_COLOR := {
	"父母": Color(0.612, 0.329, 0.141),   # #9c5424 木构深
	"子女": Color(0.643, 0.235, 0.173),   # #a43c2c 朱砂
	"夫妻": Color(0.706, 0.424, 0.235),   # #b46c3c 木构浅
	"兄弟": Color(0.424, 0.518, 0.424),   # #6c846c 户外绿
	"朋友": Color(0.518, 0.424, 0.329),   # #846c54 远景褐
}

const FALLBACK_COLOR := Color(0.518, 0.424, 0.329)   # 关系未知时用"朋友"的褐色
const RING_INNER := Color(0.16, 0.13, 0.09, 0.55)    # 内侧暗环，让圆在浅底上立起来
const RING_OUTER := Color(0.99, 0.965, 0.902, 0.95)  # 外侧亮边，与宣纸底呼应
const INK := Color(0.99, 0.965, 0.902)               # 字用宣纸色，压在深色圆上

var _glyph: String = "客"
var _color: Color = FALLBACK_COLOR
var _font: Font = null
var _relation: String = ""
var _texture: Texture2D = null      ## 关系对应的肖像贴图；为 null 时回落到程序化名帖牌
var _texture_path: String = ""      ## 由 setup(npc) 的 avatar 字段指定（可空）


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	# 头像不接受鼠标事件，点击应由整行的按钮处理
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as Font
	queue_redraw()


## 从 NPC 字典配置头像。缺 `relation` 字段时回退为默认字与色（不报错、不崩）。
## `avatar` 字段可给肖像路径；给了就加载，加载不到则静默回落到程序化名帖牌。
func setup(npc: Dictionary) -> void:
	var av := str(npc.get("avatar", ""))
	if av != "" and ResourceLoader.exists(av):
		_texture = load(av) as Texture2D
		_texture_path = av
	else:
		_texture = null
		_texture_path = ""
	set_relation(str(npc.get("relation", "")))


func set_relation(relation: String) -> void:
	_relation = relation
	if RELATION_GLYPH.has(relation):
		_glyph = RELATION_GLYPH[relation]
	else:
		_glyph = "客"
	_color = RELATION_COLOR.get(relation, FALLBACK_COLOR)
	# 未显式给 avatar 时，按关系找默认肖像：assets/images/ui/avatars/<关系>.png
	if _texture == null and relation != "":
		var p := "%s%s.png" % [AVATAR_DIR, relation]
		if ResourceLoader.exists(p):
			_texture = load(p) as Texture2D
	queue_redraw()


func get_relation() -> String:
	return _relation


## 供测试断言用：当前显示的字与颜色
func get_glyph() -> String:
	return _glyph


func get_color() -> Color:
	return _color


func _draw() -> void:
	var c := Vector2(SIZE, SIZE) * 0.5
	var r := SIZE * 0.5 - 1.0

	# 有真肖像时：画贴图 + 右下角一个小的关系色角标（保辨识度）
	if _texture != null:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), false)
		# 角标：主色圆 + 关系字，直径约 SIZE*0.42
		var br := SIZE * 0.21
		var bc := Vector2(SIZE - br - 0.5, SIZE - br - 0.5)
		draw_circle(bc, br, RING_OUTER, true, -1.0, true)
		draw_circle(bc, br - 1.0, _color, true, -1.0, true)
		if _font != null:
			var fs := int(FONT_SIZE * 0.52)
			var ts2 := _font.get_string_size(_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var asc2 := _font.get_ascent(fs)
			var desc2 := _font.get_descent(fs)
			draw_string(_font, Vector2(bc.x - ts2.x * 0.5, bc.y + (asc2 - desc2) * 0.5),
				_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
		return

	# 无真肖像时：走原来的"名帖牌"（亮外圈 → 主色圆 → 暗内环）
	draw_circle(c, r, RING_OUTER, true, -1.0, true)
	draw_circle(c, r - 1.5, _color, true, -1.0, true)
	draw_circle(c, r - 1.5, RING_INNER, false, 1.5, true)

	if _font == null:
		return
	# 汉字居中：draw_string 的 pos 是**基线左端**，所以按字符实际尺寸居中
	var ts := _font.get_string_size(_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var ascent := _font.get_ascent(FONT_SIZE)
	var descent := _font.get_descent(FONT_SIZE)
	var pos := Vector2(c.x - ts.x * 0.5, c.y + (ascent - descent) * 0.5)
	draw_string(_font, pos, _glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)


## ── 替换路径（真素材到位后）──────────────────────────────────────────────
## 1. 把 64×64 像素画头像按 `<关系>.png` 放进 `assets/images/ui/avatars/`
##    （或在 NPCManager 里给每个 NPC 填 `avatar` 路径）。
## 2. 本脚本改为：有 `avatar` 时加载贴图并 `draw_texture_rect` 到 44×44，无则回落到当前画法。
## 3. 接口保持不变（`setup(npc)` / `set_relation()`），main.gd 不用动。
