class_name BotArchetype extends Resource
## Bot arketipi (TDD §4.6). Veri odaklı — .tres olarak data/archetypes/ altında.
## Karar: bot ipin geçişinden `reaction_mean_ms` kadar önce/sonra, σ(round) sapmayla zıplar.
## σ tur ile büyür (zorluk eğrisi / doğal eleme). exit_range: Acemi'nin gidiş turları (σ şişer).

@export var id: StringName = &""
@export var reaction_mean_ms: float = -210.0   # geçişe göre ort. offset (negatif = önce zıpla)
@export var reaction_std_base_ms: float = 60.0  # temel σ
@export var std_round_slope: float = 3.0        # σ'nın tur başına artışı (zorluk eğrisi)

# F7'de kullanılacak (şimdilik taşınır)
@export var telegraph_fail_prob: float = 0.0
@export_enum("NONE", "SHOWOFF", "COPYCAT") var quirk: int = 0

# Acemi gidiş penceresi (§4.6): bu tur aralığında σ yapay şişirilir (gidiş garanti, script'li ölüm yok)
@export var exit_from: int = 0
@export var exit_to: int = 0
@export var exit_sigma_mult: float = 1.0
