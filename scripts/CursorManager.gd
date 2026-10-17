extends Node
## 全局毛笔光标（单例，见 project.godot 的 [autoload]）。
##
## 为什么单独一个 autoload：光标是**全局状态**，跨场景不该重置；放在场景脚本里会
## 每进一个场景重设一次，还容易漏。这里只在启动时设一次。
##
## 素材 `assets/images/ui/cursor_brush_tip.png` 由 `tools/gen_cursor.py` 生成：
## 64×64、透明底、单一笔尖朝上、热点在尖端 (32, 7)。
## **不要**拿拖拽预览那张 `brush_cursor.png`（场景插画，缩到系统光标尺寸会糊）。
##
## ⚠️ 验证边界：系统光标不进视口截图，`--headless` 下也不会真的绘制。
## 所以回归脚本只能验"素材合格 + 设置调用不报错"（tools/verify_cursor.gd），
## 真机上还得人眼看一眼。

const CURSOR_PATH := "res://assets/images/ui/cursor_brush_tip.png"
## 热点＝笔尖位置（像素）。改素材尺寸时同步改这里。
const HOTSPOT := Vector2(32, 7)
## Godot 要求光标 ≤ 128×128（超出会被忽略或缩放出错）
const MAX_SIZE := 128

var _texture: Texture2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_texture = _load_cursor()
	if _texture == null:
		return
	Input.set_custom_mouse_cursor(_texture, Input.CURSOR_ARROW, HOTSPOT)


func _load_cursor() -> Texture2D:
	if not ResourceLoader.exists(CURSOR_PATH):
		push_warning("[CursorManager] 光标素材不存在：%s（先跑 `godot --headless --path . --import`）" % CURSOR_PATH)
		return null
	var tex := load(CURSOR_PATH) as Texture2D
	if tex == null:
		push_warning("[CursorManager] 光标素材加载失败：%s" % CURSOR_PATH)
		return null
	var sz := tex.get_size()
	if sz.x <= 0 or sz.y <= 0:
		push_warning("[CursorManager] 光标尺寸异常：%s" % sz)
		return null
	if sz.x > MAX_SIZE or sz.y > MAX_SIZE:
		push_warning("[CursorManager] 光标超过 %d×%d：%s（会被忽略或缩放）" % [MAX_SIZE, MAX_SIZE, sz])
	return tex


## 供探针断言
func cursor_texture() -> Texture2D:
	return _texture


func hotspot() -> Vector2:
	return HOTSPOT
