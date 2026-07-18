---
name: godot-gdscript
description: Godot 4.4 + GDScript 2.x ile kod yazarken, .tscn/.tres dosyası oluştururken, headless test/sim koşarken veya web export ayarı yaparken kullan. Godot'a özgü tuzakları ve bu projenin sözleşmelerini içerir.
---

# Godot 4.4 / GDScript — Proje Sözleşmeleri

## GDScript 2.x zorunlulukları
- `@export var speed: float = 1.0` · `@onready var rope := $Rope` · `signal jumper_eliminated(id: int, cause: int)`
- Her script typed: parametre ve dönüş tipleri yazılır. `class_name PascalCase`.
- `await get_tree().create_timer(...)` gameplay mantığında YASAK (determinizm) — tick sayaçları kullan.
  Yalnız kozmetik akışlarda (UI tween, konfeti) serbest.
- Enum'lar: `enum CrossResult { PERFECT, GRAZE, MISS }` — magic number yok.

## .tscn / .tres yazımı
- .tscn metin formatı: `[gd_scene format=3]` başlığı, node'lar `[node name="X" type="Y" parent="."]`.
- Sahnede yalnız statik iskelet; 16 jumper, UI ekran durumları, partiküller koddan instantiate edilir.
- .tres Resource: `[gd_resource type="Resource" script_class="RopeBehavior" format=3]` + script yolu.
- UID uyarısı: Godot editor .tscn'leri açınca uid ekler/değiştirir — bu diff normaldir, çakışmada
  editörün yazdığını koru.

## Bu projenin mimari sözleşmeleri (özet — detay docs/tdd.md)
- İletişim: "call down, signal up". Global sinyaller yalnız EventBus'ta.
- Zaman: `_physics_process` 60Hz tick. ms→tick: `int(ms * 0.06)`. `_process` yalnız render interpolasyonu.
- RNG: `Rng.behavior / Rng.bots / Rng.cosmetic` — gameplay'de başka RNG kaynağı yok.
- Config erişimi: `Config.timing.perfect_ms` gibi tipli getter'lar; JSON anahtarına string ile
  dağınık erişim yok.

## Headless komutlar
- GUT testleri: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- Balans sim: `godot --headless -s res://tests/sim/run_sim.gd` → `sim_results.csv`
- Editor import'u gerektiren asset eklendiyse önce: `godot --headless --import` (tek sefer).

## Web export tuzakları
- Preset: threads OFF, extensions OFF, VRAM compression for mobile ON.
- `JavaScriptBridge` yalnız web feature tag'inde çağrılır: `if OS.has_feature("web"):`
- `user://` web'de IndexedDB'dir — senkron dosya G/Ç güvenli ama origin'e bağlı, test ederken
  localhost ile itch origin'i farklı kayıt tutar.
