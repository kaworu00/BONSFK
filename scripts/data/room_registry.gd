class_name RoomRegistry
# ============================================================
# RoomRegistry —— 关卡房间数据表
# 作用：把所有房间的布局集中写在「数据」里，每个房间描述：
#   宽度、出生点、可击碎墙、敌人、英灵、出口门。
# 加新房间 = 往 ROOMS 里加一段字典，生成逻辑（room.gd）不用改。
# 字段说明：
#   name      房间显示名（HUD 会显示）
#   width     房间像素宽度（决定地面/左右墙/相机移动范围）
#   bg        背景色
#   spawn     玩家出生点
#   breakable 可击碎墙 [{x, blocks}]：blocks 是竖直格数（灵石击碎）
#   enemies   巡逻敌人 [{id, x, min, max}]：碰到进战斗
#   npcs      可招募英灵 [{id, x}]
#   exits     出口门 [{to, x}]：走进去切换到对应房间
# ============================================================

const ROOMS := {
    "cave_01": {
        "name": "幽径入口",
        "width": 1920,
        "bg": Color(0.09, 0.11, 0.18),
        "spawn": Vector2(200, 360),
        "breakable": [{"x": 1100.0, "blocks": 3}],
        "enemies": [
            {"id": "taowu", "x": 850.0, "min": 700.0, "max": 1000.0},
            {"id": "hundun", "x": 1300.0, "min": 1250.0, "max": 1420.0},
        ],
        "npcs": [
            {"id": "houyi", "x": 430.0},
            {"id": "kuafu", "x": 610.0},
            {"id": "jingwei", "x": 1180.0},
            {"id": "xingtian", "x": 1450.0},
        ],
        "exits": [{"to": "cave_02", "x": 1860.0}],
    },
    "cave_02": {
        "name": "青丘之径",
        "width": 1920,
        "bg": Color(0.1, 0.09, 0.16),
        "spawn": Vector2(120, 360),
        "enemies": [
            {"id": "qiongqi", "x": 950.0, "min": 800.0, "max": 1000.0},
            {"id": "jiuying", "x": 1550.0, "min": 1450.0, "max": 1680.0},
        ],
        "npcs": [
            {"id": "yinglong", "x": 500.0},
            {"id": "jiuweihu", "x": 750.0},
            {"id": "zhulong", "x": 1100.0},
            {"id": "baize", "x": 1320.0},
        ],
        "exits": [
            {"to": "cave_01", "x": 60.0},
            {"to": "cave_03", "x": 1860.0},
        ],
    },
    "cave_03": {
        "name": "逐鹿遗迹",
        "width": 1920,
        "bg": Color(0.12, 0.08, 0.1),
        "spawn": Vector2(120, 360),
        "enemies": [
            {"id": "xiangliu", "x": 900.0, "min": 750.0, "max": 1050.0},
        ],
        "npcs": [
            {"id": "chiyou", "x": 1300.0},
            {"id": "dayu", "x": 1550.0},
        ],
        "exits": [
            {"to": "cave_02", "x": 60.0},
            {"to": "kunlun", "x": 1860.0},
        ],
    },
    "kunlun": {
        "name": "昆仑之墟",
        "width": 1920,
        "bg": Color(0.14, 0.1, 0.16),
        "spawn": Vector2(120, 360),
        "enemies": [
            {"id": "taotie", "x": 800.0, "min": 650.0, "max": 950.0},
            {"id": "zaochi", "x": 1500.0, "min": 1420.0, "max": 1620.0},
        ],
        "npcs": [
            {"id": "zhurong", "x": 550.0},
            {"id": "gonggong", "x": 770.0},
            {"id": "_healer", "x": 1150.0},
            {"id": "_merchant", "x": 1400.0},
        ],
        "exits": [
            {"to": "cave_03", "x": 60.0},
            {"to": "guixu", "x": 1860.0},
        ],
    },
    "guixu": {
        "name": "归墟",
        "width": 1920,
        "bg": Color(0.07, 0.09, 0.13),
        "spawn": Vector2(120, 360),
        "enemies": [
            {"id": "xiangyao", "x": 1000.0, "min": 900.0, "max": 1100.0},
        ],
        "npcs": [],
        "exits": [{"to": "kunlun", "x": 60.0}],
    },
}