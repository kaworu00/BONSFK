extends CharacterBody2D
# ============================================================
# crystal.gd —— 灵石（水晶）
# 作用：朝 aim_direction 方向飞行，撞到不同东西产生不同效果：
#   1) 撞到地形       → 生成一块「浮空平台」（几秒后消失，用来铺路解谜）
#   2) 撞到可击碎障碍 → 击碎它
#   3) 撞到敌人       → 冻结敌人（变蓝、停下，可安全绕过）
# 这就是 VP 里「水晶生成平台 / 击碎障碍 / 冻结敌人」机制的简化版。
# ============================================================

const SPEED := 420.0       # 飞行速度
const LIFETIME := 2.0      # 最长存活时间（没撞到东西就自动消失）

var aim_direction := Vector2.RIGHT


func _ready() -> void:
    # 灵石在层3；只检测层1（地形，用于生成平台/击碎障碍）和层4（敌人，用于冻结）
    collision_layer = 3
    collision_mask = 1 | 4

    var shape := RectangleShape2D.new()
    shape.size = Vector2(8, 8)
    var cs := CollisionShape2D.new()
    cs.shape = shape
    add_child(cs)

    add_child(_rect(Vector2(10, 10), Color(0.4, 0.9, 1.0)))

    # 超时自毁
    var timer := get_tree().create_timer(LIFETIME)
    timer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
    velocity = aim_direction * SPEED
    var col := move_and_collide(velocity * delta)
    if col:
        _on_hit(col)


func _on_hit(col: KinematicCollision2D) -> void:
    var collider := col.get_collider()
    if collider is Node:
        if collider.is_in_group("breakable"):
            # 撞到可击碎障碍 → 击碎它
            collider.call("smash")
        elif collider.is_in_group("enemy"):
            # 撞到敌人 → 冻结敌人
            collider.call("freeze_enemy")
        else:
            _spawn_platform(col)
    else:
        _spawn_platform(col)
    queue_free()


func _spawn_platform(col: KinematicCollision2D) -> void:
    # 普通地形：在撞击点略偏法线方向的位置生成浮空平台
    var normal := col.get_normal()      # 撞击面的法线方向
    var pos := col.get_position()       # 撞击点
    var platform := _make_platform(pos + normal * 14.0)
    get_parent().add_child(platform)


func _make_platform(pos: Vector2) -> StaticBody2D:
    var sb := StaticBody2D.new()
    sb.position = pos
    var shape := RectangleShape2D.new()
    shape.size = Vector2(56, 14)
    var cs := CollisionShape2D.new()
    cs.shape = shape
    sb.add_child(cs)
    sb.add_child(_rect(Vector2(56, 14), Color(0.5, 0.9, 1.0, 0.9)))
    # 6 秒后消失
    var timer := get_tree().create_timer(6.0)
    timer.timeout.connect(sb.queue_free)
    return sb


func _rect(size: Vector2, color: Color) -> Polygon2D:
    var p := Polygon2D.new()
    var h := size * 0.5
    p.polygon = PackedVector2Array([
        Vector2(-h.x, -h.y), Vector2(h.x, -h.y),
        Vector2(h.x, h.y), Vector2(-h.x, h.y)
    ])
    p.color = color
    return p