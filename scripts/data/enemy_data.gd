extends Resource
class_name EnemyData
# ============================================================
# EnemyData —— 敌人数据（Resource 资源）
# 作用：和 CharacterData 一样，把敌人的数值、颜色、山海经图鉴描述
#       做成 .tres 数据文件，实现「数据驱动」。
# 怎么用：复制 scripts/data/enemies/ 里的任一 .tres 改个名字即可。
# ============================================================

@export var id: String = ""                 # 唯一 id，例如 "taowu"
@export var display_name: String = ""       # 显示名，例如 "梼杌"
@export var max_hp: int = 100               # 最大生命
@export var attack: int = 10                # 攻击力
@export var color: Color = Color.WHITE      # 占位美术颜色
@export var action_name: String = "扑击"     # 反击动作名（战斗文案展示）
@export var is_boss: bool = false           # 是否 Boss（触发分阶段血条 + 专属大招）
@export var story: String = ""              # 山海经图鉴描述（战斗时展示）