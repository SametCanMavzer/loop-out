class_name RopeBehavior extends Resource
## İp davranışı (TDD §4.2). Veri odaklı — .tres olarak data/behaviors/ altında.
## 7 davranış bu şablonun parametre setleridir; yalnız DoubleSweep/FakeSlow özel mantık ister.
## Telegraf: davranış etkiye girmeden telegraph_ms önce oyuncu uyarılır (behavior_telegraphed).

@export var id: StringName = &"normal"
@export var min_round: int = 1          # bu turdan önce seçilemez
@export var weight: float = 1.0         # ağırlıklı rastgele seçim (Rng.behavior)
@export var telegraph_ms: float = 400.0 # etkiden önce uyarı süresi
@export var telegraph_anim: StringName = &""  # görsel (F7 render); mantığı etkilemez

## Davranışa özel parametreler (rope bunları uygular):
##   speed_mult: float  → angular_vel çarpanı (base'e göre)
##   height: int        → 0=LOW, 1=HIGH
##   special: StringName → &"double_sweep" / &"fake_slow" (özel alt mantık)
@export var params: Dictionary = {}
