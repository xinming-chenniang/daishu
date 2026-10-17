extends Button

const BRUSH_CURSOR_PATH := "res://assets/images/ui/brush_cursor.png"

var category: String = ""   # "salutation" / "body" / "signature"
var body_slot: String = ""  # "slot1" / "slot2" / "slot3" for body

func _get_drag_data(_at_position: Vector2):
	if text == "":
		return null
	# 拖起时给一声木头轻叩（拿不到单例就静默跳过 —— --script 模式不注册 autoload）
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx("ui_click")
	var data := {
		"type": "word",
		"word": text,
		"category": category,
		"body_slot": body_slot,
	}
	set_drag_preview(build_drag_preview())
	return data

# 构建拖拽预览节点（与 _get_drag_data 分开，便于单测：直接调本函数不会触发拖拽引擎断言）
# 注：光标图在实际系统光标尺寸（16-32px）下会糊成一团墨点，所以只用在放得大的拖拽预览里。
func build_drag_preview() -> Control:
	var brush_tex: Texture2D = null
	if ResourceLoader.exists(BRUSH_CURSOR_PATH):
		brush_tex = load(BRUSH_CURSOR_PATH) as Texture2D

	if brush_tex != null:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var brush := TextureRect.new()
		brush.texture = brush_tex
		brush.custom_minimum_size = Vector2(72, 72)
		brush.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		brush.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(brush)

		var label := Label.new()
		label.text = text
		label.add_theme_color_override("font_color", Color(0.09, 0.08, 0.07))
		label.add_theme_color_override("font_outline_color", Color(0.99, 0.97, 0.91))
		label.add_theme_constant_override("outline_size", 4)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		return row

	var fallback := Label.new()
	fallback.text = text
	fallback.add_theme_color_override("font_color", Color.WHITE)
	fallback.add_theme_color_override("font_outline_color", Color.BLACK)
	fallback.add_theme_constant_override("outline_size", 2)
	return fallback

