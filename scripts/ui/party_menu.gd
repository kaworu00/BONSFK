extends CanvasLayer
# ============================================================
# party_menu.gd —— 队伍编制界面
# 作用：从「英灵图鉴」（已招募的英灵）里挑选最多 4 位出战。
#   打开时暂停探索，编队结果直接写进 GlobalState.party，
#   战斗会读取 party 决定谁上场；存档也会保存 party。
# 操作：W/S 选人 · 回车 出战/移出 · Q/E 翻页 · N 或 Esc 关闭。
# ============================================================

const ROWS_PER_PAGE := 6    # 每页显示 6 行英灵

var char_ids: Array = []   # 图鉴里的角色 id（= 已招募顺序）
var select_char := 0       # 当前选中英灵的全局下标
var page := 0              # 当前页

var _labels: Array = []        # 图鉴 6 行
var _slot_labels: Array = []   # 出战队伍 4 槽
var _status: Label


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停探索时本界面仍运行
    layer = 60
    char_ids = GlobalState.recruited.keys()
    _build()
    _refresh()


func _build() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.03, 0.03, 0.08, 0.93)
    bg.size = Vector2(960, 540)
    add_child(bg)

    var title := GlobalState.make_label("队伍编制 · 出阵英灵", 26, Color(0.6, 0.9, 1.0))
    title.position = Vector2(60, 45)
    add_child(title)

    var slot_hint := GlobalState.make_label("出战队伍（最多 4 人）：", 16, Color(0.8, 1, 0.8))
    slot_hint.position = Vector2(60, 85)
    add_child(slot_hint)

    for i in range(4):
        var lbl := GlobalState.make_label("", 16, Color(1, 1, 1))
        lbl.position = Vector2(60 + i * 200, 115)
        add_child(lbl)
        _slot_labels.append(lbl)

    var div := GlobalState.make_label("——————— 英灵图鉴（回车 编入 / 移出）———————", 15, Color(0.6, 0.62, 0.7))
    div.position = Vector2(60, 150)
    add_child(div)

    for i in range(ROWS_PER_PAGE):
        var lbl := GlobalState.make_label("", 17, Color(0.92, 0.92, 0.92))
        lbl.position = Vector2(60, 190 + i * 40)
        add_child(lbl)
        _labels.append(lbl)

    _status = GlobalState.make_label("", 15, Color(1, 0.6, 0.6))
    _status.position = Vector2(60, 440)
    add_child(_status)

    var hint := GlobalState.make_label(
        "W/S 选人 · 回车 出战/移出 · Q/E 翻页 · N 或 Esc 关闭", 14, Color(0.7, 0.75, 0.85)
    )
    hint.position = Vector2(60, 490)
    add_child(hint)


func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("menu_up"):
        _move_selection(-1)
    elif Input.is_action_just_pressed("menu_down"):
        _move_selection(1)
    elif Input.is_action_just_pressed("page_prev"):
        _flip_page(-1)
    elif Input.is_action_just_pressed("page_next"):
        _flip_page(1)
    elif Input.is_action_just_pressed("menu_confirm"):
        _toggle()
    elif Input.is_action_just_pressed("party") or Input.is_action_just_pressed("menu_cancel"):
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


func _toggle() -> void:
    if char_ids.is_empty():
        _status.text = "尚未招募英灵（探索中靠近发光的英灵按 E）"
        return
    var id: String = char_ids[select_char]
    if GlobalState.party.has(id):
        GlobalState.party.erase(id)
        _status.text = "已移出出战队伍"
    elif GlobalState.party.size() < 4:
        GlobalState.party.append(id)
        _status.text = "已加入出战队伍"
    else:
        _status.text = "队伍已满（4 人）——先对「出战中」的英灵按回车移出，再编入新人"
    _refresh()


func _close() -> void:
    get_tree().paused = false
    queue_free()


func _refresh() -> void:
    for i in range(_slot_labels.size()):
        _slot_labels[i].text = _slot_text(i)
    if char_ids.is_empty():
        for i in range(_labels.size()):
            _labels[i].text = ""
        _labels[0].text = "（还没有招募到英灵）"
        return
    for i in range(_labels.size()):
        _labels[i].text = _line_text(i)


func _slot_text(i: int) -> String:
    if i < GlobalState.party.size():
        var id: String = GlobalState.party[i]
        var cd := load("res://scripts/data/characters/" + id + ".tres") as CharacterData
        if cd == null:
            return "%d. %s" % [i + 1, id]
        var role := "法师" if cd.is_mage else "近战"
        return "%d. %s·%s" % [i + 1, cd.display_name, role]
    return "%d. ——（空）" % (i + 1)


func _line_text(row: int) -> String:
    var idx := page * ROWS_PER_PAGE + row
    if idx >= char_ids.size():
        return ""
    var id: String = char_ids[idx]
    var cd := load("res://scripts/data/characters/" + id + ".tres") as CharacterData
    if cd == null:
        return id
    var mark := "▶ " if idx == select_char else "   "
    var role := "法师" if cd.is_mage else "近战"
    var in_team := "✓ 出战中" if GlobalState.party.has(id) else "未出战"
    var tail := ""
    if idx == select_char and char_ids.size() > ROWS_PER_PAGE:
        tail = "    第 %d/%d 页" % [page + 1, _total_pages()]
    return "%s%s（%s） [%s]%s" % [mark, cd.display_name, role, in_team, tail]
