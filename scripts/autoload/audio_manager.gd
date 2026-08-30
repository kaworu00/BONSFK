extends Node
# ============================================================
# AudioManager —— 程序化音效管理器（Autoload 单例）
# 作用：不依赖任何外部素材，用数学波形实时合成 8-bit 风格音效。
# 用法：在任意脚本里调用 AudioManager.play("音效名")。
# 原理：把一段 PCM 采样写进 AudioStreamWAV，交给播放器池播放。
# ============================================================

const SAMPLE_RATE := 22050  # 采样率（够用且省内存）

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}


func _ready() -> void:
    # 预建播放器池：同帧多个音效互不打断
    for i in range(8):
        var p := AudioStreamPlayer.new()
        add_child(p)
        _players.append(p)

    # 预合成全部音效（只算一次，之后播放零开销）
    _cache["attack"] = _attack()                        # 近战命中：短促「嚓」
    _cache["skill"] = _gen(0.25, 400.0, 1200.0, 0.5, "sine")    # 范围魔法：上扬闪光
    _cache["shoot"] = _gen(0.12, 900.0, 300.0, 0.45, "sine")    # 灵石发射：嗖
    _cache["hit_ally"] = _gen(0.14, 110.0, 45.0, 0.6, "square") # 我方受击：低沉
    _cache["warn"] = _gen(0.15, 1400.0, 1400.0, 0.35, "square") # 敌人蓄力：哔
    _cache["boss_roar"] = _gen(0.6, 60.0, 40.0, 0.7, "saw")     # Boss 怒吼/毒：轰鸣
    _cache["kill"] = _gen(0.18, 300.0, 40.0, 0.55, "square")    # 敌人倒下：下坠
    _cache["finisher"] = _gen(0.5, 200.0, 800.0, 0.6, "saw")    # 决之技：大招上扬
    _cache["crystal"] = _gen(0.22, 1200.0, 1800.0, 0.5, "sine") # 胜利水晶：清脆
    _cache["recruit"] = _gen(0.4, 500.0, 900.0, 0.5, "sine")    # 招募英灵：上升琶音
    _cache["heal"] = _gen(0.5, 350.0, 520.0, 0.45, "tri")       # 治疗：柔和
    _cache["buy"] = _gen(0.15, 1500.0, 1500.0, 0.5, "sine")     # 购买：金币叮


# 主入口：AudioManager.play("attack")
func play(id: String, vol_db: float = 0.0) -> void:
    if not _cache.has(id):
        return
    for p in _players:
        if not p.playing:
            p.stream = _cache[id]
            p.volume_db = vol_db
            p.play()
            return
    # 播放器全被占用：抢占最早那个（音效很短，几乎不会发生）
    var p0 := _players[0]
    p0.stream = _cache[id]
    p0.volume_db = vol_db
    p0.play()


# 近战命中专用：锯齿下潜 + 白噪声混杂，听感像「嚓」一下
func _attack() -> AudioStreamWAV:
    var n := int(SAMPLE_RATE * 0.09)
    var samples := PackedFloat32Array()
    samples.resize(n)
    var phase := 0.0
    for i in range(n):
        var k := float(i) / maxi(1, n - 1)
        var f := lerpf(260.0, 90.0, k)
        phase += f / SAMPLE_RATE
        var saw := fmod(phase, 1.0) * 2.0 - 1.0
        var noise := randf() * 2.0 - 1.0
        var env := pow(1.0 - k, 2.0)
        samples[i] = (saw * 0.55 + noise * 0.45) * 0.7 * env
    return _wav(samples)


# 通用合成器：一段从 f1 滑到 f2 的波，指数衰减包络
func _gen(dur: float, f1: float, f2: float, vol: float, shape: String) -> AudioStreamWAV:
    var n := int(SAMPLE_RATE * dur)
    var samples := PackedFloat32Array()
    samples.resize(n)
    var phase := 0.0
    for i in range(n):
        var k := float(i) / maxi(1, n - 1)
        var f := lerpf(f1, f2, k)
        phase += f / SAMPLE_RATE
        var ph := fmod(phase, 1.0)
        var s := 0.0
        match shape:
            "square":
                s = 1.0 if ph < 0.5 else -1.0
            "saw":
                s = ph * 2.0 - 1.0
            "tri":
                s = absf(ph * 2.0 - 1.0) * 2.0 - 1.0
            _:            # 默认正弦
                s = sin(phase * TAU)
        var env := pow(1.0 - k, 2.0)
        samples[i] = s * vol * env
    return _wav(samples)


# 浮点采样 → 16-bit 单声道 WAV
func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
    var w := AudioStreamWAV.new()
    w.format = AudioStreamWAV.FORMAT_16_BITS
    w.mix_rate = SAMPLE_RATE
    w.stereo = false
    var bytes := PackedByteArray()
    bytes.resize(samples.size() * 2)
    for i in range(samples.size()):
        var s := clampf(samples[i], -1.0, 1.0)
        var v := int(s * 32767.0)
        bytes[i * 2] = v & 0xFF
        bytes[i * 2 + 1] = (v >> 8) & 0xFF
    w.data = bytes
    return w