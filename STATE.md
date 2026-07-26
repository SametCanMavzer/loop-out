# STATE — İP ATLA v1 İlerleme
> Bu dosya projenin tek rapor kaynağıdır. Her görev sonunda Claude günceller.
> Şu an: **Faz 9 — Ekonomi** (henüz başlanmadı). F1–F8 tamamlandı ✅ (oyun uçtan uca oynanır: 16 kişi, 7 davranış, HUD, sonuç, restart).

> GDD/TDD PDF'leri `pdftotext -enc UTF-8 docs/gdd.md.pdf out.txt` ile okunabilir (/mingw64/bin). GDD §4.1 tam davranış havuzu (7): normal, speed_step, sudden_stop, reverse, high_sweep, double_sweep, fake_slow. Zorluk eğrisi §4.2 balance.json'a işlendi. Özel mantık gerektirenler: sudden_stop (yarım tur durur), reverse (yön), double_sweep (çift süpürme), fake_slow (telegrafsız, tur25+); speed_step base'i kalıcı artırır.

## Yol haritası (TDD §18)
- [x] **F1 İskelet:** Godot projesi + klasör yapısı (TDD §2) + 7 autoload stub + balance.json yükleme + Git init + web export preset (threads OFF)
  - [x] F1a: proje iskeleti — project.godot (Compatibility, 60Hz tick, InputMap jump/duck), §2 klasör yapısı, 7 autoload stub, balance.json (§5.1), main.tscn, .gitignore, export_presets.cfg (threads OFF). Duman testi geçti: `tests/smoke_f1.gd` (7 autoload + Config yükleme + ms_to_ticks + Rng determinizm).
  - [x] F1-KAPI (E10 kapısı): hedef cihazda (2018 sınıfı Android, Chrome, web export threads OFF) `fps_test.tscn` 17 kapsül → **60 FPS onaylandı**. Mimari doğrulandı, riskli varsayım kapandı.
- [x] **F2 Tick çekirdeği:** tick_clock + Rng 3 stream + input kuyruğu (tick damgalı)
  - [x] `scripts/core/tick_clock.gd` (TickClock, 60Hz, advance/start/stop/reset + `ticked` sinyali), `input_command.gd` (InputCommand: tick+action+pressed, to_replay), `input_queue.gd` (InputQueue: `_input` yakalama + tick damgalama + FIFO `poll(tick)`). `touch_latency_offset_ms` config'e eklendi (§6, default 0). Birim testi geçti: `tests/test_tick_core.gd`.
  - NOT: canlı sahnede `TickClock.start()` + `InputQueue.setup()` bağlanması F5'te (GameState run döngüsü) yapılacak — henüz simüle edilecek bir şey yok. Determinizm sözleşmesi (advance()/poll() doğrudan çağrılabilir) test edildi.
- [x] **F3 İp:** RopeState (yalnız Normal) + crossing matematiği + süpürme gölgesi
  - [x] F3a: `scripts/rope/rope.gd` (Rope) — RopeState verisi (angle/angular_vel/height/mode) + açısal `swept_past` crossing (fizik motorsuz, TAU sarma-güvenli) + PERFECT/GRAZE/MISS sınıflandırma + HIGH/E7 (ducking nötr, airborne/yerde ıskalama). Config'e tipli `perfect_ms(round)`/`graze_ms(round)` getter'ları eklendi (§4.5 daralan/sudden-death graze). Birim testi: `tests/test_rope.gd` + Config getter'ları `smoke_f1.gd`'de.
  - [x] F3b: süpürme gölgesi + görsel ip dönüşü — `scripts/rope/rope_visual.gd` (RopeVisual: `_process`'te `lerp_angle` + physics interpolation fraction, LOW/HIGH yükseklik), `scenes/arena/rope_spinner.tscn` (bar + blob gölge), dev demo `scenes/dev/rope_demo.tscn`. **Editör onayı alındı** (akıcı dönüş + gölge + LOW/HIGH doğrulandı).
- [x] **F4 Jumper:** zıplama + zamanlama sınıflandırma + input buffer → GDD Faz 1 HİS TESTİ ✅
  - [x] F4a: `input_source.gd` (InputSource arayüzü), `human_input.gd` (poll→InputQueue), `jumper_tuning.gd` (tick cinsi zamanlama, Config'ten enjekte), `jumper.gd` (Jumper: airborne tick sayacı + hold→high "geç karar" + duck release toleransı + input buffer; Rope crossing hedefi). Config'e `jumper_tuning()` getter'ı. Birim testi: `tests/test_jumper.gd` + smoke'ta tuning doğrulaması. Autoload'dan bağımsız (test-edilebilir).
  - [x] F4b: oynanabilir sahne `scenes/dev/play_test.tscn` — GDD Faz 1 **HİS TESTİ onaylandı** ("his oturdu"). Bu turda 3 düzeltme: (1) yüksek zıplama görseli hız-tabanlı (pop yok), (2) crossing Model A (havada=en az GRAZE), (3) jumper dünya konumu rope rotasyon konvansiyonuna hizalandı (görsel/mantık geçiş uyumu — asıl his bugı). NOT: play_test dev kamera çerçevelemesi kaba (ip tam sığmıyor); gerçek arena kamerası F8.
- [x] **F5 Eleme:** sendeleme+af + eleme impuls + daralan çember + yeniden dizilim ✅
  - [x] F5a: `scripts/core/stumble_judge.gd` (StumbleJudge — Model A uyumlu: PERFECT/GRAZE=temiz, MISS=sendeleme; ⚠→af→eleme + sudden death; saf/autoload'suz, Outcome döndürür). Config'e `pardon_rounds(round)` getter'ı (§4.5, null→-1). Birim testi: `tests/test_stumble.gd` + smoke'ta pardon_rounds.
  - [x] F5b: `Ring` (radius_for + distribute_angles) + `arena_test` demosu — daralan çember + yeniden dizilim tween'i (crossing askıda, ip dönmeye devam) + tek gövde eleme impulsu + EventBus köprüsü. **Editör onayı alındı** ("ip dönmeye devam ediyor"). Denetimde 3 kusur düzeltildi (§4.4 ip donması, jumper node sızıntısı, tween üst üste binme). arena_test'e geçici "Yeniden Başlat" butonu (dev test kolaylığı).
- [x] **F6 Botlar:** InputSource + Acemi/Panikçi/Sağlam + zorluk eğrisi bağlantısı ✅
  - [x] F6a: `bot_archetype.gd` (BotArchetype Resource) + `bot_brain.gd` (BotBrain extends InputSource — Rng.bots'tan niyet tick'i örnekleme, sarma-güvenli t_cross tahmini, zorluk eğrisi σ(round), Acemi exit σ şişme). Autoload'suz (rng/rope/jumper enjekte). Birim testi: `tests/test_bot.gd` (determinizm, geçiş penceresi, InputSource sözleşmesi/E12).
  - [x] F6b: 3 arketip `.tres` + arena'da gerçek botlar (BotBrain, Rng.bots) + tur ilerlemesiyle σ büyümesi. **Editör onayı** ("botlar zıplıyor"). Denetimde 3 düzeltme: reset_intent (bayat niyet), eleme erteleme (rope.tick sırasında pozisyon değişimi → sahte MISS; miss oranı %15→%3), tüm jumper'lara zıplama görseli. İnce balans F11.
- [x] **F7 Davranışlar:** telegraf sistemi + kalan 6 ip davranışı + Şovcu/Kopyacı + dinamik dram ✅
  - [x] F7a: `rope_behavior.gd` (RopeBehavior Resource: id/min_round/weight/telegraph_ms/params) + Rope'a telegraf altyapısı (telegraph_ticks_left geri sayımı, queue_behavior, _apply_behavior speed_mult/height, base_angular_vel, behavior_telegraphed/started sinyalleri). Birim testi: `tests/test_behavior.gd`.
  - [x] F7b: generic 4 davranış `.tres` (normal/speed_step/reverse/high_sweep) + Rope etkileri (base kalıcı: speed_step tempo, reverse yön; geçici: height). Test: `tests/test_behavior.gd` (roster + etkiler).
  - [x] F7c: özel 3 davranış (sudden_stop yarım-tur zamanlı duruş, fake_slow yavaş→snap, double_sweep ertelenmiş ikinci süpürme) + .tres'leri. Rope'a zamanlı hız etkisi (_effect_ticks_left) + _deferred ikinci-süpürme kuyruğu. Test: `tests/test_behavior_special.gd`.
  - [x] F7d: `scripts/core/round_director.gd` (RoundDirector — ağırlıklı rastgele Rng.behavior, tur bazlı aktif set §4.2, min_round, max-2-ardışık; tick() seçim aralığında davranış döndürür). Decoupled. Test: `tests/test_director.gd`.
  - [x] F7e: Şovcu/Kopyacı arketipleri — BotBrain quirk dalı (SHOWOFF %30 takla→σ×2; COPYCAT oyuncunun zıplaması+gecikme, yoksa kendi örneklemi) + 2 `.tres`. Test: `tests/test_bot_quirk.gd`. NOT: SHOWOFF'un "perfect'te takla" tetiği stokastik σ×2 olarak yorumlandı (botlar nadiren perfect alır; niyet buydu).
  - [x] F7f: `scripts/core/drama_director.gd` (DramaDirector §4.7: kurtarma=streak≥eşik+tur≤3'te Acemi seç, final aday=Sağlam/en düşük σ) + BotBrain σ override (set_sigma_override). Decoupled. Test: `tests/test_drama.gd`.
  - [x] F7g: arena'ya bağlama (RoundDirector→rope telegraf, davranışlar canlı, Şovcu/Kopyacı botlar, dram). Kod+denetim bitti; **editör testi F8 sonunda gerçek arena ile birlikte** yapılacak (Samet kararı).
- [x] **F8 UI:** tek sahne router + HUD + sonuç + restart reset + oryantasyon ✅
  - [x] F8a: `scripts/core/game_state.gd` (GameState FSM §3.3: MENU→COUNTDOWN→PLAYING→SPECTATE→RESULTS, geçersiz geçiş reddi, reset) + `scripts/ui/ui_router.gd` (UIRouter: ekranlar ağaçta kalır, yalnız visible toggle §7.1) + `main.tscn` §7.1 iskeleti (Arena3D/UILayer{MainMenu,HUD,Results,Characters,SettingsPopup}/FadeLayer). Test: `tests/test_game_state.gd`.
  - [x] F8b: `arena_controller.gd` (16 kadro Config'ten + deterministik karıştırma, tur=ip tam turu, EventBus köprüsü, spectate kuralı, reset) + `arena_view.gd`/`arena.tscn` (görsel katman) + `main.gd`/`main.tscn` (GameState akışı, geri sayım, tur sonu). Doğrulama: `scenes/dev/sim_balance.tscn` (çok-seed kadro eğrisi + restart bütünlüğü).
  - [x] F8c: `hud.tscn/gd` (canlı sayaç+pulse, tur, combo, PERFECT/GRAZE/MISS, telegraf, ⚠ 4-ColorRect kenar çerçevesi, DOKUN ipucu) + `results.tscn/gd` (sıralama + tur + TEKRAR OYNA) + restart akışı (sahne reload yok; sim'de doğrulandı: 16 canlı/tur 1/tick 0).
  - [x] F8d: `camera_rig.gd` (§7.2 portrait/landscape preset + viewport size_changed tween; `KEEP_WIDTH` ile dar ekranda çember kadraja sığar — eski "ip sığmıyor" sorununun kalıcı çözümü). UI zaten anchor tabanlı, ikinci layout sahnesi yok.
  - [x] F8-KAPI: **Editör onayı alındı** (gerçek oyun main.tscn: 16 kişi, HUD, davranışlar, sonuç+restart, oryantasyon). F7 davranış testi de bu turda birlikte onaylandı. Testte 1 gerçek bug yakalandı (yeniden dizilimde "bedava tur") ve düzeltildi.
- [ ] **F9 Ekonomi:** save + jeton + gacha + karakter Resource sistemi
- [ ] **F10 Ses:** SFX havuzu + vuş metronomu + müzik pitch bağlama + slow-motion
- [ ] **F11 Test/Balans:** determinizm birim testleri + headless sim + tuning
- [ ] **F12 SDK:** Ads arayüzü + Poki/Crazy adaptörleri + analitik
- [ ] **F13 Yerelleştirme:** TR/EN + ayarlar + "rakipler hakkında" metni
- [ ] **F14 Polish:** partiküller + konfeti + kamera zoom + görseller
- [ ] **F15 Yayın:** export + itch + Poki/CrazyGames başvuru

## Bekleyen [EDİTÖR KONTROLÜ]
- **F8-KAPI (F7 davranış testi dahil):** `scenes/main.tscn` çalıştır — artık gerçek oyun. Kontrol listesi: (1) 16 kapsül + 1 sn geri sayım sonrası tur başlar; (2) HUD: canlı sayacı elemede pulse eder, tur no artar, PERFECT combo, ⚠ alınca ekran kenarı kırmızı çerçeve, ilk zıplamaya kadar "DOKUN"; (3) davranış telegrafları (⚠ SPEED_STEP / SUDDEN_STOP / REVERSE / HIGH_SWEEP / DOUBLE_SWEEP) ve etkileri okunuyor mu; (4) elenince ≤3 kaldıysa finali izleme, değilse doğrudan sonuç ekranı; (5) TEKRAR OYNA <2 sn'de yeni tur; (6) pencereyi yatay↔dikey boyutlandırınca kamera preset geçişi ve çember kadraja sığması. Kontroller: SPACE zıpla / basılı tut yüksek / S eğil.

## Bilinen buglar
(yok)

## Teknik notlar (denetimden)
- HIGH süpürmede **başarılı eğilme nötrdür** (§4.3: sinyal yok) → `crossed` sinyaliyle ölçülemez; ölçüm/HUD/ses (F10) için "temiz eğilme" geri bildirimi gerekirse Rope'a ayrı sinyal eklenmeli. Denetimde bu, sahte "%100 MISS" görüntüsü verdi (ölçüm düzeltildi).
- Bot MISS oranları (zorluk sıkılaştırması sonrası, 6 seed): high_sweep %8.5 · normal %17.5 · reverse %18.4 · speed_step %21.0 · sudden_stop %24.0 · double_sweep %38.5 (en zor ✓ GDD ★★★★).
- Kadro eğrisi (12 seed): tur 5/12/19/29 → 13.1/7.9/6.1/4.1 canlı (GDD hedef 13/9/6/3), oyun ~29 turda biter (hedef 30+). İnce ayar F11.
- **Yeniden dizilim artık crossing'i ASKIYA ALMIYOR** (§4.4 yorumu değişti): mantıksal açı da SHRINK_S boyunca tick tick kayar (ArenaView aynı açıyı okuduğu için görsel senkron). Eski askı modeli bir turu "bedava" geçiriyordu — Samet testinde yakalandı ("2 kez üst üste zıplamadım ama elenmedim").

## Karar günlüğü (yalnız TDD'den sapmalar, 1 satır/karar)
- Godot sürümü: TDD/CLAUDE.md "4.4" diyor ama yüklü sürüm **4.7.1 stable**; ona hedeflendi (config_version=5, GDScript 2.x aynı). Uyumsuzluk yok.
- balance.json: §5.1 şemasında `lookahead_ms` sehven `archetype_counts` içinde; §4.6'ya göre `bots` seviyesine taşındı.
- difficulty_rounds: GDD §4.1 tam davranış havuzu PDF (docs/gdd.md.pdf) metin okunamadığından §5.1'deki 2 çapa korundu; tam havuz F7'de doldurulacak.
- Rope decoupling: §3.2 rope_crossed EventBus sinyali; ama Rope'u saf/test edilebilir tutmak için lokal `crossed` sinyali yayar + zamanlama pencerelerini parametre alır (autoload'a bağlı değil). EventBus köprüsü + round→pencere Config eşlemesi F5 GameState'te yapılır. (-s test bağlamı autoload global'lerini çözemiyor; bu decoupling hem doğru mimari hem test şartı.)
- F7 denetimi: archetype_counts panikci 3→4 (GDD §5.1 "16 kadro"=15 bot; 14'tü). fake_slow telegraf sinyali artık 0-tick'te yayılmıyor (GDD "telegraf YOK" sızıntısı). fake_slow min_round=30 (GDD içinde 25+ vs tier 30+ çelişkisi tier lehine çözüldü). Botlar double_sweep'te basılı zıplar (GDD karşı hamle), davranış başlayınca niyet sıfırlar (bayat zamanlama adaleti), Panikçi telegraf paniği (σ×3, prob 0.6) implement edildi.
- **Zorluk sıkılaştırması (F8 testi sonrası, Samet kararı — "zıplamasam da elenmiyorum"):** (1) `jump_air_ms` 420→300, `high_jump_air_ms` 700→520, `hold_threshold_ms` 300→180; (2) **Model A sıkı**: havada olmak yetmez, ip geçerken zıplama yayının %12–88 aralığında olmalısın (`Jumper.is_clear`; erken zıplayıp inişe geçmişsen ıskalarsın); (3) af eşiği `pardon_rounds` 5→8 / 7→10 (GDD §3.2'den sapma). Bot arketipleri yeni pencereye kalibre edildi (mean −210→−150 ms, σ'lar ~%33 düşürüldü) — yoksa botlar da toplu eleniyordu (oyun 12-19 turda bitiyordu).
- **Crossing Model A (F4b HİS TESTİ sonrası, §4.3'ten sapma):** Havadaysan ip geçince en az GRAZE; delta<=perfect ise PERFECT; MISS yalnız yerdeysen. Sudden death'te (graze_ms<=perfect_ms) perfect değilsen MISS. Sebep: §4.3'ün "airborne-ama-erken=MISS" modeli test edilince adaletsiz hissettirdi (GRAZE hiç çıkmıyor, çoğu MISS). Samet onayı ile "havadaysan geçersin" modeline geçildi (§14.4 pencere-ayar kapısı).

## Teknik borç
(yok)
