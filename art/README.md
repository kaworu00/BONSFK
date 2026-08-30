# 美术替换指南（丢图即生效）

现在游戏里所有角色/敌人都还是「占位色块」。你只要把 PNG 图片按下面的**路径**放进本目录（`res://art/`），回到 Godot 重新运行，游戏就会自动用你的图替换色块——**完全不用改代码**。

## 路径约定

| 放进这里 | 会替换谁 |
|---|---|
| `art/player.png` | 主角（探索时的你） |
| `art/heroes/<英灵id>.png` | 英灵：探索里的发光 NPC + 战斗里的队友 |
| `art/enemies/<敌人id>.png` | 魔物：探索里的巡逻怪 + 战斗里的敌人 |

**英灵 id**（12 位）：
`houyi jingwei kuafu xingtian yinglong jiuweihu zhulong baize chiyou dayu zhurong gonggong`

**敌人 id**（7 种）：
`taowu qiongqi hundun jiuying xiangliu taotie zaochi`

## 图片规格

- 格式：**PNG，透明背景**（没透明底会显示成大方块）。
- 建议**竖长**比例（宽:高 ≈ 2:3 或 1:2），程序会自动缩放到游戏需要的尺寸。
- 尺寸：先用 **64×96** 左右试；嫌模糊再放大到 128×192（2 倍）也行。
- **面向右画**（角色默认朝右，朝左时程序会自动水平翻转）。

## 例子

- 画好主角 → 存成 `art/player.png` → 重跑即生效。
- 画好后羿 → 存成 `art/heroes/houyi.png` → 探索里遇到后羿、战斗里用后羿都显示这张图。

## 提示

还没画完的图**可以先不放进目录**，对应角色会继续用原来的色块，互相不影响。所以你可以一个角色一个角色地慢慢替换。
