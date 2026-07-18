extends Node
## Global sinyal sözlüğü (TDD §3.2). Sadece sinyal tanımı — mantık YOK.
## İletişim kuralı: "call down, signal up".

signal round_started(round_no: int, seed: int)
signal rope_crossed(jumper_id: int, result: int, delta_ms: float) # result: PERFECT/GRAZE/MISS
signal jumper_stumbled(jumper_id: int)
signal jumper_pardoned(jumper_id: int)
signal jumper_eliminated(jumper_id: int, cause: int)
signal ring_shrunk(alive_count: int)
signal behavior_telegraphed(behavior_id: StringName)
signal behavior_started(behavior_id: StringName)
signal round_ended(placement: int, coins: int)
signal player_eliminated(alive_count: int) # izleme modu kararını tetikler
