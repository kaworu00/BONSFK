extends CharacterBody2D
class_name Player
# ============================================================
# player.gd —— 玩家控制器（横板探索）
# 包含：左右移动、跳跃（含重力）、下蹲、朝向、发射灵石。
# 状态机：IDLE（待机）/ RUN（跑）/ JUMP（跳）/ FALL（落）/ CROUCH（蹲）
# 目前用「占位色块」当角色，正式美术做好后，把 _build_body 里的
# Polygon2D 换成 Sprite2D + 动画即可。
# ============================================================

enum State { IDLE, RUN, JUMP, FALL, CROUCH }

const SPEED := 220.0          # 水平移动速度（像素/秒）
const JUMP_VELOCITY := -420.0 # 起跳初速度（负 = 向上）
const GRAVITY := 900.0        # 重力加速度
const CRYSTAL_COOLDOWN := 0.4 # 灵石发射冷却（秒）

const CrystalScene := preload("res://scenes/world/crystal.tscn")

var facing := 1               # 1 = 朝右，-1 = 朝左
var state: State = State.IDLE
var can_fire := true
var camera_limit_right := 2560  # 相机右边界（由房间宽度决定，room.gd 会覆盖它）

var _visual: Node2D
var _coll: CollisionShape2D


func _ready() -> void:
    add_to_group("player")
    # 碰撞层方案：
    #   层1 = 地形（墙/地面/平台）
    #   层2 = 玩家
    #   层3 = 灵石
    # 玩家只和地形碰撞（mask=1），不和灵石碰撞。
    collision_layer = 2
    collision_mask = 1
    _build_body()
    _build_camera()


func _build_body() -> void:
    # 身体：优先加载 res://art/player.png，没有图则回落蓝色色块
    _visual = GlobalState.make_art_node("res://art/player.png", Vector2(16, 32), Color(0.3, 0.6, 1.0))
    _visual.name = "Visual"
    add_child(_visual)

    # 加一只白色「眼睛」标记朝向（翻转时能看出面向哪边）
    var eye := _rect(Vector2(3, 3), Color(1, 1, 1))
    eye.position = Vector2(4, -6)
    _visual.add_child(eye)

    # 碰撞体：和可视大小一致
    var shape := RectangleShape2D.new()
    shape.size = Vector2(16, 32)
    _coll = CollisionShape2D.new()
    _coll.shape = shape
    _coll.name = "CollisionShape2D"
    add_child(_coll)


func _build_camera() -> void:
    var cam := Camera2D.new()
    cam.enabled = true
    cam.add_to_group("exploration_camera")  # 供 main.gd 在战斗结束后找回相机
    cam.position_smoothing_enabled = true
    cam.position_smoothing_speed = 8.0
    cam.limit_left = 0
    cam.limit_right = camera_limit_right
    cam.limit_top = -200
    cam.limit_bottom = 600
    cam.name = "Camera2D"
    add_child(cam)


func _physics_process(delta: float) -> void:
    # 1. 重力：不在地上就往下加速
    if not is_on_floor():
        velocity.y += GRAVITY * delta

    # 2. 水平输入
    var dir := Input.get_axis("move_left", "move_right")
    velocity.x = dir * SPEED
    if dir != 0.0:
        facing = 1 if dir > 0.0 else -1

    # 3. 跳跃（只有在地上才能跳）
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = JUMP_VELOCITY

    # 4. 下蹲
    var crouching := Input.is_action_pressed("crouch")
    _set_crouch(crouching)

    # 5. 更新状态机
    _update_state(crouching)

    # 6. 真正移动（处理碰撞 + 落到地面标记 is_on_floor）
    move_and_slide()

    # 7. 朝向翻转占位视觉
    _visual.scale.x = facing

    # 8. 发射灵石
    if Input.is_action_just_pressed("crystal") and can_fire:
        _fire_crystal()


func _update_state(crouching: bool) -> void:
    if crouching:
        state = State.CROUCH
    elif not is_on_floor():
        state = State.JUMP if velocity.y < 0 else State.FALL
    elif absf(velocity.x) > 1.0:
        state = State.RUN
    else:
        state = State.IDLE


func _set_crouch(c: bool) -> void:
    # 简化版下蹲：把身体压扁到一半高（正式版可改成独立碰撞形状）
    var t := 0.5 if c else 1.0
    var shape := _coll.shape as RectangleShape2D
    shape.size.y = 32.0 * t
    _visual.scale.y = t


func _fire_crystal() -> void:
    var crystal = CrystalScene.instantiate()
    # 瞄准方向：默认正前方；按住跳跃键 = 斜上，按住下蹲键 = 斜下
    var aim := Vector2(float(facing), 0.0)
    if Input.is_action_pressed("jump"):
        aim = Vector2(float(facing), -1.0)
    elif Input.is_action_pressed("crouch"):
        aim = Vector2(float(facing), 1.0)
    # 用 set() 给灵石实例设自定义属性，避免静态类型检查报错
    crystal.set("aim_direction", aim.normalized())
    crystal.set("global_position", global_position + Vector2(0, -10))
    get_parent().add_child(crystal)
    AudioManager.play("shoot")

    # 冷却：用 await 等 0.4 秒再允许发射
    can_fire = false
    await get_tree().create_timer(CRYSTAL_COOLDOWN).timeout
    can_fire = true


# 小工具：生成一个居中的实心矩形（Polygon2D）
func _rect(size: Vector2, color: Color) -> Polygon2D:
    var p := Polygon2D.new()
    var h := size * 0.5
    p.polygon = PackedVector2Array([
        Vector2(-h.x, -h.y), Vector2(h.x, -h.y),
        Vector2(h.x, h.y), Vector2(-h.x, h.y)
    ])
    p.color = color
    return p