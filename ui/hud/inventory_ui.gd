extends Control

var is_open = false
@onready var grid: GridContainer = $NinePatchRect2/NinePatchRect/GridContainer
@onready var btn_close: TextureButton = $NinePatchRect2/exit_button
@onready var btn_trash: TextureButton = $NinePatchRect2/trash_button
@onready var trash_slot = $NinePatchRect2/trash_slot

# Rutas para los slots de equipamiento de la derecha
@onready var armor_bot = $NinePatchRect2/NinePatchRect3/armor_bot
@onready var armor_chest = $NinePatchRect2/NinePatchRect3/armor_chest
@onready var armor_helm = $NinePatchRect2/NinePatchRect3/armor_helm
@onready var weapon_slot = $NinePatchRect2/NinePatchRect3/weapon_slot

func _ready() -> void:
	close()
	# Nos conectamos al EventBus con la nueva firma de la señal
	EventBus.inventory_updated.connect(_on_inventory_updated)
	
	# Conectamos los botones del inventario
	if btn_close:
		btn_close.pressed.connect(close)
	if btn_trash:
		btn_trash.pressed.connect(_on_trash_pressed)
	
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

## Lógica de la papelera
func _on_trash_pressed() -> void:
	var trade_svc = EventBus.services.trade as TradeService
	# Si el slot de la papelera tiene algo, le decimos al TradeService que lo borre
	if trade_svc and trash_slot.has_item:
		trade_svc.clear_slot(trash_slot.my_index)

## Actualización de TODOS los slots de la pantalla
func _on_inventory_updated(slots: Array, _coins: int) -> void:
	var visual_slots = []
	
	# 1. Metemos los 16 slots principales del Grid (Índices 0 al 15)
	visual_slots.append_array(grid.get_children())
	
	# 2. Metemos los 4 slots de equipamiento (Índices 16 al 19)
	visual_slots.append(armor_bot)
	visual_slots.append(armor_chest)
	visual_slots.append(armor_helm)
	visual_slots.append(weapon_slot)
	
	# 3. Metemos el slot de la papelera (Índice 20)
	visual_slots.append(trash_slot)
	
	# Actualizamos cada slot pasándole su nuevo índice
	for i in range(visual_slots.size()):
		var slot = visual_slots[i]
		if i < slots.size():
			slot.display(slots[i], i)
		else:
			slot.display(null, i)
