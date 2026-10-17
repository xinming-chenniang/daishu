# 回归校验：存档往返、损坏存档、版本过新、旧存档兼容
#
# 为什么单独测：存档此前**没有任何回归覆盖**，而它的失败是"静默坏档"——
# 读失败时旧实现会带着半套状态直接进主界面。现在 load_game() 返回 bool，
# 标题界面据此回落新游戏（见 title_screen.gd）。
#
# 用法：
#   pwsh -File tools\run-godot.ps1 --headless --script res://tools/verify_save.gd
#
# ⚠️ 脚本把 `PlayerManager.save_path` 指到 `user://save_test.dat`，**不碰玩家真实存档**；
#    结束时删掉临时文件并还原路径。
extends SceneTree

const TEST_PATH := "user://save_test.dat"

var _fails: Array[String] = []


func _initialize() -> void:
	await process_frame  # --script 的 _initialize 早于 SceneTree 激活，见 AI_PLAYBOOK 第 21 条

	var pm = get_root().get_node_or_null("PlayerManager")
	if pm == null:
		print("=== 结论: FAIL ===（找不到 PlayerManager）")
		quit(1)
		return

	var original_path: String = pm.save_path
	pm.save_path = TEST_PATH
	_remove(TEST_PATH)

	print("=== ① 往返：写进去 → reset → 读回来 ===")
	pm.reset()
	pm.money = 123
	pm.day = 4
	pm.mark_npc_completed(-7)
	pm.record_entry("commission", 20, "测试委托", {"npc_id": -7})

	var data: Dictionary = pm.get_save_data()
	_check(int(data.get("version", -1)) == int(pm.SAVE_VERSION), "存档里带 version = %d" % int(pm.SAVE_VERSION))
	_check(pm.save_game() == true, "save_game() 返回 true")
	_check(pm.has_save() == true, "has_save() 为 true")

	pm.reset()
	_check(pm.money == 100 and pm.day == 1, "reset() 后回到初始状态")
	_check(pm.load_game() == true, "load_game() 返回 true")
	_check(pm.money == 123, "钱恢复为 123")
	_check(pm.day == 4, "天数恢复为 4")
	_check(pm.is_npc_completed(-7), "已完成委托恢复")
	_check(pm.day_ledger.size() == 1, "当日流水恢复 1 条")

	print("=== ② 损坏存档：必须返回 false，且不改动当前状态 ===")
	_write(TEST_PATH, "这不是 JSON {{{")
	_check(pm.load_game() == false, "损坏存档 load_game() 返回 false")
	_check(pm.money == 123, "读失败后钱保持 123（未被半套状态污染）")

	print("=== ③ 版本比程序新：拒绝加载 ===")
	_write(TEST_PATH, '{"version": 999, "money": 5, "day": 2}')
	_check(pm.load_game() == false, "version 999 load_game() 返回 false")
	_check(pm.money == 123, "拒绝加载后钱保持 123")

	print("=== ④ 旧存档（没有 version 字段）按 1 兼容 ===")
	_write(TEST_PATH, '{"money": 77, "day": 2}')
	_check(pm.load_game() == true, "无 version 的旧存档能加载")
	_check(pm.money == 77 and pm.day == 2, "旧存档数值正确（77 / 第 2 日）")

	print("=== ⑤ 没有存档文件 ===")
	_remove(TEST_PATH)
	_check(pm.has_save() == false, "删掉后 has_save() 为 false")
	_check(pm.load_game() == false, "没有存档时 load_game() 返回 false")

	# 收尾：删临时文件、还原路径
	_remove(TEST_PATH)
	pm.save_path = original_path
	_check(pm.save_path == original_path, "已还原真实存档路径")

	if _fails.is_empty():
		print("=== 结论: PASS ===")
		quit(0)
	else:
		print("=== 结论: FAIL（%d 项）===" % _fails.size())
		for f in _fails:
			print("  [!] ", f)
		quit(1)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_fails.append("无法写入测试文件 %s" % path)
		return
	f.store_string(text)
	f.close()


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  [OK] ", msg)
	else:
		print("  [FAIL] ", msg)
		_fails.append(msg)
