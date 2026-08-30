extends Area2D
# ============================================================
# npc.gd —— 可招募英灵
# 作用：玩家靠近后按 E 触发「招募」，显示身世故事并加入队伍。
# 对应 VP 里「遇到死去的英雄，看完一段故事后招募」的核心体验。
# ============================================================

var npc_id := "houyi"
var in_range := false
var recruited := false
var is_service := false   # 是否特殊设施（_healer 治疗神龛 / _merchant 行商）

var _hint: Label


func _ready() -> void:
    collision_layer = 1
    collision_mask = 2

    # 特殊设施（治疗神龛 / 行商）走独立构建
    if npc_id.begins_with("_"):
        is_service = true
        _build_service()
        return

    # 读档/已招募状态贯通：如果这个英灵已被招募过，直接标记为已招募
    if GlobalState.recruited.has(npc_id):
        recruited = true

    # 检测范围（比可视大，方便触发）
    var shape := RectangleShape2D.new()
    shape.size = Vector2(90, 90)
    var cs := CollisionShape2D.new()
    cs.shape = shape
    add_child(cs)

    # 英灵形象：优先加载 res://art/heroes/<id>.png，缺图回落发光色块
    var body := GlobalState.make_art_node("res://art/heroes/" + npc_id + ".png", Vector2(20, 40), Color(0.6, 0.9, 1.0))
    body.position = Vector2(0, -18)
    add_child(body)
    var halo := _rect(Vector2(30, 12), Color(1, 1, 0.6, 0.5))
    halo.position = Vector2(0, -44)
    add_child(halo)

    # 从角色数据里读显示名，这样一个脚本能通用于所有英灵
    var cd := load("res://scripts/data/characters/" + npc_id + ".tres") as CharacterData
    var shown_name := cd.display_name if cd != null else npc_id
    var suffix := "（英灵·已入队）" if recruited else "（英灵）"
    var name_lbl := GlobalState.make_label(shown_name + suffix, 13, Color(0.8, 0.95, 1))
    name_lbl.position = Vector2(-40, -70)
    add_child(name_lbl)

    _hint = GlobalState.make_label("", 13, Color(1, 1, 0.5))
    _hint.position = Vector2(-50, -92)
    add_child(_hint)

    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        in_range = true


func _on_body_exited(body: Node2D) -> void:
    if body.is_in_group("player"):
        in_range = false


func _process(_delta: float) -> void:
    if is_service:
        if in_range:
            _hint.text = "按 E " + ("恢复全队生命" if npc_id == "_healer" else "打开商店")
            if Input.is_action_just_pressed("interact"):
                if npc_id == "_healer":
                    _heal()
                else:
                    _open_shop()
        else:
            _hint.text = ""
        return

    # 读档后可重新同步「已招募」状态
    if not recruited and GlobalState.recruited.has(npc_id):
        recruited = true
    if recruited:
        _hint.text = ""
        return
    if in_range:
        _hint.text = "按 E 招募"
        if Input.is_action_just_pressed("interact"):
            _recruit()
    else:
        _hint.text = ""


func _recruit() -> void:
    var cd := load("res://scripts/data/characters/" + npc_id + ".tres") as CharacterData
    if cd == null:
        return  # 数据文件缺失，不继续（避免空指针崩溃）
    recruited = true
    GlobalState.recruited[npc_id] = cd.display_name
    # 前 4 位自动加入出战队伍；队伍满员后，其余英灵收入「英灵图鉴」，
    # 依然可以在升格界面（T）培养。
    var joined := false
    if GlobalState.party.size() < 4 and not GlobalState.party.has(npc_id):
        GlobalState.party.append(npc_id)
        joined = true
    EventBus.npc_recruited.emit(npc_id)
    AudioManager.play("recruit")
    _show_story(cd, joined)


func _show_story(cd: CharacterData, joined: bool) -> void:
    # 用一层 CanvasLayer 弹一个简易对话框，几秒后消失。
    # 注意：这里挂到 root 而不是挂到 NPC 节点下，
    # 因为挂到 CanvasItem（Node2D）下会继承它的位移，导致对话框位置偏移。
    var layer := CanvasLayer.new()
    layer.layer = 20
    get_tree().root.add_child(layer)

    var box := ColorRect.new()
    box.color = Color(0, 0, 0, 0.82)
    box.size = Vector2(620, 150)
    box.position = Vector2(170, 365)
    layer.add_child(box)

    var tail := "（已加入出战队伍）" if joined else "（队伍已满，已收入英灵图鉴，可按 T 培养）"
    var lbl := GlobalState.make_label(
        "【%s】\n%s\n\n%s" % [cd.display_name, cd.story, tail], 15
    )
    lbl.position = Vector2(190, 380)
    lbl.size = Vector2(580, 120)
    lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layer.add_child(lbl)

    var timer := get_tree().create_timer(5.0)
    timer.timeout.connect(layer.queue_free)


# ---- 特殊设施：治疗神龛 / 行商 ----
func _build_service() -> void:
    var is_heal := npc_id == "_healer"
    var title := "治疗神龛" if is_heal else "行商"
    var color := Color(0.3, 0.95, 0.6) if is_heal else Color(1, 0.85, 0.4)
    var shape := RectangleShape2D.new()
    shape.size = Vector2(90, 90)
    var cs := CollisionShape2D.new()
    cs.shape = shape
    add_child(cs)
    var body := GlobalState.make_art_node("res://art/shrine.png" if is_heal else "res://art/merchant.png", Vector2(32, 40), color)
    body.position = Vector2(0, -18)
    add_child(body)
    var halo := _rect(Vector2(34, 12), Color(0.5, 1, 0.6, 0.5) if is_heal else Color(1, 0.9, 0.4, 0.5))
    halo.position = Vector2(0, -44)
    add_child(halo)
    var name_lbl := GlobalState.make_label(title, 13, Color(0.8, 1, 0.9))
    name_lbl.position = Vector2(-40, -70)
    add_child(name_lbl)
    _hint = GlobalState.make_label("", 13, Color(1, 1, 0.5))
    _hint.position = Vector2(-64, -92)
    add_child(_hint)
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)


func _heal() -> void:
    var count := 0
    for id in GlobalState.party:
        var cd := load("res://scripts/data/characters/" + id + ".tres") as CharacterData
        if cd != null:
            var bonus := 15 if GlobalState.has_trinket("xuanwulin") else 0
            GlobalState.party_hp[id] = cd.max_hp + bonus
            count += 1
    if count == 0:
        _show_service_msg("队伍还是空的，先在前方招募英灵吧。")
    else:
        AudioManager.play("heal")
        _show_service_msg("神龛光芒洒下，%d 名英灵生命恢复全满！" % count)


func _open_shop() -> void:
    var Shop := preload("res://scripts/ui/shop_menu.gd")
    var m = Shop.new()
    get_tree().root.add_child(m)


func _show_service_msg(text: String) -> void:
    var layer := CanvasLayer.new()
    layer.layer = 20
    get_tree().root.add_child(layer)
    var box := ColorRect.new()
    box.color = Color(0, 0, 0, 0.82)
    box.size = Vector2(520, 90)
    box.position = Vector2(220, 400)
    layer.add_child(box)
    var lbl := GlobalState.make_label(text, 15)
    lbl.position = Vector2(242, 415)
    lbl.size = Vector2(480, 60)
    lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layer.add_child(lbl)
    var timer := get_tree().create_timer(2.5)
    timer.timeout.connect(layer.queue_free)


func _rect(size: Vector2, color: Color) -> Polygon2D:
    var p := Polygon2D.new()
    var h := size * 0.5
    p.polygon = PackedVector2Array([
        Vector2(-h.x, -h.y), Vector2(h.x, -h.y),
        Vector2(h.x, h.y), Vector2(-h.x, h.y)
    ])
    p.color = color
    return p