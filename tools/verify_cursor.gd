# 校验毛笔系统光标：素材存在/尺寸合规/透明底/尖端不透明/热点在范围内
#
# ⚠️ 边界说明：系统光标**不进视口截图**，--headless 下也不会真的绘制。
# 本脚本能证明的是"素材与设置调用没问题"，证明不了"看起来好看"—— 真机仍需人眼确认。
extends SceneTree

const HOTSPOT := Vector2(32, 7)
const MAX_SIZE := 128

var _fails: Array[String] = []


func _initialize() -> void:
	await process_frame  # --script 的 _initialize 早于 SceneTree 激活（AI_PLAYBOOK 第 21 条）

	var cm = get_root().get_node_or_null("CursorManager")
	_check(cm != null, "CursorManager 单例存在")
	if cm == null:
		_finish()
		return

	var tex: Texture2D = cm.cursor_texture()
	_check(tex != null, "光标贴图已加载")
	if tex == null:
		_finish()
		return

	var size := tex.get_size()
	print("  贴图尺寸：%s，热点：%s" % [size, cm.hotspot()])
	_check(size.x > 0 and size.y > 0, "尺寸非零")
	_check(size.x <= MAX_SIZE and size.y <= MAX_SIZE, "尺寸不超过 %d×%d" % [MAX_SIZE, MAX_SIZE])
	_check(size.x == size.y, "方形贴图（热点换算简单、缩放不变形）")

	var hs: Vector2 = cm.hotspot()
	_check(hs.x >= 0 and hs.y >= 0 and hs.x < size.x and hs.y < size.y, "热点在贴图范围内")

	var img: Image = tex.get_image()
	_check(img != null, "能取到像素数据")
	if img != null:
		_check(img.detect_alpha() != Image.ALPHA_NONE, "贴图带 alpha 通道（透明底）")
		var corner := img.get_pixel(0, 0)
		_check(corner.a < 0.05, "左上角透明（corner alpha=%.2f）" % corner.a)
		var tip := img.get_pixel(int(hs.x), int(hs.y))
		_check(tip.a > 0.3, "热点处有墨（alpha=%.2f）" % tip.a)
		var center := img.get_pixel(size.x / 2, size.y / 2)
		_check(center.a > 0.5, "笔肚不透明（alpha=%.2f）" % center.a)

	# 重复设置一次不应报错（引擎侧无 getter，无法断言状态）
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, hs)
	print("  再次调用 Input.set_custom_mouse_cursor 未报错")

	_finish()


func _finish() -> void:
	if _fails.is_empty():
		print("=== 结论: PASS ===")
		quit(0)
	else:
		print("=== 结论: FAIL（%d 项）===" % _fails.size())
		for f in _fails:
			print("  [!] ", f)
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  [OK] ", msg)
	else:
		print("  [FAIL] ", msg)
		_fails.append(msg)
