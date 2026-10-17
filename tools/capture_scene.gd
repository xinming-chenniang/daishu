# 通用场景截图：加载任意场景，可选点击某个按钮后截图
# 用法：
#   godot --path <项目> --script res://tools/capture_scene.gd -- --scene main --out <路径.png> [--click StartDayBtn]
extends SceneTree

const SCENES := {
	"main": "res://scenes/main.tscn",
	"title": "res://scenes/title_screen.tscn",
	"prologue": "res://scenes/prologue.tscn",
	"letter": "res://scenes/letter.tscn",
	"success": "res://scenes/success.tscn",
	"gameover": "res://scenes/gameover.tscn",
}

func _initialize() -> void:
	var scene_key := "main"
	var out_path := ""
	var click_name := ""
	var click_first := ""       ## 可选：点击该节点路径下的**第一个 Button**（用于名字由代码生成的列表项）
	var fixed_seed := -1        ## 可选：固定随机种子，让"随机 NPC"可复现（A/B 截图对比用）
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		match args[i]:
			"--scene":
				if i + 1 < args.size():
					scene_key = args[i + 1]
			"--out":
				if i + 1 < args.size():
					out_path = args[i + 1]
			"--click":
				if i + 1 < args.size():
					click_name = args[i + 1]
			"--click-first":
				if i + 1 < args.size():
					click_first = args[i + 1]
			"--seed":
				if i + 1 < args.size():
					fixed_seed = int(args[i + 1])

	if out_path.is_empty():
		push_error("缺少 --out 参数")
		quit(1)
		return
	if not SCENES.has(scene_key):
		push_error("未知场景: " + scene_key)
		quit(1)
		return

	# 固定种子必须在**生成 NPC 之前**：letter 场景会调 NPCManager.get_today_npcs()。
	# 用途：改布局/样式前后各截一张，用逐像素对比证明"没有意外变化"。
	if fixed_seed >= 0:
		seed(fixed_seed)
		print("[capture] 固定随机种子: ", fixed_seed)

	# 显式把窗口设到设计分辨率。
	# 注意：命令行 `--resolution` 会把**视口**一起改掉，导致截图被缩放
	# （实测给 900x260 时出图只有 462x260 —— 游戏视口被设成 900x260 而窗口是 1152x648）。
	# 所以这里不依赖 --resolution，自己设窗口尺寸，并在写图后断言像素尺寸。
	const DESIGN := Vector2i(1152, 648)
	DisplayServer.window_set_size(DESIGN)
	get_root().size = DESIGN
	for i in range(3):
		await process_frame

	var packed: PackedScene = load(SCENES[scene_key])
	if packed == null:
		push_error("加载失败: " + SCENES[scene_key])
		quit(1)
		return
	var scene: Node = packed.instantiate()
	get_root().add_child(scene)
	for i in range(4):
		await process_frame

	# letter 场景需要注入一个 NPC 才会填充词库（否则左侧词库是空的 —— 这是本工具的坑，
	# 不是游戏问题：场景本身靠 main.gd 调用 init_with_npc 才初始化）
	if scene_key == "letter":
		var npc_manager: Node = get_root().get_node_or_null("NPCManager")
		if npc_manager == null:
			print("[capture] 找不到 NPCManager，词库将为空")
		else:
			var npcs: Array = npc_manager.get_today_npcs(1)
			if npcs.is_empty():
				print("[capture] 没有生成 NPC，词库将为空")
			else:
				var npc: Dictionary = npcs[0]
				scene.init_with_npc(int(npc.get("npc_id", 0)))
				print("[capture] 注入 NPC: ", npc.get("name", "?"), "（", npc.get("letter_type", "?"), "）")
				for i in range(4):
					await process_frame

	# 可选：点一次按钮（用于触发列表填充等交互后再截图）
	if not click_name.is_empty():
		var btn := _find_node_by_name(scene, click_name)
		if btn == null:
			print("[capture] 找不到按钮: ", click_name)
		elif btn is Button:
			print("[capture] 点击按钮: ", click_name)
			btn.emit_signal("pressed")
			for i in range(6):
				await process_frame
		else:
			print("[capture] ", click_name, " 不是 Button")

	# 可选：点击某个节点路径下的**第一个 Button**
	# （用于名字由代码生成的列表项，比如委托列表 —— 它们的 name 不是固定字符串）
	if not click_first.is_empty():
		var host := scene.get_node_or_null(click_first)
		if host == null:
			print("[capture] 找不到节点: ", click_first)
		else:
			var first_btn := _find_first_button(host)
			if first_btn == null:
				print("[capture] ", click_first, " 下没有 Button")
			else:
				print("[capture] 点击 ", click_first, " 下第一个按钮: ", first_btn.text)
				first_btn.emit_signal("pressed")
				for i in range(10):
					await process_frame

	for i in range(3):
		await process_frame

	var img: Image = get_root().get_texture().get_image()
	if img == null:
		push_error("取不到视口图像")
		quit(1)
		return
	img.save_png(out_path)
	print("[capture] 已保存 ", out_path, "  ", img.get_width(), "x", img.get_height())
	# 自检：尺寸必须是设计分辨率，否则截图被缩放过、不能当像素级依据
	if img.get_width() != DESIGN.x or img.get_height() != DESIGN.y:
		push_error("截图尺寸 %dx%d 与设计分辨率 %dx%d 不符（说明视口被缩放，别拿它做像素判断）"
			% [img.get_width(), img.get_height(), DESIGN.x, DESIGN.y])
		quit(1)
		return
	quit(0)

func _find_node_by_name(root: Node, target: String) -> Node:
	if root.name == target:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, target)
		if found != null:
			return found
	return null

## 深度优先找第一个 Button（用于 name 由代码生成的列表项）
func _find_first_button(root: Node) -> Button:
	if root is Button:
		return root as Button
	for child in root.get_children():
		var found := _find_first_button(child)
		if found != null:
			return found
	return null
