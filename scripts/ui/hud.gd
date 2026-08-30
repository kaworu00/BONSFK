extends CanvasLayer
# ============================================================
# hud.gd —— 探索界面 HUD
# 作用：显示队伍、经验水晶、操作提示；F5 存档 / F9 读档；
#       按 T 打开「英灵升格」加点、按 N 打开「队伍编制」
#       （两个界面打开时都会暂停探索，互斥）。
# ============================================================

const UpgradeMenuScript := preload("res://scripts/ui/upgrade_menu.gd")
const PartyMenuScript := preload("res://scripts/ui/party_menu.gd")

var party_label: Label
var exp_label: Label
var time_label: Label
var title_label: Label
var upgrade_menu = null
var party_menu = null
var room_name := ""
var _base_title := ""


func _ready() -> void:
    layer = 10
    _base_title = "山海引魂录 · " + room_name
    title_label = GlobalState.make_label(_base_title, 18)
    title_label.position = Vector2(20, 12)
    add_child(title_label)

    party_label = GlobalState.make_label("", 14)
    party_label.position = Vector2(20, 42)
    add_child(party_label)

    exp_label = GlobalState.make_label("", 14)
    exp_label.position = Vector2(20, 62)
    add_child(exp_label)

    time_label = GlobalState.make_label("", 14, Color(1, 0.85, 0.4))
    time_label.position = Vector2(20, 82)
    add_child(time_label)

    var hint := GlobalState.make_label(
        "A/D 移动 · 空格 跳 · S 蹲 · J 灵石 · E 对话 · T 升级 · N 编队 · 碰魔物进战斗 · F5/F9 存读档", 13,
        Color(0.75, 0.8, 0.9)
    )
    hint.position = Vector2(20, 500)
    add_child(hint)


func _process(_delta: float) -> void:
    # 实时刷新队伍与水晶显示
    var names: Array = []
    for id in GlobalState.party:
        var cd := load("res://scripts/data/characters/" + str(id) + ".tres") as CharacterData
        names.append(cd.display_name if cd != null else str(id))
    party_label.text = "队伍：" + ("、".join(names) if not names.is_empty() else "空（靠近发光的英灵按 E 招募）")
    exp_label.text = "经验水晶：%d" % GlobalState.exp_crystals
    time_label.text = "章节 %d · 剩余回合 %d · 封印值 %d" % [GlobalState.chapter, GlobalState.periods, GlobalState.seal_value]

    # 存档 / 读档
    if Input.is_action_just_pressed("save"):
        SaveManager.save_game()
        _flash_title("已保存（F9 读取）")
    elif Input.is_action_just_pressed("load"):
        if SaveManager.load_game():
            _flash_title("已读取存档")
        else:
            _flash_title("没有找到存档")

    # T 打开升格界面 / N 打开队伍编制（关闭由界面自己处理）
    if Input.is_action_just_pressed("upgrade"):
        _open_upgrade()
    elif Input.is_action_just_pressed("party"):
        _open_party()


# 标题短暂显示一段提示，1.6 秒后恢复成「房间名」
func _flash_title(msg: String) -> void:
    title_label.text = msg
    var t := get_tree().create_timer(1.6)
    t.timeout.connect(_restore_title)


func _restore_title() -> void:
    title_label.text = _base_title


func _open_upgrade() -> void:
    if _menu_open():
        return
    var um = UpgradeMenuScript.new()
    um.name = "UpgradeMenu"
    add_child(um)
    upgrade_menu = um
    get_tree().paused = true  # 暂停探索（界面自身 process_mode=ALWAYS 仍会运行）


func _open_party() -> void:
    if _menu_open():
        return
    var pm = PartyMenuScript.new()
    pm.name = "PartyMenu"
    add_child(pm)
    party_menu = pm
    get_tree().paused = true


# 两个菜单互斥：已有任意一个开着就不重复打开
func _menu_open() -> bool:
    var up_open := upgrade_menu != null and is_instance_valid(upgrade_menu)
    var pa_open := party_menu != null and is_instance_valid(party_menu)
    return up_open or pa_open