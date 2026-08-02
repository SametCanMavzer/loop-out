extends Node
## Çizim bütçesi ölçer (TDD §11). Gerçek sahneyi kurar ve kaç görsel nesne çizildiğini sayar.
##
## Neden gerekli: çizim çağrısı sayısı, orta seviye Android tarayıcıda 60 FPS'in en tipik
## darboğazı. Dekor ve 16 kişilik kadro eklendikçe bu sayı sessizce şişebilir; burada
## sayılıyor ve bir tavana bağlanıyor.
##
## Not: headless'ta gerçek renderer yok, bu yüzden GPU sayacı okunamaz — çizilebilir NESNE
## sayısı sayılır. MultiMesh, içinde kaç kopya olursa olsun tek nesnedir; bu yüzden burada
## 1 sayılır ve zaten olayın özü budur.
##
## Çalıştırma: godot --headless scenes/dev/probe_perf.tscn

## Tavan: WebGL2/Compatibility'de orta seviye Android için pratik sınır 150-200 civarı;
## 120 rahat bir çalışma payı bırakır. (İlk sürümde 60 yazılmıştı — dayanağı olmayan bir
## sayıydı ve sahne 63'te "bütçe aşıldı" diyordu. Eşik ölçüme değil tahmine dayanıyordu.)
const BUDGET := 120


func _ready() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	add_child(scene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame

	var mesh := 0
	var multi := 0
	var multi_instances := 0
	var label3d := 0
	var by_owner := {}
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var kind := ""
		if n is MultiMeshInstance3D:
			multi += 1
			kind = "MultiMesh"
			var mm := (n as MultiMeshInstance3D).multimesh
			if mm != null:
				multi_instances += mm.instance_count
		elif n is Label3D:
			label3d += 1
			kind = "Label3D"
		elif n is MeshInstance3D:
			mesh += 1
			kind = "Mesh"
		if kind != "":
			var group := _group_of(n)
			by_owner[group] = int(by_owner.get(group, 0)) + 1
		for c in n.get_children():
			stack.append(c)

	var total := mesh + multi + label3d
	print("=== ÇİZİM BÜTÇESİ ===")
	var keys := by_owner.keys()
	keys.sort()
	for k in keys:
		print("  %-14s %3d" % [k, by_owner[k]])
	print("  ---")
	print("  MeshInstance3D %d + MultiMesh %d + Label3D %d = %d çizilebilir nesne"
		% [mesh, multi, label3d, total])
	print("  MultiMesh içindeki toplam kopya: %d (bunlar tek çağrıda çizilir)" % multi_instances)
	if total <= BUDGET:
		print("  SONUÇ: bütçe içinde (%d ≤ %d) ✓" % [total, BUDGET])
	else:
		print("  SONUÇ: bütçe AŞILDI (%d > %d) ✗" % [total, BUDGET])
	get_tree().quit(0 if total <= BUDGET else 1)


func _group_of(n: Node) -> String:
	var p := n
	while p != null:
		if p.name == "Schoolyard":
			return "dekor"
		if p.name == "Figures":
			return "figürler"
		if p.name == "RopeSpinner":
			return "ip"
		p = p.get_parent()
	return "diğer"
