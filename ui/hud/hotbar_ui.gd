extends Control

@onready var grid: GridContainer = $NinePatchRect/GridContainer

func _ready() -> void:
	#Nos conectamos a los cambios del inventario y de selección de la hotbar
	EventBus.inventory_updated.connect(_on_inventory_updated)
	EventBus.hotbar_selection_changed.connect(_on_selection_changed)
	EventBus.inventory_opened.connect(func(): visible = false)
	EventBus.inventory_closed.connect(func(): visible = true)
	
	#Sincronización inicial al cargar la escena
	var trade_svc = EventBus.services.trade
	if trade_svc:
		_on_inventory_updated(trade_svc._slots, trade_svc.coins)
		_on_selection_changed(trade_svc.active_hotbar_index)


## Actualiza los dibujos usando SOLO los 4 primeros elementos del inventario
func _on_inventory_updated(slots: Array, _coins: int) -> void:
	var visual_slots = grid.get_children()
	
	# Recorremos solo nuestros 4 slots visuales
	for i in range(visual_slots.size()):
		if i < slots.size():
			visual_slots[i].display(slots[i],i) # Le pasamos el dato del inventario real
		else:
			visual_slots[i].display(null,i)


## Cambia el color de los slots para resaltar el que tienes en la mano
func _on_selection_changed(index: int) -> void:
	var visual_slots = grid.get_children()
	
	for i in range(visual_slots.size()):
		if i == index:
			# Slot seleccionado: Color original y opaco
			visual_slots[i].modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			# Slots no seleccionados: Ligeramente oscurecidos para dar contraste
			visual_slots[i].modulate = Color(0.6, 0.6, 0.6, 0.8)
