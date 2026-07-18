Bir hata bildiriyorum: $ARGUMENTS

Protokol:
1. Belirtiyi analiz et, ilgili kodu oku (tahmin etme, dosyayı aç).
2. Olası sebepleri olasılık sırasına diz (max 3).
3. En olası sebep için EN DÜŞÜK MALİYETLİ düzeltmeyi uygula.
4. Sistemi yeniden yazma/yeniden tasarlama — mimari değişiklik gerektiğini düşünüyorsan
   önce gerekçesiyle sor, onaysız yapma.
5. Düzeltme sonrası: ilgili test varsa koş; yoksa ve mantık hatasıysa küçük bir regresyon
   testi ekle (tests/ altına). Görsel hataysa [EDİTÖR KONTROLÜ] ver.
6. `fix:` commit'i at. Tekrarlayan hata sınıfıysa STATE.md Teknik borç'a 1 satır not düş.

Bug tur içindeyse benden seed numarasını iste (debug overlay F3) — deterministik yapı sayesinde
aynı seed ile aynı hata üretilebilir.
