## Overlay visual al dormir en la cama.
## Secuencia:
##   1. Fade out a negro (1s)
##   2. Pausa en negro (1s) — durante esta pausa se ejecuta el callback de save+advance
##   3. Fade in a transparente (1s)
##   4. Modal "Partida guardada" con botón Aceptar
##
## Uso:
##   var overlay = preload("res://ui/menus/sleep_overlay.tscn").instantiate()
##   get_tree().root.add_child(overlay)
##   overlay.play_sleep_sequence(next_day, save_callback)
extends CanvasLayer

signal completed

const FADE_TIME: float = 1.0
const HOLD_TIME: float = 1.0

@onready var black: ColorRect = $BlackScreen
@onready var dialog: AcceptDialog = $SaveDialog

var _new_day: int = 1


func _ready() -> void:
	dialog.confirmed.connect(_on_dialog_accepted)
	dialog.close_requested.connect(_on_dialog_accepted)
	black.modulate.a = 0.0


## Lanza la secuencia completa.
## save_callback se ejecuta cuando la pantalla está totalmente negra
## (para que el cambio de día no sea visible "saltando").
func play_sleep_sequence(new_day: int, save_callback: Callable) -> void:
	_new_day = new_day
	var tween: Tween = create_tween()
	# 1. Fade a negro
	tween.tween_property(black, "modulate:a", 1.0, FADE_TIME)
	# 2. En negro: ejecutar save+advance
	tween.tween_callback(save_callback)
	tween.tween_interval(HOLD_TIME)
	# 3. Fade in (volver a ver)
	tween.tween_property(black, "modulate:a", 0.0, FADE_TIME)
	# 4. Mostrar modal
	tween.tween_callback(_show_dialog)


func _show_dialog() -> void:
	dialog.dialog_text = "Partida guardada\nDía %d" % _new_day
	dialog.popup_centered()


func _on_dialog_accepted() -> void:
	completed.emit()
	queue_free()
