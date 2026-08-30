extends Node2D
# ============================================================
# battle.gd —— 战斗控制器（「北欧女神」式战斗 · 阶段 3 版）
# 相对阶段 2 新增四项：
#   1. 前后排站位：近战站前排当肉盾，法师站后排施法
#   2. 连段浮空计数：命中累积「连段」，敌人被击飞浮空，连段越高伤害越高
#   3. 法师范围魔法：法师的攻击打中全体敌人（范围特效）
#   4. 多目标敌人：一场战斗可出现多个敌人，各自有血条、独立倒下
# 操作：U/I/O/P = 四名队友   K = 决之技
# ============================================================

const CHAR_PATH := "res://scripts/data/characters/"
const ENEMY_PATH := "res://scripts/data/enemies/"
const DEFAULT_PARTY := ["houyi", "jingwei"]

# 遇敌组：enemy_id 决定这场战斗出现哪些敌人（数值/图鉴读 EnemyData .tres）
# 落单怪 → 带小弟 → 双头目，逐步升级，演示「多目标」战斗
const ENEMY_GROUPS := {
    "taowu": ["taowu"],
    "qiongqi": ["qiongqi", "taowu"],
    "hundun": ["hundun"],
    "jiuying": ["jiuying", "hundun"],
    "xiangliu": ["xiangliu", "jiuying"],
    "taotie": ["taotie"],
    "zaochi": ["zaochi", "taotie"],
    "xiangyao": ["xiangyao"],
}

var enemy_id := "taowu"

var party_data: Array = []   # Array[CharacterData]
var fighters: Array = []     # 每个元素 Dictionary {data, hp, key, node, is_mage}
var enemies: Array = []      # 每个元素 Dictionary {id, name, hp, max_hp, atk, node, body, bar, dead}

var hit_gauge: float = 0.0   # 连击槽 0~100
var combo: int = 0           # 连段计数
var finisher_ready: bool = false
var battle_over: bool = false

var enemy_attack_timer: float = 0.0
var enemy_attack_interval: float = 2.6
const WARN_TIME := 0.7       # 反击前蓄力预警时长（秒）
const ATTACK_COOLDOWN := 0.35  # 队友每次出手后的收招间隙（秒）
var warned := false          # 本轮是否已发过蓄力预警

var ui_layer: CanvasLayer
var world: Node2D
var gauge_bar: ProgressBar
var combo_label: Label
var msg_label: Label


func _ready() -> void:
    _build_camera()
    world = Node2D.new()
    world.name = "World"
    add_child(world)
    _setup_ui()
    _load_party()
    _spawn_enemies()
    _spawn_fighters()
    _refresh_ui()
    msg_label.text = "遭遇 %s！U/I/O/P 攻击" % (_enemies_summary())


func _build_camera() -> void:
    var cam := Camera2D.new()
    cam.position = Vector2(480, 270)
    cam.enabled = true
    add_child(cam)
    cam.make_current()


func _setup_ui() -> void:
    ui_layer = CanvasLayer.new()
    add_child(ui_layer)

    var bg := ColorRect.new()
    bg.color = Color(0.05, 0.05, 0.1, 0.94)
    bg.size = Vector2(960, 540)
    bg.position = Vector2.ZERO
    ui_layer.add_child(bg)

    # 连击槽（左上）
    var g_title := GlobalState.make_label("连击槽", 14)
    g_title.position = Vector2(30, 12)
    ui_layer.add_child(g_title)
    gauge_bar = ProgressBar.new()
    gauge_bar.position = Vector2(30, 38)
    gauge_bar.size = Vector2(240, 24)
    gauge_bar.max_value = 100
    gauge_bar.show_percentage = false
    ui_layer.add_child(gauge_bar)

    # 连段计数（连击槽下方）
    combo_label = GlobalState.make_label("连段 x0", 22, Color(1, 0.9, 0.4))
    combo_label.position = Vector2(30, 70)
    ui_layer.add_child(combo_label)

    # 战斗消息
    msg_label = GlobalState.make_label("", 15, Color(0.95, 0.95, 0.8))
    msg_label.position = Vector2(30, 105)
    msg_label.size = Vector2(620, 30)
    ui_layer.add_child(msg_label)

    # 操作提示
    var hint := GlobalState.make_label(
        "U/I/O/P = 四名队友（近战单体 / 法师范围）   连击槽满按 K = 决之技", 13, Color(0.75, 0.8, 0.9)
    )
    hint.position = Vector2(30, 500)
    ui_layer.add_child(hint)

    # 敌人血条（右上，逐个动态生成）
    var e_title := GlobalState.make_label("敌人", 14)
    e_title.position = Vector2(690, 12)
    ui_layer.add_child(e_title)


func _load_party() -> void:
    var ids: Array = GlobalState.party.duplicate()
    if ids.is_empty():
        ids = DEFAULT_PARTY.duplicate()
    for i in range(4):
        if i < ids.size() and ids[i] != "":
            var cd := load(CHAR_PATH + ids[i] + ".tres") as CharacterData
            party_data.append(_apply_boost(cd))
        else:
            var ph := CharacterData.new()
            ph.id = "ph"
            ph.display_name = "空缺"
            ph.max_hp = 80
            ph.attack = 8
            ph.combo_hits = 3
            ph.is_mage = false
            ph.color = Color(0.45, 0.45, 0.5)
            party_data.append(ph)


# 把玩家在「英灵升格」界面加的点叠加到角色上（不污染 .tres 原始数据）
func _apply_boost(cd: CharacterData) -> CharacterData:
    if cd == null:
        return cd
    var copy := cd.duplicate() as CharacterData
    if GlobalState.boosts.has(cd.id):
        var b: Dictionary = GlobalState.boosts[cd.id]
        copy.max_hp += int(b.get("hp", 0)) * 10   # 每点生命 +10
        copy.attack += int(b.get("atk", 0)) * 2   # 每点攻击 +2
    # 饰品全局被动
    if GlobalState.has_trinket("xuanwulin"):
        copy.max_hp += 15   # 玄武鳞：生命上限 +15
    if GlobalState.has_trinket("chiyanfu"):
        copy.attack += 2    # 赤炎符：攻击 +2
    return copy


func _spawn_enemies() -> void:
    var group: Array = ENEMY_GROUPS.get(enemy_id, ENEMY_GROUPS["taowu"])
    var xs: Array = [760.0, 840.0, 680.0]  # 多个敌人错开站位
    for i in range(group.size()):
        _spawn_one_enemy(group[i], xs[i])


# 生成单个敌人（开局布怪 + Boss 召唤小怪共用）
func _spawn_one_enemy(eid: String, x: float) -> Dictionary:
    var ed := load(ENEMY_PATH + eid + ".tres") as EnemyData
    if ed == null:
        return {}
    var e := {
        "id": ed.id,
        "name": ed.display_name,
        "hp": ed.max_hp,
        "max_hp": ed.max_hp,
        "atk": ed.attack,
        "action": ed.action_name,
        "story": ed.story,
        "dead": false,
        "is_boss": ed.is_boss,  # 是否 Boss（分阶段 + 大招）
        "phased": false,        # Boss 是否已进入第三阶段（换形态）
        "charging": false,      # Boss 是否在蓄力大招（可被打断）
        "charge_t": 0.0,        # 蓄力剩余时间（秒）
        "weak_hits": 0,         # 弱点已被击中次数（Boss 专属）
        "weak_broken": false,   # 弱点是否已击破（Boss 攻击削弱）
        "summoned": 0,          # 已召唤小怪次数（Boss 专属）
        "skip_next": false,     # 被眩晕/魅惑：下一轮回合跳过反击
        "burn": 0,              # 灼烧剩余回合数
        "burn_dmg": 0,          # 灼烧每回合伤害
    }
    var idx := enemies.size()
    e["node"] = _make_enemy_node(e, ed.color, x)
    e["bar"] = _make_enemy_bar(e, idx)
    world.add_child(e.node)
    enemies.append(e)
    return e


func _make_enemy_node(e: Dictionary, color: Color, x: float) -> Node2D:
    var n := Node2D.new()
    n.position = Vector2(x, 368)
    var boss: bool = e.is_boss
    var body_size := Vector2(100, 120) if boss else Vector2(60, 72)
    var body = GlobalState.make_art_node("res://art/enemies/" + e.id + ".png", body_size, color)
    body.name = "Body"
    body.position = Vector2(0, -body_size.y / 2.0)
    n.add_child(body)
    e["body"] = body

    var title := ("Boss·" if boss else "") + str(e.name)
    var name_lbl := GlobalState.make_label(title, 14, Color(1, 0.85, 0.4) if boss else Color(1, 0.7, 0.7))
    name_lbl.position = Vector2(-30, -body_size.y - 24)
    n.add_child(name_lbl)

    var hp_lbl := GlobalState.make_label("", 12, Color(0.9, 1, 0.8))
    hp_lbl.name = "EnemyHp"
    hp_lbl.position = Vector2(-30, -body_size.y - 6)
    n.add_child(hp_lbl)
    return n


func _make_enemy_bar(e: Dictionary, i: int) -> ProgressBar:
    var boss: bool = e.is_boss
    var title := ("Boss·" if boss else "") + str(e.name)
    var name_lbl := GlobalState.make_label(title, 12, Color(1, 0.9, 0.4) if boss else Color(1, 0.8, 0.8))
    name_lbl.position = Vector2(690, 40 + i * 46)
    ui_layer.add_child(name_lbl)
    var bar := ProgressBar.new()
    if boss:
        bar.position = Vector2(690, 62 + i * 46)
        bar.size = Vector2(230, 20)
    else:
        bar.position = Vector2(760, 40 + i * 46)
        bar.size = Vector2(160, 16)
    bar.max_value = e.max_hp
    bar.show_percentage = false
    ui_layer.add_child(bar)
    # 山海经图鉴描述小字
    var story := str(e.get("story", ""))
    if story != "":
        var st := GlobalState.make_label(story, 11, Color(0.7, 0.72, 0.8))
        st.position = Vector2(690, 40 + i * 46 + 18)
        ui_layer.add_child(st)
    return bar


func _spawn_fighters() -> void:
    var keys := ["attack_1", "attack_2", "attack_3", "attack_4"]
    var front_count := 0  # 前排（近战）
    var back_count := 0   # 后排（法师）
    for i in range(4):
        var cd: CharacterData = party_data[i]
        var f := {
            "data": cd,
            "hp": GlobalState.party_hp.get(cd.id, cd.max_hp),
            "key": keys[i],
            "is_mage": cd.is_mage,
            "cooldown": 0.0,      # 收招冷却（秒）
            "node": _make_fighter(cd),
        }
        if cd.is_mage:
            f.node.position = Vector2(150 + back_count * 100, 300)  # 后排靠上
            back_count += 1
        else:
            f.node.position = Vector2(300 + front_count * 100, 368) # 前排靠下、接近敌人
            front_count += 1
        world.add_child(f.node)
        fighters.append(f)
    # 战场地面线
    var floor := _rect(Vector2(960, 8), Color(0.2, 0.22, 0.3))
    floor.position = Vector2(480, 390)
    world.add_child(floor)


func _make_fighter(cd: CharacterData) -> Node2D:
    var n := Node2D.new()
    n.name = cd.display_name
    var body = GlobalState.make_art_node("res://art/heroes/" + cd.id + ".png", Vector2(28, 44), cd.color)
    body.position = Vector2(0, -22)
    n.add_child(body)
    var role := "法师" if cd.is_mage else "近战"
    var name_lbl := GlobalState.make_label(cd.display_name + "·" + role, 13)
    name_lbl.position = Vector2(-32, -58)
    n.add_child(name_lbl)
    var hp_lbl := GlobalState.make_label("", 12, Color(0.8, 1, 0.8))
    hp_lbl.name = "HpLabel"
    hp_lbl.position = Vector2(-32, -42)
    n.add_child(hp_lbl)
    return n


func _process(delta: float) -> void:
    if battle_over:
        return

    # 敌人周期性反击（先蓄力预警，再结算伤害）
    enemy_attack_timer += delta
    if not warned and enemy_attack_timer >= enemy_attack_interval - WARN_TIME:
        warned = true
        _warn_attack()
    if enemy_attack_timer >= enemy_attack_interval:
        enemy_attack_timer = 0.0
        warned = false
        _enemy_attack()

    # Boss 蓄力大招倒计时：时间到就喷毒
    for e in enemies:
        if e.get("charging", false):
            e["charge_t"] -= delta
            if e["charge_t"] <= 0.0:
                e["charging"] = false
                _boss_ult(e)

    # 队友连段冷却递减
    for f in fighters:
        if f.cooldown > 0.0:
            f.cooldown -= delta
            if f.cooldown < 0.0:
                f.cooldown = 0.0

    # 队友攻击（带收招冷却，鼓励按节奏轮换队友）
    for f in fighters:
        if f.hp <= 0:
            continue
        if Input.is_action_just_pressed(f.key):
            if f.cooldown > 0.0:
                msg_label.text = "%s 还在收招，稍等…" % f.data.display_name
            else:
                _fighter_attack(f)

    # 决之技
    if finisher_ready and Input.is_action_just_pressed("finisher"):
        _do_finisher()


func _fighter_attack(f: Dictionary) -> void:
    if battle_over:
        return
    if f.is_mage:
        _mage_attack(f)
    else:
        _melee_attack(f)


# --- 近战：挑最前面的活敌人打（单体） ---
func _melee_attack(f: Dictionary) -> void:
    if battle_over:
        return
    var t: Dictionary = _find_front_enemy()
    if t.is_empty():
        return
    var dmg: int = int(f.data.attack) + int(combo / 10.0)  # 连段越高伤害越高
    var extra := ""
    if f.data.skill_effect == "pierce":
        dmg *= 2                                        # 贯穿：伤害翻倍
        extra = "（贯穿！）"
    elif f.data.skill_effect == "stagger" and randi() % 2 == 0:  # 眩晕：50% 让目标下轮跳过反击
        t.skip_next = true
        extra = "（眩晕！）"
    if warned:                                      # 完美时机：敌人蓄力期间命中
        dmg = int(dmg * 1.5)
        combo += 5
        extra += "（完美时机！）"
    t.hp = maxi(0, t.hp - dmg)
    AudioManager.play("attack")
    # 打断 Boss 蓄力大招（打断后 Boss 下轮硬直）
    if t.get("is_boss", false) and t.get("charging", false):
        t["charging"] = false
        t["skip_next"] = true
        combo += 3
        extra += "（打断蓄力！）"
    extra += _check_weak(t)
    combo += f.data.combo_hits
    hit_gauge = minf(100.0, hit_gauge + 25.0)
    f.cooldown = ATTACK_COOLDOWN
    msg_label.text = "%s 使出「%s」！%s -%d%s（连段 x%d）" % [f.data.display_name, f.data.skill_name, t.name, dmg, extra, combo]
    _show_hit_number(t.node, dmg)
    _lunge_toward(f.node, t.node)
    _float_enemy(t)
    _after_damage()


# --- 法师：范围魔法，打全体活敌人 ---
func _mage_attack(f: Dictionary) -> void:
    if battle_over:
        return
    var total := 0
    var hits := 0
    var extra := ""
    for e in enemies:
        if e.hp > 0:
            var dmg: int = int(f.data.attack) + int(combo / 20.0)
            e.hp = maxi(0, e.hp - dmg)
            total += dmg
            hits += 1
            _show_hit_number(e.node, dmg)
            # 打断 Boss 蓄力大招 + 弱点判定
            if e.get("is_boss", false) and e.get("charging", false):
                e["charging"] = false
                e["skip_next"] = true
                combo += 3
                extra += "（打断蓄力！）"
            extra += _check_weak(e)
            if f.data.skill_effect == "burn":
                e.burn = 2                                   # 灼烧：2 回合
                e.burn_dmg = 6                               # 每回合 6 点
            elif f.data.skill_effect == "charm" and randi() % 2 == 0:  # 魅惑：50% 让目标下轮跳过反击
                e.skip_next = true
    if hits == 0:
        return
    if warned:                                      # 完美时机：范围总伤 x1.5
        total = int(total * 1.5)
        combo += 5
    combo += f.data.combo_hits * hits
    hit_gauge = minf(100.0, hit_gauge + 25.0)
    f.cooldown = ATTACK_COOLDOWN
    if f.data.skill_effect == "burn":
        extra = "（灼烧！）" + extra
    elif f.data.skill_effect == "charm":
        extra = "（魅惑！）" + extra
    if warned:
        extra += "（完美时机！）"
    msg_label.text = "%s 吟唱「%s」！命中 %d 个敌人，共 -%d%s（连段 x%d）" % [f.data.display_name, f.data.skill_name, hits, total, extra, combo]
    _show_aoe()
    AudioManager.play("skill")
    _after_damage()


func _do_finisher() -> void:
    if battle_over:
        return
    finisher_ready = false
    var per_enemy := _total_attack() * 3
    var total := 0
    for e in enemies:
        if e.hp > 0:
            e.hp = maxi(0, e.hp - per_enemy)
            total += per_enemy
            _show_hit_number(e.node, per_enemy)
    hit_gauge = 0.0
    combo = 0
    msg_label.text = "决之技！！造成 %d 点伤害！" % total
    _flash_screen(Color(1, 1, 1, 0.6))
    AudioManager.play("finisher")
    _play_finisher_cutin()
    _after_damage()


# 决之技全屏特写：闪白 + 首个活英灵立绘切入
func _play_finisher_cutin() -> void:
    var hero: Dictionary = {}
    for f in fighters:
        if f.hp > 0:
            hero = f
            break
    if hero.is_empty():
        return
    var layer := CanvasLayer.new()
    layer.layer = 30
    add_child(layer)
    var veil := ColorRect.new()
    veil.color = Color(0, 0, 0, 0.6)
    veil.size = Vector2(960, 540)
    layer.add_child(veil)
    var portrait = GlobalState.make_art_node("res://art/heroes/" + hero.data.id + ".png", Vector2(200, 260), hero.data.color)
    portrait.position = Vector2(480, 260)
    layer.add_child(portrait)
    var lbl := GlobalState.make_label(hero.data.display_name + " 决之技！！", 36, Color(1, 0.85, 0.3))
    lbl.position = Vector2(310, 90)
    layer.add_child(lbl)
    var tween := create_tween()
    tween.tween_interval(1.0)
    tween.tween_property(veil, "modulate:a", 0.0, 0.4)
    tween.parallel().tween_property(portrait, "modulate:a", 0.0, 0.4)
    tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.4)
    tween.tween_callback(layer.queue_free)


func _enemy_attack() -> void:
    _tick_burns()
    if battle_over:
        return

    # 挑一个没被眩晕/魅惑牵制的活敌人来反击
    var candidates := enemies.filter(func(e): return e.hp > 0 and not e.skip_next)
    if candidates.is_empty():
        _clear_skip()
        msg_label.text = "敌人被牵制，来不及反击！"
        _refresh_ui()
        return
    var e: Dictionary = candidates[randi_range(0, candidates.size() - 1)]

    # Boss：第三阶段（≤30% 血）换形态 + 暴露弱点 + 召唤小怪
    if e.is_boss:
        if e.hp <= e.max_hp * 0.3 and not e.get("phased", false):
            e["phased"] = true
            var bb: Node2D = e.body
            bb.modulate = Color(1, 0.35, 0.55)
            msg_label.text = "%s 现出真身，凶威暴涨！" % e.name
            AudioManager.play("boss_roar")
            _expose_core(e)
            _summon_minion(e)
        # 二/三阶段：概率补充召唤小怪（营造 Boss + 群怪的压迫感）
        elif e.summoned < 2 and e.hp < e.max_hp * 0.6 and randi() % 100 < 20:
            _summon_minion(e)
        # 大招：概率进入「蓄力」——被打中会中断，蓄力完成才喷毒（可被打断）
        var ult_rate := 50 if e.hp <= e.max_hp * 0.3 else 30
        if e.hp < e.max_hp * 0.5 and not e.get("charging", false) and randi() % 100 < ult_rate:
            e["charging"] = true
            e["charge_t"] = 1.8
            msg_label.text = "%s 深吸一口气，正在蓄力喷毒！（抓紧打断）" % e.name
            AudioManager.play("warn")
            _clear_skip()
            return

    # 选目标：25% 概率偷袭后排法师，否则优先打前排肉盾
    var alive := fighters.filter(func(f): return f.hp > 0)
    if alive.is_empty():
        _end_battle(false)
        return
    var target: Dictionary
    var back := alive.filter(func(f): return f.is_mage)
    if not back.is_empty() and randi() % 4 == 0:
        target = back[randi_range(0, back.size() - 1)]
    else:
        var front := alive.filter(func(f): return not f.is_mage)
        if not front.is_empty():
            target = front[randi_range(0, front.size() - 1)]
        else:
            target = alive[randi_range(0, alive.size() - 1)]

    # 弱点已破削弱（攻击 -30%）/ 残血狂暴（<30% 血攻击 x1.5）
    var atk := int(e.atk)
    var mods := ""
    if e.get("weak_broken", false):
        atk = int(atk * 0.7)
        mods += "（弱点已破）"
    if e.hp < e.max_hp * 0.3:
        atk = int(e.atk * 1.5)
        mods += "（狂暴！）"
    target.hp -= atk
    AudioManager.play("hit_ally")
    var msg := "%s 使出「%s」！%s 受到 -%d%s" % [e.name, e.action, target.data.display_name, atk, mods]
    _flash_node(target.node, Color(1, 0, 0))

    # 连招：Boss 50% / 普通敌人 25% 概率追加第二击（半伤）
    var double_chance := 50 if e.is_boss else 25
    if randi() % 100 < double_chance:
        var dmg2 := maxi(1, int(atk / 2))
        target.hp -= dmg2
        msg += "（连击！再 -%d）" % dmg2
        _flash_node(target.node, Color(1, 0.3, 0))
    msg_label.text = msg

    _clear_skip()
    _refresh_ui()
    if _all_allies_dead():
        _end_battle(false)


# Boss 蓄力完成的喷毒大招
func _boss_ult(e: Dictionary) -> void:
    if battle_over:
        return
    var mult := 0.8 if e.hp <= e.max_hp * 0.3 else 0.6
    if e.get("weak_broken", false):
        mult *= 0.7   # 弱点已破：大招也削弱
    var poison := int(e.atk * mult)
    for f in fighters:
        if f.hp > 0:
            f.hp -= poison
    msg_label.text = "%s 喷出「%s」！全体受到 %d 点毒伤！" % [e.name, e.action, poison]
    AudioManager.play("boss_roar")
    _flash_screen(Color(0.3, 1, 0.3, 0.25))
    _refresh_ui()
    if _all_allies_dead():
        _end_battle(false)


# Boss 召唤一只小怪（九婴）加入战场
func _summon_minion(e: Dictionary) -> void:
    if int(e.get("summoned", 0)) >= 2:
        return
    var alive := 0
    for x in enemies:
        if x.hp > 0:
            alive += 1
    if alive >= 4:
        return
    e["summoned"] = int(e.get("summoned", 0)) + 1
    msg_label.text = "%s 呼出一只「九婴」！" % e.name
    AudioManager.play("boss_roar")
    _spawn_one_enemy("jiuying", randi_range(640, 900))


# Boss 第三阶段暴露弱点（毒核）
func _expose_core(e: Dictionary) -> void:
    if e.get("weak_broken", false):
        return
    var core := _rect(Vector2(18, 18), Color(0.6, 0.2, 1.0))
    core.name = "Core"
    core.position = Vector2(0, -25)
    e.body.add_child(core)
    e["core"] = core


# 命中 Boss 弱点判定：30% 概率击中弱点，累计 3 次弱点击破、Boss 被削弱
func _check_weak(e: Dictionary) -> String:
    if not e.get("is_boss", false) or not e.get("phased", false) or e.get("weak_broken", false):
        return ""
    if randi() % 100 >= 30:
        return ""
    e["weak_hits"] = int(e.get("weak_hits", 0)) + 1
    _flash_node(e.node, Color(0.6, 0.2, 1.0))
    if int(e.weak_hits) >= 3:
        e["weak_broken"] = true
        if e.has("core"):
            var cn: Node = e.get("core")
            if is_instance_valid(cn):
                cn.queue_free()
        return "（弱点已破！Boss 攻击 -30%）"
    return "（击中弱点 %d/3）" % int(e.weak_hits)


# 反击前的蓄力预警：随机预告一个敌人 + 闪橙红
func _warn_attack() -> void:
    var alive := enemies.filter(func(e): return e.hp > 0)
    if alive.is_empty():
        return
    var e: Dictionary = alive[randi_range(0, alive.size() - 1)]
    msg_label.text = "%s 正在蓄力…" % e.name
    AudioManager.play("warn")
    _flash_node(e.node, Color(1, 0.4, 0.1))


# 灼烧结算：每个带灼烧的敌人每回合掉血
func _tick_burns() -> void:
    var total := 0
    for e in enemies:
        if e.hp > 0 and e.burn > 0:
            var dmg: int = int(e.burn_dmg)
            e.hp = maxi(0, e.hp - dmg)
            total += dmg
            e.burn -= 1
            _show_hit_number(e.node, dmg)
    if total > 0:
        msg_label.text = "灼烧生效！共烧掉 %d 点生命" % total
        _mark_dead_enemies()
        _refresh_ui()
        if _all_enemies_dead():
            _end_battle(true)


# 清除所有敌人的「跳过下轮反击」标记
func _clear_skip() -> void:
    for e in enemies:
        e.skip_next = false


func _after_damage() -> void:
    if hit_gauge >= 100.0:
        finisher_ready = true
    _mark_dead_enemies()
    _refresh_ui()
    if _all_enemies_dead():
        _end_battle(true)


func _mark_dead_enemies() -> void:
    # 敌人血归零后淡出并上飘消失
    for e in enemies:
        if e.hp <= 0 and not e.dead:
            e.dead = true
            AudioManager.play("kill")
            var tween := create_tween()
            tween.tween_property(e.body, "modulate:a", 0.0, 0.25)
            tween.parallel().tween_property(e.body, "position:y", -120.0, 0.25)


func _end_battle(won: bool) -> void:
    if battle_over:
        return
    battle_over = true
    if won:
        # 血量写回：活英灵保留当前血量，倒下的喘口气回到 1
        for f in fighters:
            if f.data.id != "ph":
                GlobalState.party_hp[f.data.id] = maxi(1, f.hp)
        var reward := 30 + randi_range(0, 20)
        if GlobalState.has_trinket("julingyu"):
            reward = int(reward * 1.5)   # 聚灵玉：经验水晶 +50%
        GlobalState.exp_crystals += reward
        AudioManager.play("crystal")
        # 击败终极 Boss：标记 + 封印值大涨
        if enemy_id == "xiangyao":
            GlobalState.boss_defeated = true
            GlobalState.seal_value += 3
            msg_label.text = "击败「相繇」！山海封印松动，英灵归位……"
        else:
            msg_label.text = "胜利！最终连段 x%d，获得 %d 经验水晶" % [combo, reward]
    else:
        # 败北：全队回满（读档式重来，避免卡死）
        for f in fighters:
            if f.data.id != "ph":
                GlobalState.party_hp[f.data.id] = f.data.max_hp
        msg_label.text = "败北……回到探索。"
    # 时间消耗：每场战斗 -1 回合
    GlobalState.periods = maxi(0, GlobalState.periods - 1)
    await get_tree().create_timer(1.6).timeout
    EventBus.battle_finished.emit(won)
    # 结局判定
    var kind := GlobalState.check_ending()
    if kind != "":
        EventBus.ending_requested.emit(kind)


# --- 数据/刷新辅助 ---

func _find_front_enemy() -> Dictionary:
    for e in enemies:
        if e.hp > 0:
            return e
    return {}


func _total_attack() -> int:
    var s := 0
    for f in fighters:
        if f.hp > 0:
            s += f.data.attack
    return s


func _all_enemies_dead() -> bool:
    return enemies.all(func(e): return e.hp <= 0)


func _all_allies_dead() -> bool:
    return fighters.all(func(f): return f.hp <= 0)


func _enemies_summary() -> String:
    var names: Array = []
    for e in enemies:
        names.append(e.name)
    return "、".join(names)


func _refresh_ui() -> void:
    gauge_bar.value = hit_gauge
    combo_label.text = "连段 x%d" % combo
    for e in enemies:
        e.bar.max_value = e.max_hp
        e.bar.value = e.hp
        var hp_lbl: Label = e.node.get_node("EnemyHp")
        hp_lbl.text = "%d/%d" % [e.hp, e.max_hp]
    for f in fighters:
        var hp_lbl := f.node.get_node("HpLabel") as Label
        hp_lbl.text = "%d/%d" % [f.hp, f.data.max_hp]


# --- 纯表现效果 ---

func _lunge_toward(node: Node2D, target: Node2D) -> void:
    var start := node.position
    var toward: Vector2 = (target.position - node.position).normalized() * 46.0
    var tween := create_tween()
    tween.tween_property(node, "position", start + toward, 0.08)
    tween.tween_property(node, "position", start, 0.14)


func _float_enemy(e: Dictionary) -> void:
    # 敌人被击打浮空再落下
    var body: Node2D = e.body
    var tween := create_tween()
    tween.tween_property(body, "position:y", -74.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(body, "position:y", -36.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _show_hit_number(node: Node2D, dmg: int) -> void:
    var lbl := GlobalState.make_label(str(dmg), 20, Color(1, 1, 0.3))
    lbl.position = node.position + Vector2(20, -80)
    world.add_child(lbl)
    var tween := create_tween()
    tween.tween_property(lbl, "position", lbl.position + Vector2(0, -40), 0.6)
    tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6)
    tween.tween_callback(lbl.queue_free)


func _show_aoe() -> void:
    # 范围魔法：每个活敌身上扩散一个光圈
    for e in enemies:
        if e.hp <= 0:
            continue
        var ring := _rect(Vector2(90, 90), Color(0.5, 0.8, 1.0, 0.45))
        ring.position = e.node.position + Vector2(0, -36)
        world.add_child(ring)
        var tween := create_tween()
        tween.tween_property(ring, "scale", Vector2(1.7, 1.7), 0.3)
        tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
        tween.tween_callback(ring.queue_free)


func _flash_screen(color: Color = Color(1, 1, 1, 0.6)) -> void:
    var f := ColorRect.new()
    f.color = color
    f.size = Vector2(960, 540)
    ui_layer.add_child(f)
    var tween := create_tween()
    tween.tween_property(f, "modulate:a", 0.0, 0.35)
    tween.tween_callback(f.queue_free)


func _flash_node(node: Node2D, color: Color) -> void:
    var overlay := _rect(Vector2(28, 44), color)
    overlay.position = node.position + Vector2(0, -22)
    world.add_child(overlay)
    var tween := create_tween()
    tween.tween_property(overlay, "modulate:a", 0.0, 0.4)
    tween.tween_callback(overlay.queue_free)


# 小工具：生成居中实心矩形
func _rect(size: Vector2, color: Color) -> Polygon2D:
    var p := Polygon2D.new()
    var h := size * 0.5
    p.polygon = PackedVector2Array([
        Vector2(-h.x, -h.y), Vector2(h.x, -h.y),
        Vector2(h.x, h.y), Vector2(-h.x, h.y)
    ])
    p.color = color
    return p