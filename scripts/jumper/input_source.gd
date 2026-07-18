class_name InputSource extends RefCounted
## Girdi kaynağı arayüzü (TDD §3.4). İnsan, bot ve (v2a) ghost AYNI Jumper kodundan geçer:
## bot avantajı imkânsızlaşır (E12), determinizm korunur, v2b NetworkInput tek sınıf olur.
## poll(tick): o tick'e ait komutları döndürür. Taban sınıf boş döner.

func poll(_tick: int) -> Array[InputCommand]:
	return []
