extends Node
## Headless balans simülasyonu (TDD §18-11'in erken/küçük hâli). Görselsiz ArenaController'ı
## çok seed ile hızlı koşturur, GDD §4.2 kadro eğrisini ölçer:
##   tur 5→13 kişi, tur 12→9, tur 19→6, tur 29→3 (oyuncu botmuş gibi sayılır; oyuncu oynamaz).
## Çalıştırma: godot --headless scenes/dev/sim_balance.tscn

const SEEDS := 12
const MAX_TICKS := 12000
const CHECKPOINTS := [5, 12, 19, 29]
const TARGETS := {5: 13, 12: 9, 19: 6, 29: 3}


func _ready() -> void:
	var sums := {}
	var counts := {}
	for cp in CHECKPOINTS:
		sums[cp] = 0.0
		counts[cp] = 0
	var end_rounds: Array = []

	for s in SEEDS:
		var res := _run_one(1000 + s * 77)
		for cp in CHECKPOINTS:
			if res.alive_at.has(cp):
				sums[cp] += res.alive_at[cp]
				counts[cp] += 1
		end_rounds.append(res.end_round)

	print("=== BALANS SİMÜLASYONU (%d seed) ===" % SEEDS)
	for cp in CHECKPOINTS:
		var avg: float = (float(sums[cp]) / float(counts[cp])) if counts[cp] > 0 else -1.0
		print("tur %2d: ortalama canlı %.1f  (GDD hedef %d)  [%d/%d seed ulaştı]"
			% [cp, avg, TARGETS[cp], counts[cp], SEEDS])
	var mean_end := 0.0
	for e in end_rounds:
		mean_end += e
	print("tur sonu ortalaması: %.1f  (GDD: oyun 30+ turda biter, 60-120 sn)" % (mean_end / float(end_rounds.size())))
	_check_restart()
	get_tree().quit()


## Restart bütünlüğü (§7.1): aynı controller ikinci turda temiz sıfırlanmalı.
func _check_restart() -> void:
	var ctrl := ArenaController.new()
	add_child(ctrl)
	var queue := InputQueue.new()
	add_child(queue)
	ctrl.setup(queue)
	ctrl.set_physics_process(false)
	ctrl.start_round(4242)
	for i in 3000:
		ctrl.step()
		if ctrl.alive_ids.size() <= 1:
			break
	var after_first := ctrl.alive_ids.size()
	ctrl.start_round(4242)          # restart
	var ok := ctrl.alive_ids.size() == 16 and ctrl.round_no == 1 and ctrl.clock.current_tick == 0
	print("restart: 1. tur sonu %d canlı → yeniden başlat: %d canlı, tur %d, tick %d  [%s]"
		% [after_first, ctrl.alive_ids.size(), ctrl.round_no, ctrl.clock.current_tick,
			("OK" if ok else "HATA")])
	ctrl.queue_free()
	queue.queue_free()


func _run_one(seed: int) -> Dictionary:
	var ctrl := ArenaController.new()
	add_child(ctrl)
	var queue := InputQueue.new()
	add_child(queue)
	ctrl.setup(queue)
	ctrl.set_physics_process(false)     # adımları biz süreceğiz
	ctrl.start_round(seed)

	var alive_at := {}
	var end_round := 0
	for i in MAX_TICKS:
		ctrl.step()
		var r := ctrl.round_no
		if not alive_at.has(r):
			alive_at[r] = ctrl.alive_ids.size()
		if ctrl.alive_ids.size() <= 1:
			end_round = r
			break
		end_round = r
	ctrl.queue_free()
	queue.queue_free()
	return {"alive_at": alive_at, "end_round": end_round}
