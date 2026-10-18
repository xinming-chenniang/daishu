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
var _drag_hover: bool = false   # 拖着词停在本槽位上方（能放）时高亮
# 用路径查找而不是裸全局名：--script 模式不注册 autoload（AI_PLAYBOOK 第 1 条）
var _audio: Node = null

## 拖拽悬停高亮用的边框色/线宽（比默认虚线更显眼，朱砂色）
const HOVER_BORDER_COLOR := Color(0.78, 0.33, 0.18, 0.95)
const HOVER_BORDER_WIDTH := 2.5

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
	_drag_hover = false
	if text_label:
		text_label.text = _to_vertical(placeholder)
		text_label.add_theme_color_override("font_color", PLACEHOLDER_COLOR)
	modulate = _base_modulate
	queue_redraw()

func is_drag_hover() -> bool:
	return _drag_hover

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
	var color := HOVER_BORDER_COLOR if _drag_hover else _border_color
	var width := HOVER_BORDER_WIDTH if _drag_hover else _border_width
	var pos: float = 0.0
	while pos < length:
		var start_point: Vector2 = from + normal * pos
		var end_pos: float = min(pos + _dash_length, length)
		var end_point: Vector2 = from + normal * end_pos
		draw_line(start_point, end_point, color, width)
		pos += _dash_length + _gap_length

func _can_drop_data(_at_position: Vector2, data) -> bool:
	var ok := _accepts(data)
	_set_drag_hover(ok)
	return ok

## 纯判定：不改变悬停状态（供 _can_drop_data / _drop_data 共用）
func _accepts(data) -> bool:
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

func _set_drag_hover(v: bool) -> void:
	if _drag_hover == v:
		return
	_drag_hover = v
	queue_redraw()

func _drop_data(_at_position: Vector2, data) -> void:
	if not _accepts(data):
		return
	var word := str(data.get("word", ""))
	_has_word = true
	_drag_hover = false
	if text_label:
		text_label.text = _to_vertical(word)
		text_label.add_theme_color_override("font_color", FILLED_COLOR)
	# 放下后给一次"落纸"反馈：先轻微染色再淡回原色。
	# （旧实现把 modulate 直接设成淡绿且**不还原**，已放的槽位会一直偏色）
	if is_inside_tree():
		modulate = Color(0.90, 1.0, 0.90)
		var tw := create_tween()
		tw.tween_property(self, "modulate", _base_modulate, 0.28).set_trans(Tween.TRANS_SINE)
	queue_redraw()
	if _audio != null:
		_audio.play_sfx("paper_drop")
	word_dropped.emit(slot_key, word)

func _on_mouse_entered() -> void:
	# 鼠标悬停时略微提亮，模拟纸张被触碰
	if not _drag_hover and modulate == _base_modulate:
		modulate = HOVER_TINT

func _on_mouse_exited() -> void:
	_set_drag_hover(false)
	if modulate != _base_modulate:
		modulate = _base_modulate
