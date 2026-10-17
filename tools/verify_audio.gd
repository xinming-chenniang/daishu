# 校验 UI 音效：4 个 wav 能加载、有非零时长、播放不报错、缺名字不崩
#
# 说明：--script 模式不注册 autoload（AI_PLAYBOOK 第 1 条），所以这里手动实例化
# AudioManager 并挂到 root 下，模拟真实的单例生命周期。
extends SceneTree

const AM_SCRIPT := preload("res://scripts/AudioManager.gd")
const EXPECT := ["ui_click", "paper_drop", "submit", "day_end"]

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	get_root().size = Vector2i(1152, 648)
	var ok := true

	var am = AM_SCRIPT.new()
	get_root().add_child(am)
	await process_frame

	print("=== 音效加载 ===")
	for sfx_name in EXPECT:
		var has: bool = am.has_sfx(sfx_name)
		print("  %-12s %s" % [sfx_name, "OK" if has else "缺失"])
		if not has:
			ok = false
	var missing: Array = am.missing_sfx()
	print("  missing_sfx() = %s" % str(missing))
	if missing.size() > 0:
		ok = false

	print("=== 时长与类型 ===")
	for sfx_name in EXPECT:
		if not am.has_sfx(sfx_name):
			continue
		var stream: AudioStream = am._streams[sfx_name]
		var length := stream.get_length()
		print("  %-12s %.3f s  %s" % [sfx_name, length, stream.get_class()])
		if length <= 0.0:
			print("     [!] 时长为 0，资源没真正导入")
			ok = false

	print("=== 播放（headless 用 dummy 音频驱动，只验调用链不报错）===")
	for sfx_name in EXPECT:
		am.play_sfx(sfx_name)
		await process_frame
		print("  played %s" % sfx_name)

	print("=== 未知名字必须静默跳过（不得报错/不得崩）===")
	am.play_sfx("不存在的音效")
	await process_frame
	print("  played <不存在> —— 已静默跳过")

	print("=== 播放器池 ===")
	print("  players = %d，轮转游标 = %d" % [am._players.size(), am._next])
	if am._players.size() < 2:
		print("     [!] 播放器池不足 2 个，连续音效会互相截断")
		ok = false

	print("=== 结论: ", "PASS" if ok else "FAIL", " ===")
	quit(0 if ok else 1)
