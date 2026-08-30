extends Node
# ============================================================
# EventBus —— 事件总线（Autoload 单例）
# 作用：场景之间用「信号」互相通知，而不是直接互相引用。
# 好处：探索场景不需要知道战斗场景存不存在，发个信号就行，
#       主控 (main.gd) 负责监听信号并切换场景。解耦后更好扩展。
# ============================================================

# 请求进入战斗（参数 enemy_id：敌人 id，如 "taowu"）
signal battle_requested(enemy_id: String)

# 战斗结束（参数 won：是否胜利）
signal battle_finished(won: bool)

# 英灵被招募（参数 npc_id）
signal npc_recruited(npc_id: String)

# 灵石被发射（预留，可用于音效、特效）
signal crystal_fired

# 主菜单请求开始游戏（new_game：true=新游戏，false=读档继续）
signal game_start_requested(new_game: bool)

# 房间出口门请求切换（to_room：目标房间 id）
signal room_exit_requested(to_room: String)

# 触发结局（kind：true=真结局 / normal=普通结局 / bad=时间耗尽）
signal ending_requested(kind: String)

# 请求回到主菜单（结局界面回车后）
signal menu_requested