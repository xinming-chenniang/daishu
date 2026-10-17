extends Panel

signal word_dropped(slot_key: String, word: String)

@export var slot_key: String = ""           # "salutation", "body_slot1" 等
@export var expected_category: String = ""  # "salutation" / "body" / "signature"
@export var body_slot: String = ""          # "slot1" / "slot2" / "slot3" for body
@export var placeholder: String = "______"

@onready var text_label: Label = $TextLabel

var _base_modulate: Color

var _border_color: Color = Color(0.36, 0.26, 0.16, 0.55)
var _border_width: float = 1.5
var _dash_length: float = 8.0
var _gap_length: float = 4.0

# 空槽占位提示（浅褐，弱化）与已放词的墨色，两者要能一眼区分
const PLACEHOLDER_COLOR := Color(0.42, 0.31, 0.18, 0.55)
const FILLED_COLOR := Color(0.06, 0.06, 0.05, 1.0)
const HOVER_TINT := Color(1.06, 1.05, 0.98)

var _has_word: bool = false
# 用路径查找而不是裸全局名：--script 模式不注册 autoload（AI_PLAYBOOK 第 1 条）
var _audio: Node = null

func _ready() -> void:
	_audio = get_node_or_null("/root/AudioManager")
	_base_modulate = modulate
	if text_label:
		text_label.text = _to_vertical(placeholder)
		text_label.add_theme_color_override("font_color", PLACEHOLDER_COLOR)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(_on_resized)
	queue_redraw()

func clear_slot() -> void:
	_has_word = false
	if text_label:
		text_label.text = _to_vertical(placeholder)
		text_label.add_theme_color_override("font_color", PLACEHOLDER_COLOR)
	modulate = _base_modulate
	queue_redraw()

# 竖排：每字一行，自上而下
func _to_vertical(s: String) -> String:
	if s.is_empty():
		return ""
	var lines: PackedStringArray = []
	for i in range(s.length()):
		lines.append(s[i])
	return "\n".join(lines)

func _on_resized() -> void:
	queue_redraw()

func _draw() -> void:
	# 已放词的槽位不再画虚线：虚线是"这里可以放东西"的提示，放好了就该收掉
	if _has_word:
		return
	var r := Rect2(Vector2.ZERO, size)
	var top_left := r.position
	var top_right := r.position + Vector2(r.size.x, 0)
	var bottom_left := r.position + Vector2(0, r.size.y)
	var bottom_right := r.position + Vector2(r.size.x, r.size.y)

	_draw_dashed_line(top_left, top_right)
	_draw_dashed_line(top_right, bottom_right)
	_draw_dashed_line(bottom_right, bottom_left)
	_draw_dashed_line(bottom_left, top_left)

func _draw_dashed_line(from: Vector2, to: Vector2) -> void:
	var dir: Vector2 = to - from
	var length: float = dir.length()
	if length <= 0.0:
		return
	var normal: Vector2 = dir / length
	var pos: float = 0.0
	while pos < length:
		var start_point: Vector2 = from + normal * pos
		var end_pos: float = min(pos + _dash_length, length)
		var end_point: Vector2 = from + normal * end_pos
		draw_line(start_point, end_point, _border_color, _border_width)
		pos += _dash_length + _gap_length

func _can_drop_data(_at_position: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if data.get("type", "") != "word":
		return false
	var cat := str(data.get("category", ""))
	if cat != expected_category:
		return false
	if expected_category == "body":
		# 正文需要匹配具体哪个 slot
		return str(data.get("body_slot", "")) == body_slot
	return true

func _drop_data(_at_position: Vector2, data) -> void:
	if not _can_drop_data(_at_position, data):
		return
	var word := str(data.get("word", ""))
	_has_word = true
	if text_label:
		text_label.text = _to_vertical(word)
		text_label.add_theme_color_override("font_color", FILLED_COLOR)
	# 放下后给予轻微“选中”反馈
	modulate = Color(0.95, 1.0, 0.95)
	queue_redraw()
	if _audio != null:
		_audio.play_sfx("paper_drop")
	word_dropped.emit(slot_key, word)

func _on_mouse_entered() -> void:
	# 鼠标悬停时略微提亮，模拟纸张被触碰
	if modulate == _base_modulate:
		modulate = HOVER_TINT

func _on_mouse_exited() -> void:
	if modulate != _base_modulate:
		modulate = _base_modulate
