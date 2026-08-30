extends Node
# ============================================================
# GlobalState —— 全局状态（Autoload 单例）
# 作用：跨场景共享的游戏数据，例如队伍、经验水晶、封印值等。
# 在任意脚本里直接写 `GlobalState.party` 就能访问，不需要引用路径。
# ============================================================

var party: Array = []          # 当前参战角色 id 列表（例如 ["houyi", "jingwei"]）
var recruited: Dictionary = {} # 已招募英灵 id -> 显示名（例如 {"houyi": "后羿"}）
var exp_crystals: int = 0      # 经验水晶（战斗胜利获得，升级用）
var seal_value: int = 0        # 封印值（影响结局，这里先占位）
var boosts: Dictionary = {}    # 英灵升格加点：{id: {"hp": 点数, "atk": 点数}}
var current_room: String = "cave_01"  # 当前所在房间 id（存档用）
var party_hp: Dictionary = {}  # 出战英灵当前血量 {id: hp}（战斗损耗保留，休息点回满）
var trinkets: Array = []       # 已购饰品 id 列表（全局被动）
var chapter: int = 1           # 当前章节（时间章节）
var periods: int = 12          # 当前章节剩余回合数（时间配额）
var boss_defeated: bool = false  # 是否已击败 Boss「相繇」（影响结局）

# 全局 UI 字体：Godot 自带字体不含中文，这里用系统字体显示中文。
var ui_font: SystemFont


func _ready() -> void:
    _setup_input()
    _apply_default_font()


# 运行时注册输入动作。为什么不写进 project.godot 的 [input] 段？
# 因为那段是 Godot 私有序列化格式，手写极易出错；用 InputMap 更直观、更好改。
func _setup_input() -> void:
    _add_action("move_left", [KEY_A, KEY_LEFT])
    _add_action("move_right", [KEY_D, KEY_RIGHT])
    _add_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
    _add_action("crouch", [KEY_S, KEY_DOWN])
    _add_action("crystal", [KEY_J])
    _add_action("interact", [KEY_E])
    _add_action("attack_1", [KEY_U])
    _add_action("attack_2", [KEY_I])
    _add_action("attack_3", [KEY_O])
    _add_action("attack_4", [KEY_P])
    _add_action("finisher", [KEY_K])
    _add_action("save", [KEY_F5])
    _add_action("load", [KEY_F9])
    _add_action("menu_up", [KEY_W, KEY_UP])
    _add_action("menu_down", [KEY_S, KEY_DOWN])
    _add_action("menu_confirm", [KEY_ENTER, KEY_SPACE])
    _add_action("menu_cancel", [KEY_ESCAPE])
    _add_action("upgrade", [KEY_T])
    _add_action("party", [KEY_N])
    _add_action("page_prev", [KEY_Q])
    _add_action("page_next", [KEY_E])


func _add_action(action: String, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for key in keys:
        var ev := InputEventKey.new()
        # 用 physical_keycode（物理键位），这样不管用户键盘是什么布局都能稳定触发。
        ev.physical_keycode = key
        InputMap.action_add_event(action, ev)


func get_ui_font() -> SystemFont:
    if ui_font == null:
        ui_font = SystemFont.new()
        # 依次尝试这些中文字体，找到第一个系统里存在的就用它。
        ui_font.font_names = PackedStringArray([
            "Microsoft YaHei", "SimHei", "SimSun", "Noto Sans CJK SC"
        ])
    return ui_font


# 把默认字体设成上面这个支持中文的字体，让所有 Label 默认就能显示中文。
func _apply_default_font() -> void:
    var theme := Theme.new()
    theme.default_font = get_ui_font()
    theme.default_font_size = 14
    get_tree().root.theme = theme


# 给所有用到的地方一个「生成带中文默认字体的 Label」的快捷方式。
func make_label(text: String, size: int = 14, color: Color = Color.WHITE) -> Label:
    var lbl := Label.new()
    lbl.text = text
    lbl.add_theme_font_override("font", get_ui_font())
    lbl.add_theme_font_size_override("font_size", size)
    lbl.add_theme_color_override("font_color", color)
    return lbl


# 美术接入助手：优先加载贴图（Sprite2D），图片不存在就回落成占位色块。
# 用法：把 PNG 按约定路径放进 res://art/（见 art/README.md），不用改任何代码。
# tex_path 例："res://art/player.png"
func make_art_node(tex_path: String, size: Vector2, color: Color) -> Node2D:
    if ResourceLoader.exists(tex_path):
        var tex := load(tex_path) as Texture2D
        if tex != null:
            var s := Sprite2D.new()
            s.texture = tex
            s.centered = true
            if tex.get_width() > 0 and tex.get_height() > 0:
                # 按目标尺寸等比缩放（竖长贴图会自动适配）
                s.scale = Vector2(size.x / tex.get_width(), size.y / tex.get_height())
            return s
    return _make_block(size, color)


func _make_block(size: Vector2, color: Color) -> Polygon2D:
    var p := Polygon2D.new()
    var h := size * 0.5
    p.polygon = PackedVector2Array([
        Vector2(-h.x, -h.y), Vector2(h.x, -h.y),
        Vector2(h.x, h.y), Vector2(-h.x, h.y)
    ])
    p.color = color
    return p


# 饰品（全局被动，战斗里自动生效）
const TRINKETS := {
    "julingyu": {"name": "聚灵玉", "cost": 30, "desc": "战斗胜利经验水晶 +50%"},
    "xuanwulin": {"name": "玄武鳞", "cost": 40, "desc": "全体英灵生命上限 +15"},
    "chiyanfu": {"name": "赤炎符", "cost": 50, "desc": "全体英灵攻击 +2"},
}


func has_trinket(id: String) -> bool:
    return trinkets.has(id)


# 结局判定：满足条件就返回结局种类（"" = 还没到结局）
func check_ending() -> String:
    if boss_defeated:
        return "true" if seal_value >= 8 else "normal"
    if periods <= 0:
        return "bad"
    return ""


# 重置进度（新游戏用）
func reset_progress() -> void:
    party = []
    recruited = {}
    exp_crystals = 0
    seal_value = 0
    boosts = {}
    current_room = "cave_01"
    party_hp = {}
    trinkets = []
    chapter = 1
    periods = 12
    boss_defeated = false