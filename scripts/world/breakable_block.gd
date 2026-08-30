extends StaticBody2D
# ============================================================
# breakable_block.gd —— 可击碎障碍
# 作用：被灵石击中后碎裂消失；用来在关卡里做「需要击碎才能通过」的墙。
# 它只是给一个普通 StaticBody2D 挂上这个脚本、并加入 "breakable" 分组，
# 这样灵石撞到它时就能识别并调用 smash()。
# ============================================================

func _ready() -> void:
    add_to_group("breakable")
    collision_layer = 1
    collision_mask = 1


func smash() -> void:
    # 碎裂反馈：缩小 + 淡出，然后移除
    var tween := create_tween()
    tween.tween_property(self, "scale", Vector2(0.05, 0.05), 0.18)
    tween.parallel().tween_property(self, "modulate:a", 0.0, 0.18)
    tween.tween_callback(queue_free)