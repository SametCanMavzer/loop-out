class_name GameState extends RefCounted
## Oyun akışı durum makinesi (TDD §3.3): MENU → COUNTDOWN → PLAYING → (SPECTATE) → RESULTS → COUNTDOWN…
## Basit enum + match; framework yok. Saf mantık — autoload'a bağlı DEĞİL, sinyal yayar.
## Geçersiz geçişler reddedilir (assert değil: sessizce false döner, çağıran karar verir).

signal state_changed(from: int, to: int)

enum State { MENU, COUNTDOWN, PLAYING, SPECTATE, RESULTS }

## İzinli geçişler (§3.3). SPECTATE: oyuncu elendi ama tur sürüyor (E11 izleme modu).
const TRANSITIONS := {
	State.MENU: [State.COUNTDOWN],
	State.COUNTDOWN: [State.PLAYING, State.MENU],
	State.PLAYING: [State.SPECTATE, State.RESULTS, State.MENU],
	State.SPECTATE: [State.RESULTS, State.MENU],
	State.RESULTS: [State.COUNTDOWN, State.MENU],
}

var current: State = State.MENU


func can_go(to: State) -> bool:
	return TRANSITIONS.get(current, []).has(to)


## Duruma geç. Geçersizse false döner ve durum değişmez.
func go(to: State) -> bool:
	if not can_go(to):
		return false
	var from := current
	current = to
	state_changed.emit(from, to)
	return true


## Tam sıfırlama (restart = sahne reload DEĞİL, §7.1).
func reset() -> void:
	current = State.MENU


func is_running() -> bool:
	return current == State.PLAYING or current == State.SPECTATE
