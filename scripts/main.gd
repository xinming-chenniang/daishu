extends Control

const NPCAvatar := preload("res://scripts/npc_avatar.gd")

# 节点引用
@onready var money_label = $MainPanel/VBoxContainer/StatusBar/MoneyLabel
@onready var day_label = $MainPanel/VBoxContainer/StatusBar/DayLabel
@onready var npc_list_container = $MainPanel/VBoxContainer/NPCList
@onready var start_day_btn = $MainPanel/VBoxContainer/ButtonBar/StartDayBtn
@onready var end_day_btn = $MainPanel/VBoxContainer/ButtonBar/EndDayBtn
@onready var save_quit_btn = $MainPanel/VBoxContainer/ButtonBar/SaveQuitBtn
@onready var end_day_popup: AcceptDialog = $EndDayPopup
@onready var end_day_label: Label = $EndDayPopup/EndDayLabel
# 用路径查找而不是裸全局名：--script 模式不注册 autoload（AI_PLAYBOOK 第 1 条）
@onready var _audio: Node = get_node_or_null("/root/AudioManager")

func _ready():
	# 连接按钮信号
	start_day_btn.pressed.connect(_on_start_day_pressed)
	end_day_btn.pressed.connect(_on_end_day_pressed)
	save_quit_btn.pressed.connect(_on_save_quit_pressed)
	end_day_popup.confirmed.connect(_on_end_day_popup_confirmed)
	end_day_popup.get_ok_button().text = "确认"
	
	# 监听玩家状态变化并刷新 UI
	PlayerManager.money_changed.connect(_on_money_changed)
	PlayerManager.day_changed.connect(_on_day_changed)
	
	# 初始化显示
	update_ui()
	
	# 默认不显示NPC列表（等点击“开始今日”后显示）
	clear_npc_list()

## 面板高度跟内容走。
## 面板是 root Control 的直接子节点（不在任何 Container 里），所以 size_flags /
## custom_minimum_size 都不会被自动采纳 —— 高度必须自己算，否则内容一长就顶出屏幕上沿
## （实测：加了头像后每行 37→44px，VBox 最小高 280 > 面板给的 238，状态栏被推出屏幕）。
func _resize_panel_to_content() -> void:
	var panel: Panel = $MainPanel
	var vbox: Control = $MainPanel/VBoxContainer
	var sb := panel.get_theme_stylebox("panel")
	var pad := sb.get_content_margin(SIDE_TOP) + sb.get_content_margin(SIDE_BOTTOM) if sb != null else 20.0
	# 向上取整到 8px：与项目其它资产/UI 的 8px 对齐约定一致（ART_PLAN §五）
	var needed: float = vbox.get_combined_minimum_size().y + pad
	panel.offset_bottom = panel.offset_top + ceilf(needed / 8.0) * 8.0

func add_money(delta: int) -> bool:
	return PlayerManager.add_money(delta)

func update_ui():
	money_label.text = "铜钱: " + str(PlayerManager.money) + "文"
	day_label.text = "第 %d 日 / 共 %d 日" % [PlayerManager.day, PlayerManager.TOTAL_DAYS]

func _on_money_changed(_new_money: int) -> void:
	update_ui()

func _on_day_changed(_new_day: int) -> void:
	update_ui()

func clear_npc_list():
	# 清空NPC列表容器中的所有子节点
	for child in npc_list_container.get_children():
		child.queue_free()

func _on_start_day_pressed():
	if _audio != null:
		_audio.play_sfx("ui_click")
	print("开始新的一天")
	# 调用NPCManager获取今日NPC
	var npc_manager = get_node("/root/NPCManager")  # 如果是自动加载的
	if not npc_manager:
		print("错误：找不到NPCManager")
		return
	
	var today_npcs = npc_manager.get_today_npcs(PlayerManager.day)
	print("今日NPC数量：", today_npcs.size())
	
	# 清空之前的列表
	clear_npc_list()
	
	# 为每个NPC创建一个条目：头像（左）+ 姓名与信型（右）
	# 头像单独用固定尺寸的 Control 承载 —— 直接放进 HBox 会被主题的九宫格边距撑高
	for npc in today_npcs:
		var npc_id = npc.get("npc_id", null)
		if npc_id != null and PlayerManager.is_npc_completed(int(npc_id)):
			continue
		npc_list_container.add_child(_make_npc_row(npc))

	# 行数变了，面板高度跟着变（不这么做，条目一多就会顶出屏幕上沿）
	_resize_panel_to_content()

# 单条委托：左侧头像 + 右侧按钮
func _make_npc_row(npc: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var avatar_slot := Control.new()
	avatar_slot.custom_minimum_size = Vector2(NPCAvatar.SIZE, NPCAvatar.SIZE)
	avatar_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar := NPCAvatar.new()
	avatar.setup(npc)
	avatar_slot.add_child(avatar)
	row.add_child(avatar_slot)

	var btn := Button.new()
	# 补上关系：它决定称谓池，是玩家真的要读的信息（与 avatar 同一份数据来源）
	var relation := str(npc.get("relation", ""))
	var label := "%s（%s）" % [npc["name"], npc.get("letter_type", "家书")]
	if not relation.is_empty():
		label = "%s · %s（%s）" % [npc["name"], relation, npc.get("letter_type", "家书")]
	btn.text = label
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 将NPC的id存储在按钮的meta中，便于点击时获取
	btn.set_meta("npc_id", npc["npc_id"])
	btn.pressed.connect(_on_npc_button_pressed.bind(btn))
	row.add_child(btn)
	return row

func on_npc_completed(npc_id: int) -> void:
	PlayerManager.mark_npc_completed(npc_id)
	# 结构已改为「每行 = 头像 + 按钮」，按钮不再直接挂在 NPCList 下，所以递归找、
	# 并整体移除那一行（只删按钮会留下孤立的头像）
	for row in npc_list_container.get_children():
		var btn := _find_npc_button(row, npc_id)
		if btn != null:
			row.queue_free()
			break

func _find_npc_button(node: Node, npc_id: int) -> Button:
	if node is Button and node.has_meta("npc_id") and int(node.get_meta("npc_id")) == npc_id:
		return node as Button
	for child in node.get_children():
		var found := _find_npc_button(child, npc_id)
		if found != null:
			return found
	return null

func _on_npc_button_pressed(btn):
	if _audio != null:
		_audio.play_sfx("ui_click")
	var npc_id = btn.get_meta("npc_id")
	print("点击了NPC：", btn.text, " ID: ", npc_id)
	
	# 切换到代写界面，并传入NPC ID
	var letter_scene = preload("res://scenes/letter.tscn")
	var letter_instance = letter_scene.instantiate()
	get_tree().root.add_child(letter_instance)
	
	# 调用初始化函数（确保传入 int，与 NPCManager 查找一致）
	letter_instance.init_with_npc(int(npc_id))
	
	# 隐藏主界面（可选）
	self.hide()

func _on_end_day_pressed():
	if _audio != null:
		_audio.play_sfx("ui_click")
	var summary: Dictionary = PlayerManager.get_day_summary()
	var income := int(summary.get("income", 0))
	var expense := int(summary.get("expense", 0))
	var stall_fee := int(summary.get("stall_fee", PlayerManager.STALL_FEE_PER_DAY))
	var net := int(summary.get("net", 0))
	var lines := "第 %d 日结算\n\n" % PlayerManager.day
	lines += "今日收入：%d 文\n" % income
	lines += "今日扣除：%d 文\n" % expense
	lines += "固定支出（摊位+房租+米钱）：%d 文\n\n" % stall_fee
	lines += "净收益：%d 文\n" % net
	lines += "确认后进入下一天。"
	end_day_label.text = lines
	end_day_popup.popup_centered()

func _on_end_day_popup_confirmed() -> void:
	if _audio != null:
		_audio.play_sfx("day_end")
	# 两条"已切场景"的早退：交摊位费可能直接破产、第 10 天之后会进结局。
	# 这两种情况下 Main 都会在帧末被释放，再往下改 UI 就是操作已释放的节点。
	if PlayerManager.apply_end_of_day_costs():
		return
	if PlayerManager.next_day():
		return
	PlayerManager.reset_day_ledger()
	PlayerManager.reset_completed_npcs()
	clear_npc_list()
	update_ui()

func _on_save_quit_pressed():
	print("保存并退出")
	PlayerManager.save()
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
