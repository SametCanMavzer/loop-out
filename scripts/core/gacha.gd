class_name Gacha extends RefCounted
## Çekiliş makinesi (GDD §6.3): 100 jeton = rastgele karakter (Crossy Road modeli).
## Yalnız kozmetik. Saf/decoupled: havuz + rng enjekte edilir, jeton işlemini çağıran yapar.
##
## Nadirlik ağırlıkları: yaygın ağır basar; sahip olunanlar da çıkabilir (duplikat) — ama
## sahip olunmayan varsa önce onlardan çekilir (yeni içerik hissi; duplikat sadece havuz
## tükendiğinde). Pity/duplikat-telafisi v1'de YOK (kapsam sadeliği).

const WEIGHTS := {
	CharacterData.Rarity.COMMON: 100.0,
	CharacterData.Rarity.RARE: 22.0,
	CharacterData.Rarity.LEGENDARY: 4.0,
}

var _pool: Array = []          # CharacterData listesi
var _rng: RandomNumberGenerator


func setup(pool: Array, rng: RandomNumberGenerator) -> void:
	_pool = pool
	_rng = rng


## Bir çekiliş yap. owned: sahip olunan id listesi. Döner: CharacterData (null = havuz boş).
## `is_new` bilgisi için çağıran owned.has(result.id) kontrol eder (çekilişten ÖNCE).
func draw(owned: Array) -> CharacterData:
	if _pool.is_empty() or _rng == null:
		return null
	var candidates: Array = _pool.filter(func(c): return not owned.has(String(c.id)))
	if candidates.is_empty():
		candidates = _pool                     # hepsi toplandı → duplikat
	return _weighted_pick(candidates)


func _weighted_pick(cands: Array) -> CharacterData:
	var total := 0.0
	for c in cands:
		total += float(WEIGHTS.get(c.rarity, 1.0))
	var r := _rng.randf() * total
	for c in cands:
		r -= float(WEIGHTS.get(c.rarity, 1.0))
		if r <= 0.0:
			return c
	return cands[cands.size() - 1]


## Havuzu diskten yükler (data/characters/*.tres). Sıra deterministik olsun diye id'ye göre sıralı.
static func load_pool() -> Array:
	var out: Array = []
	var dir := DirAccess.open("res://data/characters")
	if dir == null:
		return out
	var names := dir.get_files()
	names.sort()                               # Dictionary/dizin sırasına güvenme (§4.8)
	for f in names:
		var path := "res://data/characters/%s" % f.replace(".remap", "")
		if not path.ends_with(".tres"):
			continue
		var res := load(path)
		if res is CharacterData:
			out.append(res)
	return out
