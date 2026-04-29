extends Control

var is_open = false
@onready var grid: GridContainer = $NinePatchRect2/NinePatchRect/GridContainer

func _ready() -> void:
	close()
	# Nos conectamos al EventBus con la nueva firma de la señal
	EventBus.inventory_updated.connect(_on_inventory_updated)
	
	# Actualizamos el inventario al conectarnos (después de seleccionar un archivo de guardado)
	var trade_svc = EventBus.services.trade
	if trade_svc:
		_on_inventory_updated(trade_svc._slots, trade_svc.coins)
	

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if is_open:
			close()
		else: 
			open()

##Abrir el inventario
func open() -> void:
	visible = true
	is_open = true
	EventBus.inventory_opened.emit()

##Cerrar el inventario
func close() -> void:
	visible = false
	is_open = false
	EventBus.inventory_closed.emit()

func _on_inventory_updated(slots: Array, _coins: int) -> void:
	var visual_slots = grid.get_children()
	
	for i in range(visual_slots.size()):
		var slot = visual_slots[i]
		
		# Si hay datos en esa posición, los mostramos
		if i < slots.size():
			slot.display(slots[i])
		else:
			slot.display(null)
