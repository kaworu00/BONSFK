extends CanvasLayer
# ============================================================
# main_menu.gd —— 主菜单
# 作用：游戏启动后显示标题与两个选项：
#   「新的航行」→ 清空进度开始
#   「继续」     → 读档继续（没有存档就提示）
# 键盘：W/S 或 ↑/↓ 选择，回车/空格 确认。
# ============================================================

var options := ["新的航行", "继续"]
var index := 0
var _labels: Array = []
var _status: Label


func _ready() -> void:
    layer = 100
    _build()
    _refresh()


func _build() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.05, 0.07, 0.13)
    bg.size = Vector2(960, 540)
    add_child(bg)

    # 底部山影装饰
    var m1 := _square(Vector2(340, 170), Color(0.09, 0.11, 0.2))
    m1.position = Vector2(180, 520)
    add_child(m1)
    var m2 := _square(Vector2(240, 120), Color(0.08, 0.1, 0.18))
    m2.position = Vector2(680, 545)
    add_child(m2)

    var title := GlobalState.make_label("山海引魂录", 54, Color(0.6, 0.9, 1.0))
    title.position = Vector2(230, 80)
    add_child(title)

    var sub := GlobalState.make_label("以灵石引渡山海英魂 · 演示版", 18, Color(0.75, 0.82, 0.92))
    sub.position = Vector2(318, 150)
    add_child(sub)

    for i in range(options.size()):
        var lbl := GlobalState.make_label("", 24, Color(0.9, 0.9, 0.9))
        lbl.position = Vector2(380, 250 + i * 60)
        add_child(lbl)
        _labels.append(lbl)

    _status = GlobalState.make_label("", 15, Color(1, 0.6, 0.6))
    _status.position = Vector2(330, 405)
    _status.size = Vector2(400, 24)
    add_child(_status)

    var hint := GlobalState.make_label("W / S 选择 · 回车 确认", 15, Color(0.7, 0.75, 0.85))
    hint.position = Vector2(380, 470)
    add_child(hint)


func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("menu_up"):
        index = (index - 1 + options.size()) % options.size()
        _refresh()
    elif Input.is_action_just_pressed("menu_down"):
        index = (index + 1) % options.size()
        _refresh()
    elif Input.is_action_just_pressed("menu_confirm"):
        _confirm()


func _confirm() -> void:
    if index == 0:
        EventBus.game_start_requested.emit(true)
    elif FileAccess.file_exists(SaveManager.SAVE_PATH):
        EventBus.game_start_requested.emit(false)
    else:
        _status.text = "没有找到存档（先开始游戏，探索中按 F5 存档）"


func _refresh() -> void:
    for i in range(_labels.size()):
        _labels[i].text = ("▶ " if i == index else "   ") + options[i]


func _square(size: Vector2, color: Color) -> Polygon2D:
    var p := Polygon2D.new()
    var h := size * 0.5
    p.polygon = PackedVector2Array([
        Vector2(-h.x, -h.y), Vector2(h.x, -h.y),
        Vector2(h.x, h.y), Vector2(-h.x, h.y)
    ])
    p.color = color
    return p