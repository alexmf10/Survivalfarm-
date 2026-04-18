## Escena raíz Bootstrap (punto de entrada de la aplicación al iniciar).
## Los servicios se registran en EventBus._ready() para que estén disponibles
## desde cualquier escena. main.gd solo navega al menú principal.
extends Node


func _ready() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://ui/menus/main_menu.tscn")
