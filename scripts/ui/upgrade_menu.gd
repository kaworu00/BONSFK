extends CanvasLayer
# ============================================================
# upgrade_menu.gd —— 英灵升格（加点）界面
# 作用：消耗「经验水晶」给英灵永久提升生命 / 攻击。
#   生命每点 +10，攻击每点 +2；每点消耗 10 经验水晶。
# 操作：W/S 选人 · A/D 切换生命/攻击 · 回车 加点 ·
#       Q/E 翻页（当英灵超过一页时）· T 或 Esc 关闭。
# 加的数值存进 GlobalState.boosts，战斗时会叠加到角色基础属性上。
# ============================================================

const COST := 10            # 每点消耗水晶
const HP_GAIN := 10         # 每点生命 +10
const ATK_GAIN := 2         # 每点攻击 +2
const ROWS_PER_PAGE := 6    # 每页显示 6 行英灵

var char_ids: Array = []   # 可选角色 id 列表（图鉴顺序）
var select_char := 0       # 当前选中英灵的全局下标
var select_attr := 0       # 0=生命，1=攻击
var page := 0              # 当前页

var _labels: Array = []
var _crystal_lbl: Label
var _attr_lbl: Label
var _status: Label


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停探索时本界面仍运行
    layer = 60
    # 可选角色 = 已招募的英灵（即图鉴）；还没有招到人时用默认两个，保证有得加
    char_ids = GlobalState.recruited.keys()
    if char_ids.is_empty():
        char_ids = ["houyi", "jingwei"]
    _build()
    _refresh()


func _build() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.03, 0.03, 0.08, 0.93)
    bg.size = Vector2(960, 540)
    add_child(bg)

    var title := GlobalState.make_label("英灵升格 · 调配神魂", 26, Color(0.6, 0.9, 1.0))
    title.position = Vector2(60, 50)
    add_child(title)

    _crystal_lbl = GlobalState.make_label("", 18, Color(1, 0.9, 0.4))
    _crystal_lbl.position = Vector2(60, 100)
    add_child(_crystal_lbl)

    _attr_lbl = GlobalState.make_label("", 16, Color(0.8, 1, 0.8))
    _attr_lbl.position = Vector2(60, 130)
    add_child(_attr_lbl)

    # 固定 6 行，超出当前页的英灵显示为空行
    for i in range(ROWS_PER_PAGE):
        var lbl := GlobalState.make_label("", 17, Color(0.92, 0.92, 0.92))
        lbl.position = Vector2(60, 168 + i * 40)
        add_child(lbl)
        _labels.append(lbl)

    _status = GlobalState.make_label("", 15, Color(1, 0.6, 0.6))
    _status.position = Vector2(60, 412)
    add_child(_status)

    var hint := GlobalState.make_label(
        "W/S 选人 · A/D 切换生命/攻击 · 回车 加点 · Q/E 翻页 · T 或 Esc 关闭", 14, Color(0.7, 0.75, 0.85)
    )
    hint.position = Vector2(60, 470)
    add_child(hint)


func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("menu_up"):
        _move_selection(-1)
    elif Input.is_action_just_pressed("menu_down"):
        _move_selection(1)
    elif Input.is_action_just_pressed("move_left"):
        select_attr = 0
        _status.text = ""
        _refresh()
    elif Input.is_action_just_pressed("move_right"):
        select_attr = 1
        _status.text = ""
        _refresh()
    elif Input.is_action_just_pressed("page_prev"):
        _flip_page(-1)
    elif Input.is_action_just_pressed("page_next"):
        _flip_page(1)
    elif Input.is_action_just_pressed("menu_confirm"):
        _buy()
    elif Input.is_action_just_pressed("upgrade") or Input.is_action_just_pressed("menu_cancel"):
        _close()


func _move_selection(delta: int) -> void:
    if char_ids.is_empty():
        return
    select_char = (select_char + delta + char_ids.size()) % char_ids.size()
    page = int(select_char / ROWS_PER_PAGE)
    _status.text = ""
    _refresh()


func _flip_page(delta: int) -> void:
    if char_ids.is_empty():
        return
    page = clampi(page + delta, 0, _total_pages() - 1)
    select_char = page * ROWS_PER_PAGE
    _status.text = ""
    _refresh()


func _total_pages() -> int:
    return maxi(1, ceili(char_ids.size() / float(ROWS_PER_PAGE)))


func _buy() -> void:
    if char_ids.is_empty():
        _status.text = "没有可升格的角色"
        return
    if GlobalState.exp_crystals < COST:
        _status.text = "经验水晶不足（每点需要 %d）" % COST
        return
    var id: String = char_ids[select_char]
    if not GlobalState.boosts.has(id):
        GlobalState.boosts[id] = {"hp": 0, "atk": 0}
    var b: Dictionary = GlobalState.boosts[id]
    if select_attr == 0:
        b["hp"] = int(b.get("hp", 0)) + 1
    else:
        b["atk"] = int(b.get("atk", 0)) + 1
    GlobalState.exp_crystals -= COST
    _status.text = "升格成功！"
    _refresh()


func _close() -> void:
    get_tree().paused = false
    queue_free()


func _refresh() -> void:
    _crystal_lbl.text = "经验水晶：%d（每点 %d 水晶）" % [GlobalState.exp_crystals, COST]
    var attr_name := "生命 +%d" % HP_GAIN
    if select_attr == 1:
        attr_name = "攻击 +%d" % ATK_GAIN
    _attr_lbl.text = "当前加点：%s　·　英灵 %d/%d 位　第 %d/%d 页" % [
        attr_name, char_ids.size(), char_ids.size(), page + 1, _total_pages()
    ]
    for i in range(_labels.size()):
        _labels[i].text = _line_text(i)


func _line_text(row: int) -> String:
    var idx := page * ROWS_PER_PAGE + row
    if idx >= char_ids.size():
        return ""
    var id: String = char_ids[idx]
    var cd := load("res://scripts/data/characters/" + id + ".tres") as CharacterData
    if cd == null:
        return id
    var b: Dictionary = GlobalState.boosts.get(id, {})
    var hp_b := int(b.get("hp", 0))
    var atk_b := int(b.get("atk", 0))
    var mark := "▶ " if idx == select_char else "   "
    var attr := ""
    if idx == select_char:
        attr = "  【%s】" % ("生命" if select_attr == 0 else "攻击")
    return "%s%s  生命 %d(+%d)  攻击 %d(+%d)%s" % [
        mark, cd.display_name, cd.max_hp + hp_b * HP_GAIN, hp_b,
        cd.attack + atk_b * ATK_GAIN, atk_b, attr
    ]