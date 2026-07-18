extends Node
## Event kuyruğu → aktif platform adaptörü (TDD §13.4). Şimdilik STUB — F12'de doldurulur.

# TODO(F12): event kuyruğu, platform adaptörü (Poki/Crazy/Null),
#            ERROR log'da client_error event'i (§13.1).
func track(event: StringName, _params: Dictionary = {}) -> void:
	# Stub: geliştirmede görünürlük için sadece logla.
	if OS.is_debug_build():
		print("[Analytics] ", event)
