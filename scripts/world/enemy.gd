extends CharacterBody2D
# ============================================================
# enemy.gd —— 敌人（可巡逻、可被灵石冻结）
# 作用：在地面上左右巡逻；被灵石击中会被「冻结」（变蓝、停下、可绕过）；
#       玩家走进它的警觉范围则进入战斗。
# ============================================================

const SPEED := 60.0        # 巡逻速度
const FREEZE_TIME := 4.0   # 冻结持续秒数

var enemy_id := "taowu"
var direction := 1
var patrol_min_x := 700.0
var patrol_max_x := 1000.0

var frozen := false
var freeze_left := 0.0
var triggered := false

var _body: Node2D
var _zone: Area2D


func _ready() -> void:
    add_to_group("enemy")
    # 敌人放在层4，只和地形(层1)碰撞；玩家(层2)会从它身上走过，靠警觉区触发战斗。
    collision_layer = 4
    collision_mask = 1
    _build_body()
    _build_zone()


func _build_body() -> void:
    var shape := RectangleShape2D.new()
    shape.size = Vector2(48, 40)
    var cs := CollisionShape2D.new()
    cs.shape = shape
    add_child(cs)

    _body = GlobalState.make_art_node("res://art/enemies/" + enemy_id + ".png", Vector2(48, 40), Color(0.85, 0.25, 0.2))
    add_child(_body)

    # 眼睛（帮助看清朝向）
    var eye := _rect(Vector2(4, 4), Color(1, 1, 1))
    eye.position = Vector2(14, -6)
    _body.add_child(eye)

    var lbl := GlobalState.make_label("魔物", 12, Color(1, 0.85, 0.85))
    lbl.position = Vector2(-20, -56)
    add_child(lbl)


func _build_zone() -> void:
    # 警觉范围：玩家走进来就触发战斗
    _zone = Area2D.new()
    _zone.collision_layer = 1
    _zone.collision_mask = 2  # 检测玩家所在层2
    var shape := RectangleShape2D.new()
    shape.size = Vector2(72, 64)
    var cs := CollisionShape2D.new()
    cs.shape = shape
    _zone.add_child(cs)
    _zone.body_entered.connect(_on_player_enter)
    add_child(_zone)


func _physics_process(delta: float) -> void:
    if frozen:
        freeze_left -= delta
        if freeze_left <= 0.0:
            _unfreeze()
        return
    # 在巡逻范围内折返
    if global_position.x <= patrol_min_x:
        direction = 1
    elif global_position.x >= patrol_max_x:
        direction = -1
    velocity = Vector2(direction * SPEED, 0)
    move_and_slide()
    _body.scale.x = -1.0 if direction < 0 else 1.0


func freeze_enemy() -> void:
    if frozen:
        return
    frozen = true
    freeze_left = FREEZE_TIME
    _body.modulate = Color(0.3, 0.7, 1.0)
    _zone.set_deferred("monitoring", false)  # 冻结期间不会触发战斗


func _unfreeze() -> void:
    frozen = false
    _body.modulate = Color(0.85, 0.25, 0.2)
    if not triggered:
        _zone.set_deferred("monitoring", true)


func _on_player_enter(body: Node2D) -> void:
    if body.is_in_group("player") and not triggered and not frozen:
        triggered = true
        _zone.set_deferred("monitoring", false)
        EventBus.battle_requested.emit(enemy_id)


func _rect(size: Vector2, color: Color) -> Polygon2D:
    var p := Polygon2D.new()
    var h := size * 0.5
    p.polygon = PackedVector2Array([
        Vector2(-h.x, -h.y), Vector2(h.x, -h.y),
        Vector2(h.x, h.y), Vector2(-h.x, h.y)
    ])
    p.color = color
    return p