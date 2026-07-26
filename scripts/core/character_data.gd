class_name CharacterData extends Resource
## Koleksiyon karakteri (GDD §6.3). YALNIZ KOZMETİK — hiçbir alan oynanışı etkilemez
## (pay-to-win kesinlikle yok). Nadirlik = özel eleme animasyonu + zıplama efekti (şov).

enum Rarity { COMMON, RARE, LEGENDARY }

@export var id: StringName = &"default"
@export var display_name: String = ""
@export_enum("COMMON", "RARE", "LEGENDARY") var rarity: int = 0
@export var color: Color = Color(0.35, 0.6, 0.9)      # kapsül rengi (v1 görseli)
@export var jump_fx: StringName = &""                 # nadirlik şovu (F14)
@export var elim_fx: StringName = &""                 # özel eleme animasyonu (F14)
