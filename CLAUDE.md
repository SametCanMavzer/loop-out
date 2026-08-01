# İP ATLA — Proje Kuralları

Godot 4.4 + GDScript, 2.5D arena eleme oyunu. Web-first (itch/Poki/CrazyGames), sonra Android.
Tek geliştirici: Samet. Sen bu projenin teknik lideri ve geliştiricisisin — kodu SEN yazarsın.

## Kaynak belgeler (gerektiğinde oku, her oturumda okuma)
- `docs/gdd.md` — oyun tasarımı (ne yapılacak)
- `docs/tdd.md` — teknik tasarım (nasıl yapılacak). **Bölüm §18 = geliştirme sırası.**
- `STATE.md` — canlı yol haritası + ilerleme. **Her oturuma buradan başla.**

## KESİNLEŞMİŞ KARARLAR (yeniden tartışma, alternatif sunma)
1. Motor: Godot 4.4, GDScript. Renderer: **Compatibility**. Web export: **threads OFF**.
2. Simülasyon: 60Hz sabit tick (`_physics_process`), tüm süreler config'te ms → tick'e çevrilir.
3. Determinizm: `Rng` autoload, 3 stream (behavior/bots/cosmetic). Gameplay kodunda YASAK:
   global `randf()`, `Time.*` ile mantık, `_process`'te durum değişimi, Dictionary sırasına güvenmek.
4. Fizik motoru yok — crossing matematiği açısal karşılaştırma (TDD §4.3). Ragdoll = tek gövde impuls.
5. İnsan/bot/ghost aynı `InputSource` arayüzünden geçer (TDD §3.4).
6. Tek sahne mimarisi: `main.tscn` hiç değişmez, restart = state reset (TDD §7.1).
7. Tüm balans değerleri SADECE `config/balance.json`'da. Koda sabit gömme.
8. Klasör yapısı: TDD §2. Autoload'lar: EventBus, Config, SaveGame, Audio, Analytics, Ads, Rng — 8.'si yasak.
9. Gölge haritası yok (blob quad), post-process yok, tek directional ışık.
10. Kapsam: TDD §17'deki "yapılmayacaklar" listesi kesindir. Yeni özellik önerisi → varsayılan cevap V2.

## Çalışma disiplini
- **Tek görev ilkesi:** STATE.md'den sıradaki işi al, ≤1-2 saatlik parçaya böl, bitir, sonrakine geç.
  Aynı anda birden fazla sistem kurma.
- Her görev sonunda: (a) varsa testleri koş, (b) STATE.md'yi güncelle, (c) commit at.
- Commit önekleri: `feat:` `fix:` `balance:` `asset:` `chore:` `test:` — kısa, İngilizce.
- Samet bir fikir önerdiğinde TDD/kapsam ile çelişiyorsa **doğrudan söyle**, gerekçele, alternatif ver.
  Onaylamak için onaylama.

## Godot gerçekleri (kritik)
- Oyunu ÇALIŞTIRAMAZSIN ve GÖREMEZSİN. Görsel/his gerektiren her doğrulamayı görevin sonunda
  `[EDİTÖR KONTROLÜ]: <ne yapılacak, ne görülmeli>` bloğuyla Samet'e devret. Onayı gelmeden
  o görevi STATE.md'de tamamlandı işaretleme.
- Mantık testleri için çalıştırabildiğin tek şey: `godot --headless` (test koşucusu + sim sahneleri).
  **Test komutu:** `godot --headless scenes/dev/run_tests.tscn` (tüm birim testleri tek süreçte, ~2 sn)
  Tek test: `godot --headless scenes/dev/run_tests.tscn -- test_rope`
  Tam paket (birim + balans/denetim/replay simülasyonları, ~17 sn): `powershell -File tests\run_all.ps1`
  Test sözleşmesi: her test `extends RefCounted` + `func run(tree: SceneTree) -> int` (hata sayısı döndürür).
  GUT kullanılmıyor — aynı hızı bağımsız koşucu sağlıyor, ek bağımlılık yok (karar: F11).
- `.tscn` dosyalarını metin olarak yazabilirsin ama MİNİMAL tut: sahnede yalnız iskelet node'lar,
  dinamik her şey (16 jumper dizilimi, UI durumları) koddan kurulur. `.godot/` klasörüne asla dokunma.
- GDScript 2.x sözdizimi: `@export`, `@onready`, typed signals, `class_name`. Godot 3 sözdizimi yazma.

## Token disiplini
- Görev şablonu, günlük rapor, yüzde tablosu üretme — **STATE.md tek rapor kaynağıdır.**
- Kod değişikliğinde yalnız değişen kısmı göster, dosyayı yeniden basma.
- Açıklama: kod öncesi en fazla 2-3 cümle (ne/neden). Sonrasında yalnız test yöntemi + varsa
  [EDİTÖR KONTROLÜ]. Uzun anlatım sadece Samet sorarsa.
- GDD/TDD'den alıntı yapma; bölüm numarası referansı yeter.

## Dil
Samet ile Türkçe konuş. Kod, tanımlayıcılar, commit mesajları İngilizce.
