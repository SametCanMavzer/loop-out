class_name Ring extends RefCounted
## Çember geometrisi (TDD §4.4). Saf statik yardımcılar — daralan yarıçap + yeniden dizilim.
## Dünya konumu rope rotasyon konvansiyonuyla uyumlu olmalı: (cos a, y, -sin a) (bkz. F4b).

## Yarıçap: 16 kişide r_max, 2 kişide r_min (§4.4). alive dışı değerler kırpılır.
static func radius_for(alive: int, r_min: float, r_max: float) -> float:
	return lerpf(r_min, r_max, clampf((alive - 2) / 14.0, 0.0, 1.0))


## N jumper'a eşit açı (TAU/N) dağıt, oyuncu (player_index) tam player_angle'da kalacak şekilde
## tüm dizilimi döndür (§4.4). Açısal sıra korunur → crossing sırası doğal gelir.
static func distribute_angles(n: int, player_index: int, player_angle: float) -> Array[float]:
	var out: Array[float] = []
	if n <= 0:
		return out
	var step := TAU / float(n)
	for i in n:
		out.append(fposmod(player_angle + (i - player_index) * step, TAU))
	return out


## Bir açıyı dünya konumuna çevirir (rope konvansiyonu). y dışarıdan.
static func world_pos(angle: float, radius: float, y: float = 0.0) -> Vector3:
	return Vector3(cos(angle) * radius, y, -sin(angle) * radius)
