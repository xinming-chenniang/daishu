extends Node

signal money_changed(new_money: int)
signal day_changed(new_day: int)

const STALL_FEE_PER_DAY: int = 10 # 每日固定支出（摊位+房租+米钱等）
const SAVE_PATH := "user://save.dat"
## 存档格式版本。**改字段语义/结构时必须 +1**，并给 apply_save_data() 补迁移分支。
## 旧存档没有 version 字段 → 按 1 读，保证老档还能用。
const SAVE_VERSION: int = 1
const TOTAL_DAYS: int = 10
const TARGET_MONEY: int = 500

## 实际读写用的存档路径。默认 `SAVE_PATH`；**回归脚本可指向临时文件**，
## 避免 `tools/verify_save.gd` 覆盖玩家真实存档。
var save_path: String = SAVE_PATH

signal day_ledger_changed

var completed_npcs: Array[int] = []

var money: int = 100:
	set(value):
		money = value
		money_changed.emit(money)

var day: int = 1:
	set(value):
		day = value
		day_changed.emit(day)

var day_ledger: Array[Dictionary] = []

func _ready() -> void:
	# 存档加载由标题界面控制，这里不自动加载
	pass

## 加/减钱。**返回 true 表示这次调用把钱变成了负数**（已请求切到失败结局）。
##
## 为什么要把这个结果返回给调用方：`change_scene_to_file()` 是**帧末**才真正换场景的，
## 调用方（letter / main）在同一次调用里还会继续改自己那套 UI。如果不看返回值就继续跑，
## 就会出现"场景已经要换走了，代码还在操作旧节点"的竞争（实测见 docs/DOC_AUDIT_2026-10-18.md §三）。
func add_money(amount: int) -> bool:
	money += amount
	if money < 0:
		show_failure_scene()
		return true
	return false

## 进入下一天。**返回 true 表示已触发结局**（第 10 天之后），调用方不要再操作本场景的 UI。
func next_day() -> bool:
	day += 1
	if day > TOTAL_DAYS:
		check_endgame()
		return true
	return false

func is_npc_completed(npc_id: int) -> bool:
	return completed_npcs.has(npc_id)

func mark_npc_completed(npc_id: int) -> void:
	if not completed_npcs.has(npc_id):
		completed_npcs.append(npc_id)

func reset_completed_npcs() -> void:
	completed_npcs.clear()

func record_entry(kind: String, amount: int, desc: String, meta: Dictionary = {}) -> void:
	day_ledger.append({
		"kind": kind,
		"amount": amount,
		"desc": desc,
		"meta": meta
	})
	day_ledger_changed.emit()

func get_day_summary() -> Dictionary:
	var income := 0
	var expense := 0
	for e in day_ledger:
		var a := int(e.get("amount", 0))
		if a >= 0:
			income += a
		else:
			expense += -a
	
	var stall_fee := STALL_FEE_PER_DAY
	var net := income - expense - stall_fee
	return {
		"income": income,
		"expense": expense,
		"stall_fee": stall_fee,
		"net": net,
		"entries": day_ledger.duplicate(true)
	}

## 收当日固定支出。返回 true = 交完这笔钱就破产了（调用方应立即停止后续结算）。
func apply_end_of_day_costs() -> bool:
	return add_money(-STALL_FEE_PER_DAY)

func reset_day_ledger() -> void:
	day_ledger.clear()
	day_ledger_changed.emit()

func reset() -> void:
	money = 100
	day = 1
	reset_completed_npcs()
	reset_day_ledger()

func check_endgame() -> void:
	if money >= TARGET_MONEY and money >= 0:
		show_success_scene()
	else:
		show_failure_scene()
func show_success_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/success.tscn")

func show_failure_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/gameover.tscn")

func get_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"money": money,
		"day": day,
		"completed_npcs": completed_npcs.duplicate(),
		"day_ledger": day_ledger.duplicate(true)
	}

## 读入存档数据。**返回 false = 拒绝加载**（版本比本程序新，或字段类型明显不对）。
## 旧存档（没有 version 字段）按 1 处理，保证兼容。
func apply_save_data(data: Dictionary) -> bool:
	var version := int(data.get("version", 1))
	if version > SAVE_VERSION:
		push_error(
			"存档版本 %d 高于本程序支持的 %d，拒绝加载（避免把新格式字段当旧格式读）" % [version, SAVE_VERSION]
		)
		return false
	if data.has("money"):
		money = int(data.get("money", money))
	if data.has("day"):
		day = int(data.get("day", day))
	completed_npcs.clear()
	for id in data.get("completed_npcs", []):
		completed_npcs.append(int(id))
	day_ledger.clear()
	for e in data.get("day_ledger", []):
		if typeof(e) == TYPE_DICTIONARY:
			day_ledger.append(e)
	day_ledger_changed.emit()
	return true

func save_game() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("保存失败：无法打开存档文件 %s" % save_path)
		return false
	var data := get_save_data()
	file.store_string(JSON.stringify(data))
	return true

## 读存档。返回 false = 没有存档 / 读不出 / 拒绝加载（损坏、版本过新）。
## 调用方（标题界面）据此决定是否回落到"新游戏"，而不是带着半套状态进主界面。
func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("读取失败：无法打开存档文件 %s" % save_path)
		return false
	var content := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(content)
	if err != OK:
		push_error("存档 JSON 解析失败：%s" % json.get_error_message())
		return false
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("存档格式不是字典，拒绝加载")
		return false
	return apply_save_data(data)

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func save() -> bool:
	return save_game()

func load() -> bool:
	return load_game()

