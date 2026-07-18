# Kurulum (bir kez yapılır)

1. Bu klasörün içeriğini boş proje klasörüne kopyala.
2. GDD'yi `docs/gdd.md`, TDD'yi `docs/tdd.md` olarak kaydet (md formatında, PDF değil).
3. Godot 4.4'ü indir ve `godot` komutunu PATH'e ekle (headless testler için şart).
4. Klasörde `claude` çalıştır.

## İlk oturum prompt'u (kopyala-yapıştır)

```
docs/tdd.md ve STATE.md'yi oku. TDD §18 ile STATE.md yol haritasının tutarlı olduğunu
doğrula, sonra /gorev ile Faz 1'e başla.
```

## Günlük kullanım
- Yeni görev: `/gorev`
- Hata bildirimi: `/hata <belirti>` (tur içi bugsa F3'ten seed numarasını da yaz)
- Oturum kapatırken: `/gunsonu`
- [EDİTÖR KONTROLÜ] geldiğinde editörde bak, sonucu tek cümleyle bildir ("onay" / "şu oldu: ...").

## Notlar
- Bu yapı sayesinde oturum sıfırlansa bile hiçbir şey kaybolmaz: CLAUDE.md kuralları,
  STATE.md ilerlemeyi taşır. Uzun oturumda context şişerse `/compact` kullan ya da
  oturumu kapatıp yeniden aç — STATE.md kaldığın yeri bilir.
- CLAUDE.md'deki kurallara ekleme yapmak istersen oturum içinde `#` ile başlayan mesaj
  yaz — Claude Code otomatik CLAUDE.md'ye işler.
```
