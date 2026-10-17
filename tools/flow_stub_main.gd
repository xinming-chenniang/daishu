# 测试替身：冒充 main.tscn 的宿主。
# 只做两件真实 main.gd 也会做的事：① 把委托记进 PlayerManager ② 记录通知历史。
# 必须是 Control —— letter.gd 的 return_to_main() 会调用 main.show()。
extends Control

var completed: Array = []


func on_npc_completed(npc_id: int) -> void:
	completed.append(int(npc_id))
	var pm = get_node_or_null("/root/PlayerManager")
	if pm != null:
		pm.mark_npc_completed(int(npc_id))


func update_ui() -> void:
	pass
