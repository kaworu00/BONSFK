extends Node
# ============================================================
# SaveManager —— 存档（Autoload 单例）
# 作用：把进度保存成 JSON 文件，读档时恢复。
# 文件位置：user://save.json（user:// 是 Godot 给每个游戏分配的
# 用户数据目录，通常是 %APPDATA%\Godot\app_userdata\项目名\）
# ============================================================

const SAVE_PATH := "user://save.json"


func save_game() -> void:
    var data := {
        "recruited": GlobalState.recruited,
        "party": GlobalState.party,
        "exp_crystals": GlobalState.exp_crystals,
        "seal_value": GlobalState.seal_value,
        "boosts": GlobalState.boosts,
        "current_room": GlobalState.current_room,
        "party_hp": GlobalState.party_hp,
        "trinkets": GlobalState.trinkets,
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_warning("存档失败：无法打开文件 " + SAVE_PATH)
        return
    file.store_string(JSON.stringify(data, "\t"))
    file.close()


func load_game() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return false
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if parsed is Dictionary:
        GlobalState.recruited = parsed.get("recruited", {})
        GlobalState.party = parsed.get("party", [])
        GlobalState.exp_crystals = int(parsed.get("exp_crystals", 0))
        GlobalState.seal_value = int(parsed.get("seal_value", 0))
        var b = parsed.get("boosts", {})
        if b is Dictionary:
            GlobalState.boosts = b
        GlobalState.current_room = str(parsed.get("current_room", "cave_01"))
        var php = parsed.get("party_hp", {})
        if php is Dictionary:
            GlobalState.party_hp = php
        var tr = parsed.get("trinkets", [])
        if tr is Array:
            GlobalState.trinkets = tr
        return true
    return false