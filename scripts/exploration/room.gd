extends Node2D
# ============================================================
# room.gd —— 通用房间生成器
# 作用：根据 room_id 读取 RoomRegistry 里的房间数据，
#       用代码搭建出地面、边界、可击碎墙、敌人、英灵、门、玩家、HUD。
#       所有房间共用这一份生成逻辑，加房间只改数据（room_registry.gd）。
# ============================================================

const PlayerScript := preload("res://scripts/player/player.gd")
const EnemyScript := preload("res://scripts/world/enemy.gd")
const NpcScript := preload("res://scripts/world/npc.gd")
const BreakableScript := preload("res://scripts/world/breakable_block.gd")
const DoorScript := preload("res://scripts/world/door.gd")
const HudScript := preload("res://scripts/ui/hud.gd")

var room_id := "cave_01"
var player: CharacterBody2D


func _ready() -> void:
    var data: Dictionary = RoomRegistry.ROOMS.get(room_id, RoomRegistry.ROOMS["cave_01"])
    _build_background(data)
    _build_bounds(data)
    _build_ground(data)
    _build_breakable_walls(data)
    _build_enemies(data)
    _build_npcs(data)
    _build_exits(data)
    _build_player(data)
    _build_hud(data)


func _build_background(data: Dictionary) -> void:
    var w := float(data.width)
    var bg := _rect(Vector2(w + 200, 600), data.bg)
    bg.position = Vector2(w / 2.0, 300)
    bg.z_index = -10
    add_child(bg)
    # 远处山影装饰
    var m := _rect(Vector2(320, 180), Color(0.13, 0.16, 0.24))
    m.position = Vector2(w * 0.35, 210)
    m.z_index = -9
    add_child(m)


func _build_bounds(data: Dictionary) -> void:
    var w := float(data.width)
    _make_static(Vector2(4, 300), Vector2(8, 600), Color(0.3, 0.3, 0.4))
    _make_static(Vector2(w - 4, 300), Vector2(8, 600), Color(0.3, 0.3, 0.4))


func _build_ground(data: Dictionary) -> void:
    for x in range(0, int(data.width), 320):
        _make_static(Vector2(x + 160, 420), Vector2(320, 40), Color(0.24, 0.27, 0.36))


func _build_breakable_walls(data: Dictionary) -> void:
    for w in data.get("breakable", []):
        var wx := float(w.get("x", 0.0))
        var blocks := int(w.get("blocks", 3))
        for b in range(blocks):
            var y := 380.0 - (blocks - 1 - b) * 40.0
            _make_breakable(Vector2(wx, y), Vector2(40, 40), Color(0.68, 0.52, 0.32))


func _build_enemies(data: Dictionary) -> void:
    for e in data.get("enemies", []):
        _make_enemy(
            Vector2(float(e.get("x", 0.0)), 380.0),
            str(e.get("id", "taowu")),
            float(e.get("min", 0.0)),
            float(e.get("max", 0.0))
        )


func _build_npcs(data: Dictionary) -> void:
    for n in data.get("npcs", []):
        _make_npc(Vector2(float(n.get("x", 0.0)), 360.0), str(n.get("id", "houyi")))


func _build_exits(data: Dictionary) -> void:
    for ex in data.get("exits", []):
        _make_door(Vector2(float(ex.get("x", 0.0)), 300.0), str(ex.get("to", "")))


func _build_player(data: Dictionary) -> void:
    player = CharacterBody2D.new()
    player.set_script(PlayerScript)
    player.name = "Player"
    player.position = data.get("spawn", Vector2(200, 360))
    # 相机移动范围跟随房间宽度
    player.set("camera_limit_right", float(data.width))
    add_child(player)


func _build_hud(data: Dictionary) -> void:
    var hud := CanvasLayer.new()
    hud.set_script(HudScript)
    hud.name = "HUD"
    hud.set("room_name", str(data.get("name", "")))
    add_child(hud)


# ---- 各类实体的生成小工具 ----

func _make_enemy(pos: Vector2, id: String, min_x: float, max_x: float) -> void:
    var enemy = CharacterBody2D.new()
    enemy.set_script(EnemyScript)
    enemy.name = "Enemy_" + id
    enemy.position = pos
    enemy.set("enemy_id", id)
    enemy.set("patrol_min_x", min_x)
    enemy.set("patrol_max_x", max_x)
    add_child(enemy)


func _make_npc(pos: Vector2, id: String) -> void:
    var npc = Area2D.new()
    npc.set_script(NpcScript)
    npc.name = "Npc_" + id
    npc.position = pos
    npc.set("npc_id", id)
    add_child(npc)


func _make_door(pos: Vector2, to_room: String) -> void:
    if to_room == "":
        return
    var door = Area2D.new()
    door.set_script(DoorScript)
    door.name = "Door_" + to_room
    door.position = pos
    door.set("to_room", to_room)
    add_child(door)


func _make_breakable(pos: Vector2, size: Vector2, color: Color) -> void:
    var sb := StaticBody2D.new()
    sb.set_script(BreakableScript)
    sb.position = pos
    var shape := RectangleShape2D.new()
    shape.size = size
    var cs := CollisionShape2D.new()
    cs.shape = shape
    sb.add_child(cs)
    sb.add_child(_rect(size, color))
    add_child(sb)


func _make_static(pos: Vector2, size: Vector2, color: Color) -> void:
    var sb := StaticBody2D.new()
    sb.position = pos
    var shape := RectangleShape2D.new()
    shape.size = size
    var cs := CollisionShape2D.new()
    cs.shape = shape
    sb.add_child(cs)
    sb.add_child(_rect(size, color))
    add_child(sb)


func _rect(size: Vector2, color: Color) -> Polygon2D:
    var p := Polygon2D.new()
    var h := size * 0.5
    p.polygon = PackedVector2Array([
        Vector2(-h.x, -h.y), Vector2(h.x, -h.y),
        Vector2(h.x, h.y), Vector2(-h.x, h.y)
    ])
    p.color = color
    return p