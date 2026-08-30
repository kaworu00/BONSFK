extends CanvasLayer
# ============================================================
# ending_menu.gd —— 结局界面
# 作用：时间配额耗尽 / 击败 Boss 后，根据封印值显示三种结局。
# 操作：回车 / 空格回到主菜单。
# ============================================================

var kind := "normal"


func _ready() -> void:
    layer = 200
    process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().paused = true   # 暂停游戏
    _build()


func _build() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.03, 0.04, 0.08)
    bg.size = Vector2(960, 540)
    add_child(bg)

    var title_text := ""
    var body_text := ""
    var color := Color.WHITE
    match kind:
        "true":
            title_text = "真结局 · 山海归位"
            body_text = "十二位英魂尽数归位，封印彻底完成。\n山海之间重归宁静，你把引渡的灯，轻轻放下。"
            color = Color(0.6, 1.0, 0.7)
        "normal":
            title_text = "普通结局 · 封印未满"
            body_text = "相繇虽败，封印却因英魂未齐而未能圆满。\n山海的门，还留着一道缝……"
            color = Color(0.9, 0.85, 0.6)
        _:
            title_text = "坏结局 · 山海关闭"
            body_text = "时间已尽，山海之门再次缓缓闭合。\n那些还未归位的英魂，将永远留在这片雾里。"
            color = Color(1.0, 0.6, 0.6)

    var title := GlobalState.make_label(title_text, 40, color)
    title.position = Vector2(210, 90)
    title.size = Vector2(540, 50)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(title)

    var body := GlobalState.make_label(body_text, 18, Color(0.9, 0.92, 0.95))
    body.position = Vector2(220, 180)
    body.size = Vector2(520, 120)
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(body)

    var stat := GlobalState.make_label(
        "引渡英灵 %d 位 · 封印值 %d · 经验水晶 %d" % [GlobalState.recruited.size(), GlobalState.seal_value, GlobalState.exp_crystals],
        15, Color(0.75, 0.8, 0.9)
    )
    stat.position = Vector2(250, 330)
    add_child(stat)

    var hint := GlobalState.make_label("回车 / 空格 — 回到主菜单", 16, Color(0.7, 0.75, 0.85))
    hint.position = Vector2(340, 410)
    add_child(hint)


func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("menu_confirm"):
        get_tree().paused = false
        queue_free()
        EventBus.menu_requested.emit()