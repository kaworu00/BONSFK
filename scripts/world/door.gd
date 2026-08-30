extends Area2D
# ============================================================
# door.gd —— 房间出口（门）
# 作用：玩家走进门 → 发出 room_exit_requested 信号，
#       由 main.gd 负责切换到目标房间。
# ============================================================

var to_room := ""


func _ready() -> void:
    collision_layer = 1
    collision_mask = 2  # 只检测玩家

    var shape := RectangleShape2D.new()
    shape.size = Vector2(56, 160)
    var cs := CollisionShape2D.new()
    cs.shape = shape
    add_child(cs)

    # 占位门外观（半透明竖条）
    var frame := _rect(Vector2(56, 160), Color(0.35, 0.55, 0.95, 0.45))
    add_child(frame)

    # 目标房间名
    var target: Dictionary = RoomRegistry.ROOMS.get(to_room, {})
    var tname: String = str(target.get("name", "???"))
    var lbl := GlobalState.make_label("→ " + tname, 13, Color(0.7, 0.9, 1.0))
    lbl.position = Vector2(-30, -100)
    add_child(lbl)

    body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player") and to_room != "":
        EventBus.room_exit_requested.emit(to_room)


func _rect(size: Vector2, color: Color) -> Polygon2D:
    var p := Polygon2D.new()
    var h := size * 0.5
    p.polygon = PackedVector2Array([
        Vector2(-h.x, -h.y), Vector2(h.x, -h.y),
        Vector2(h.x, h.y), Vector2(-h.x, h.y)
    ])
    p.color = color
    return p