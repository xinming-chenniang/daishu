# 校验音频层：4 个 UI 音效 + 2 条 BGM 能加载/播放，静音开关生效且持久化
#
# 说明：`--script` 的 `_initialize()` 早于 SceneTree 激活（AI_PLAYBOOK 第 21 条），
# 所以先 await 一帧；优先用 autoload 实例，拿不到再手动挂一个。
extends SceneTree

const AM_SCRIPT := preload("res://scripts/AudioManager.gd")
const SFX_EXPECT := ["ui_click", "paper_drop", "submit", "day_end"]
const BGM_EXPECT := ["bgm_title", "bgm_letter"]

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	get_root().size = Vector2i(1152, 648)
	await process_frame

	var am = get_root().get_node_or_null("AudioManager")
	if am == null:
		am = AM_SCRIPT.new()
		get_root().add_child(am)
		await process_frame
	var ok := true

	print("=== 音效加载 ===")
	for sfx_name in SFX_EXPECT:
		var has: bool = am.has_sfx(sfx_name)
		print("  %-12s %s" % [sfx_name, "OK" if has else "缺失"])
		if not has:
			ok = false
	print("  missing_sfx() = %s" % str(am.missing_sfx()))
	if am.missing_sfx().size() > 0:
		ok = false

	print("=== 音效时长 ===")
	for sfx_name in SFX_EXPECT:
		if not am.has_sfx(sfx_name):
			continue
		var stream: AudioStream = am._streams[sfx_name]
		var length := stream.get_length()
		print("  %-12s %.3f s  %s" % [sfx_name, length, stream.get_class()])
		if length <= 0.0:
			print("     [!] 时长为 0，资源没真正导入")
			ok = false

	print("=== BGM 加载 ===")
	for bgm_name in BGM_EXPECT:
		var has: bool = am.has_bgm(bgm_name)
		print("  %-12s %s" % [bgm_name, "OK" if has else "缺失"])
		if not has:
			ok = false
	if am.missing_bgm().size() > 0:
		ok = false
	for bgm_name in BGM_EXPECT:
		if am.has_bgm(bgm_name):
			var length: float = am._music_streams[bgm_name].get_length()
			print("  %-12s %.1f s（循环用 finished 续播）" % [bgm_name, length])
			if length < 5.0:
				print("     [!] 时长异常，可能不是完整循环")
				ok = false

	print("=== 播放调用链（headless 用 dummy 音频驱动）===")
	for sfx_name in SFX_EXPECT:
		am.play_sfx(sfx_name)
		await process_frame
		print("  played %s" % sfx_name)
	am.play_sfx("不存在的音效")
	print("  played <不存在> —— 已静默跳过")

	am.play_music("bgm_title")
	await process_frame
	print("  play_music(bgm_title) → current_music = '%s'" % am.current_music())
	if am.current_music() != "bgm_title":
		print("     [!] current_music 不对")
		ok = false
	var before: String = am.current_music()
	am.play_music("bgm_title")   # 同一条应 no-op
	if am.current_music() != before:
		print("     [!] 重复播同一条时状态被改动")
		ok = false
	am.play_music("bgm_letter")
	await process_frame
	if am.current_music() != "bgm_letter":
		print("     [!] 切歌失败")
		ok = false
	am.play_music("不存在的 BGM")
	print("  play_music(<不存在>) —— 保持 '%s'" % am.current_music())
	if am.current_music() != "bgm_letter":
		ok = false
	am.stop_music()
	await process_frame
	print("  stop_music() → current_music = '%s'" % am.current_music())

	print("=== 静音开关（走 Master 总线）+ 持久化 ===")
	am.set_muted(true)
	await process_frame
	print("  set_muted(true)  → is_muted=%s  bus_mute=%s" % [am.is_muted(), AudioServer.is_bus_mute(0)])
	if not am.is_muted() or not AudioServer.is_bus_mute(0):
		print("     [!] 静音没生效")
		ok = false
	if not FileAccess.file_exists("user://settings.cfg"):
		print("     [!] 设置文件没写出来")
		ok = false
	am.set_muted(false)
	await process_frame
	print("  set_muted(false) → is_muted=%s  bus_mute=%s" % [am.is_muted(), AudioServer.is_bus_mute(0)])
	if am.is_muted() or AudioServer.is_bus_mute(0):
		print("     [!] 取消静音失败")
		ok = false

	print("=== 播放器池 ===")
	print("  sfx players = %d，轮转游标 = %d" % [am._players.size(), am._next])
	if am._players.size() < 2:
		print("     [!] 播放器池不足 2 个，连续音效会互相截断")
		ok = false

	print("=== 结论: ", "PASS" if ok else "FAIL", " ===")
	quit(0 if ok else 1)
