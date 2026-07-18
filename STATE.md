# STATE — İP ATLA v1 İlerleme
> Bu dosya projenin tek rapor kaynağıdır. Her görev sonunda Claude günceller.
> Şu an: **Faz 2 — Tick çekirdeği** (henüz başlanmadı). F1 tamamlandı ✅

## Yol haritası (TDD §18)
- [x] **F1 İskelet:** Godot projesi + klasör yapısı (TDD §2) + 7 autoload stub + balance.json yükleme + Git init + web export preset (threads OFF)
  - [x] F1a: proje iskeleti — project.godot (Compatibility, 60Hz tick, InputMap jump/duck), §2 klasör yapısı, 7 autoload stub, balance.json (§5.1), main.tscn, .gitignore, export_presets.cfg (threads OFF). Duman testi geçti: `tests/smoke_f1.gd` (7 autoload + Config yükleme + ms_to_ticks + Rng determinizm).
  - [x] F1-KAPI (E10 kapısı): hedef cihazda (2018 sınıfı Android, Chrome, web export threads OFF) `fps_test.tscn` 17 kapsül → **60 FPS onaylandı**. Mimari doğrulandı, riskli varsayım kapandı.
- [ ] **F2 Tick çekirdeği:** tick_clock + Rng 3 stream + input kuyruğu (tick damgalı)
- [ ] **F3 İp:** RopeState (yalnız Normal) + crossing matematiği + süpürme gölgesi
- [ ] **F4 Jumper:** zıplama + zamanlama sınıflandırma + input buffer → GDD Faz 1 HİS TESTİ
- [ ] **F5 Eleme:** sendeleme+af + eleme impuls + daralan çember + yeniden dizilim
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
(yok)

## Bilinen buglar
(yok)

## Karar günlüğü (yalnız TDD'den sapmalar, 1 satır/karar)
- Godot sürümü: TDD/CLAUDE.md "4.4" diyor ama yüklü sürüm **4.7.1 stable**; ona hedeflendi (config_version=5, GDScript 2.x aynı). Uyumsuzluk yok.
- balance.json: §5.1 şemasında `lookahead_ms` sehven `archetype_counts` içinde; §4.6'ya göre `bots` seviyesine taşındı.
- difficulty_rounds: GDD §4.1 tam davranış havuzu PDF (docs/gdd.md.pdf) metin okunamadığından §5.1'deki 2 çapa korundu; tam havuz F7'de doldurulacak.

## Teknik borç
(yok)
