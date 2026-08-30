extends Node2D
# ============================================================
# main.gd —— 主控
# 负责流程切换：主菜单 → 房间探索 ⇄ 战斗
#   - 启动时先显示主菜单（新的航行 / 继续）
#   - 菜单通过 EventBus.game_start_requested 通知本脚本开始
#   - 房间之间用门（door.gd）切换；碰敌人进战斗，战斗结束回房间
# ============================================================

const RoomScript := preload("res://scripts/exploration/room.gd")
const BattleScene := preload("res://scenes/battle/battle.tscn")
const MenuScript := preload("res://scripts/ui/main_menu.gd")

var room: Node2D   # 当前房间
var battle         # 战斗场景实例（脚本有自定义属性 enemy_id，动态访问）
var menu


func _ready() -> void:
    EventBus.game_start_requested.connect(_on_game_start)
    EventBus.battle_requested.connect(_on_battle_requested)
    EventBus.battle_finished.connect(_on_battle_finished)
    EventBus.room_exit_requested.connect(_on_room_exit)
    _show_menu()


func _show_menu() -> void:
    menu = MenuScript.new()
    menu.name = "MainMenu"
    add_child(menu)


func _on_game_start(new_game: bool) -> void:
    if new_game:
        GlobalState.reset_progress()
    elif not SaveManager.load_game():
        return  # 读档失败（菜单里已做过存在性判断，这里双保险）
    # 关闭菜单，进入存档记录的房间（新游戏则是第一关）
    if menu != null and is_instance_valid(menu):
        menu.queue_free()
        menu = null
    _enter_room(GlobalState.current_room)


func _enter_room(room_id: String) -> void:
    if room != null and is_instance_valid(room):
        room.queue_free()
    GlobalState.current_room = room_id
    room = RoomScript.new()
    room.name = "Room"
    room.set("room_id", room_id)
    add_child(room)


func _on_room_exit(to_room: String) -> void:
    _enter_room(to_room)


func _on_battle_requested(enemy_id: String) -> void:
    if battle != null:
        return  # 已经在战斗中，忽略重复请求
    # 冻结并隐藏房间层（避免玩家还能动，也避免探索相机干扰战斗画面）
    room.process_mode = Node.PROCESS_MODE_DISABLED
    room.visible = false

    battle = BattleScene.instantiate()
    battle.set("enemy_id", enemy_id)
    add_child(battle)


func _on_battle_finished(_won: bool) -> void:
    if battle != null:
        battle.queue_free()
        battle = null
    # 恢复房间层
    room.process_mode = Node.PROCESS_MODE_INHERIT
    room.visible = true
    _restore_camera()


# 战斗结束后，把相机还给房间里的玩家相机。
func _restore_camera() -> void:
    var cams := get_tree().get_nodes_in_group("exploration_camera")
    if not cams.is_empty():
        var cam := cams[0] as Camera2D
        if cam != null:
            cam.make_current()