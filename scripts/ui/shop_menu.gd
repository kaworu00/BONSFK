extends CanvasLayer
# ============================================================
# shop_menu.gd —— 行商商店
# 作用：用「经验水晶」购买全局被动饰品，买完立即在战斗里生效。
# 操作：W/S 选择，回车购买，Esc / E 关闭。
# ============================================================

var ids := ["julingyu", "xuanwulin", "chiyanfu"]
var sel := 0
var _rows: Array = []
var _msg: Label
var _crystal_lbl: Label


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

    var veil := ColorRect.new()
    veil.color = Color(0, 0, 0, 0.6)
    veil.size = Vector2(960, 540)
    add_child(veil)

    var title := GlobalState.make_label("行商 · 以经验水晶交换珍宝", 20, Color(1, 0.9, 0.5))
    title.position = Vector2(300, 70)
    add_child(title)

    _crystal_lbl = GlobalState.make_label("", 15, Color(1, 0.85, 0.3))
    _crystal_lbl.position = Vector2(300, 104)
    add_child(_crystal_lbl)

    _msg = GlobalState.make_label("", 13, Color(1, 0.75, 0.75))
    _msg.position = Vector2(300, 420)
    _msg.size = Vector2(380, 30)
    add_child(_msg)

    var footer := GlobalState.make_label("W/S 选择 · 回车购买 · Esc 关闭", 13, Color(0.75, 0.8, 0.9))
    footer.position = Vector2(300, 485)
    add_child(footer)

    _refresh()


func _refresh() -> void:
    _crystal_lbl.text = "当前经验水晶：%d" % GlobalState.exp_crystals
    for r in _rows:
        r.queue_free()
    _rows.clear()
    for i in range(ids.size()):
        var id: String = ids[i]
        var t: Dictionary = GlobalState.TRINKETS[id]
        var owned := GlobalState.has_trinket(id)
        var prefix := "▶ " if i == sel else "   "
        var state := "  [已拥有]" if owned else ""
        var line := "%s%s — %d 水晶：%s%s" % [prefix, str(t.name), int(t.cost), str(t.desc), state]
        var lbl := GlobalState.make_label(
            line, 15, Color(1, 1, 0.8) if i == sel else Color(0.85, 0.85, 0.9)
        )
        lbl.position = Vector2(300, 140 + i * 46)
        add_child(lbl)
        _rows.append(lbl)


func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("menu_up"):
        sel = (sel - 1 + ids.size()) % ids.size()
        _refresh()
    elif Input.is_action_just_pressed("menu_down"):
        sel = (sel + 1) % ids.size()
        _refresh()
    elif Input.is_action_just_pressed("menu_confirm"):
        _buy()
    elif Input.is_action_just_pressed("menu_cancel") or Input.is_action_just_pressed("interact"):
        queue_free()


func _buy() -> void:
    var id: String = ids[sel]
    var t: Dictionary = GlobalState.TRINKETS[id]
    if GlobalState.has_trinket(id):
        _msg.text = "这件已经拥有了。"
        return
    if GlobalState.exp_crystals < int(t.cost):
        _msg.text = "水晶不足，还差 %d。" % (int(t.cost) - GlobalState.exp_crystals)
        return
    GlobalState.exp_crystals -= int(t.cost)
    GlobalState.trinkets.append(id)
    AudioManager.play("buy")
    _msg.text = "购入「%s」！" % str(t.name)
    _refresh()