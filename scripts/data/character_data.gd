extends Resource
class_name CharacterData
# ============================================================
# CharacterData —— 角色数据（Resource 资源）
# 作用：把角色的数值、颜色、身世故事做成一个「数据文件」(.tres)，
#       改数值不用改代码。这是 Godot 里很常用的「数据驱动」思路。
#
# 怎么用：
#   1. 在编辑器里右键 res://scripts/data/characters/ 新建 Resource，
#      选择 CharacterData，填好字段保存即可；
#   2. 或者直接复制 houyi.tres 改个名字。
# ============================================================

@export var id: String = ""                 # 唯一 id，例如 "houyi"
@export var display_name: String = ""       # 显示名，例如 "后羿"
@export var max_hp: int = 100               # 最大生命
@export var attack: int = 10                # 攻击力
@export var combo_hits: int = 4             # 一套连击的段数
@export var is_mage: bool = false           # 是否是法师（true=后排施放范围魔法；false=前排近战）
@export var skill_name: String = "连击"      # 战斗技能名（释放攻击时在文案里展示）
# 技能效果（空 = 普通技能）：
#   "pierce"  贯穿：单体伤害翻倍
#   "stagger" 眩晕：概率让目标下一轮回合跳过反击
#   "burn"    灼烧：命中后每回合额外掉血（持续 2 回合）
#   "charm"   魅惑：概率让被命中敌人下一轮回合跳过反击
@export var skill_effect: String = ""
@export var color: Color = Color.WHITE      # 占位美术用的颜色（正式美术替换后就不需要了）
@export var story: String = ""              # 身世故事（招募剧情用）
