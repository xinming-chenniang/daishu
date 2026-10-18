extends Node

## 全局动效开关 + 淡入工具。
##
## 为什么要它：截图/验证工具（`capture_scene.gd`、各种 `verify_*.gd`）只等 3–6 帧就抓图，
## 如果场景 `_ready` 里跑 0.35 s 的淡入，抓到的是半透明帧 —— 文档图会变暗、
## 视觉回归也会莫名其妙地失败。所以**动画必须先问这里**。
##
## 判据（任一命中即视为"非交互环境"，直接跳到终态）：
##   · headless 渲染（`--headless`）
##   · `--script` 模式（所有 verify_* / capture_scene 都走这条）
##   · 命令行带 `--out` / `--shot`（截图输出参数，双保险）

const FADE_IN_SECONDS := 0.35


func animations_enabled() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	for arg in OS.get_cmdline_args():
		if arg == "--script" or arg == "--headless":
			return false
	for arg in OS.get_cmdline_user_args():
		if arg == "--out" or arg == "--shot":
			return false
	return true


## 淡入一个 CanvasItem（场景根节点 / letter 实例）。
## 动画关闭时直接把 alpha 置 1，保证截图与验证看到的是终态。
func fade_in(node: CanvasItem, duration: float = FADE_IN_SECONDS) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not animations_enabled():
		node.modulate.a = 1.0
		return
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
