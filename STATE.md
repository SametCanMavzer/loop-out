# STATE — İP ATLA v1 İlerleme
> Bu dosya projenin tek rapor kaynağıdır. Her görev sonunda Claude günceller.
> Şu an: **Faz 6 — Botlar** (henüz başlanmadı). F1–F5 tamamlandı ✅

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
- [ ] **F6 Botlar:** InputSource + Acemi/Panikçi/Sağlam + zorluk eğrisi bağlantısı
- [ ] **F7 Davranışlar:** telegraf sistemi + kalan 6 ip davranışı + Şovcu/Kopyacı + dinamik dram
- [ ] **F8 UI:** tek sahne router + HUD + sonuç + restart reset + oryantasyon
- [ ] **F9 Ekonomi:** save + jeton + gacha + karakter Resource sistemi
- [ ] **F10 Ses:** SFX havuzu + vuş metronomu + müzik pitch bağlama + slow-motion
- [ ] **F11 Test/Balans:** determinizm birim testleri + headless sim + tuning
- [ ] **F12 SDK:** Ads arayüzü + Poki/Crazy adaptörleri + analitik
- [ ] **F13 Yerelleştirme:** TR/EN + ayarlar + "rakipler hakkında" metni
- [ ] **F14 Polish:** partiküller + konfeti + kamera zoom + görseller
- [ ] **F15 Yayın:** export + itch + Poki/CrazyGames başvuru

## Bekleyen [EDİTÖR KONTROLÜ]
- **F4b-KAPI (GDD Faz 1 HİS TESTİ):** `scenes/dev/play_test.tscn` çalıştır. Mavi kapsül (270°, önde) + dönen ip. **SPACE** ile ip sana yaklaşırken zıpla → üstte PERFECT/GRAZE/MISS + delta ms. **SPACE basılı tut** = yüksek zıplama (daha uzun havada). **S/↓** = eğil (kapsül çömelir). Değerlendir: zamanlama penceresi adil mi, zıplama hissi tatmin edici mi, geç/erken basış doğru cezalandırıyor mu. Sonucu bildir (onay / "şu ayar tuhaf: ...").

## Bilinen buglar
(yok)

## Karar günlüğü (yalnız TDD'den sapmalar, 1 satır/karar)
- Godot sürümü: TDD/CLAUDE.md "4.4" diyor ama yüklü sürüm **4.7.1 stable**; ona hedeflendi (config_version=5, GDScript 2.x aynı). Uyumsuzluk yok.
- balance.json: §5.1 şemasında `lookahead_ms` sehven `archetype_counts` içinde; §4.6'ya göre `bots` seviyesine taşındı.
- difficulty_rounds: GDD §4.1 tam davranış havuzu PDF (docs/gdd.md.pdf) metin okunamadığından §5.1'deki 2 çapa korundu; tam havuz F7'de doldurulacak.
- Rope decoupling: §3.2 rope_crossed EventBus sinyali; ama Rope'u saf/test edilebilir tutmak için lokal `crossed` sinyali yayar + zamanlama pencerelerini parametre alır (autoload'a bağlı değil). EventBus köprüsü + round→pencere Config eşlemesi F5 GameState'te yapılır. (-s test bağlamı autoload global'lerini çözemiyor; bu decoupling hem doğru mimari hem test şartı.)
- **Crossing Model A (F4b HİS TESTİ sonrası, §4.3'ten sapma):** Havadaysan ip geçince en az GRAZE; delta<=perfect ise PERFECT; MISS yalnız yerdeysen. Sudden death'te (graze_ms<=perfect_ms) perfect değilsen MISS. Sebep: §4.3'ün "airborne-ama-erken=MISS" modeli test edilince adaletsiz hissettirdi (GRAZE hiç çıkmıyor, çoğu MISS). Samet onayı ile "havadaysan geçersin" modeline geçildi (§14.4 pencere-ayar kapısı).

## Teknik borç
(yok)
