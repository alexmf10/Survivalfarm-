## Gestiona el inventario del jugador (cosechas y semillas) y la lógica
## de compraventa con el comerciante.
##
## --- Inventario ---
## • _crop_inventory: cultivos cosechados disponibles para vender.
## • _seed_inventory: semillas compradas (para uso futuro en el sistema de siembra).
## • coins: monedas del jugador.
##
## --- Señales ---
## • Escucha: EventBus.crop_harvested → añade cultivo al inventario.
## • Emite: EventBus.inventory_updated(coins) → notifica cambios de inventario.
class_name TradeService
extends RefCounted

const MAX_SLOTS = 16

const SELL_PRICES: Dictionary = {
	CropComponent.CropType.Wheat: 5,
	CropComponent.CropType.Beet: 8,
}

const SEED_PRICES: Dictionary = {
	CropComponent.CropType.Wheat: 3,
	CropComponent.CropType.Beet: 5,
}

const CROP_NAMES: Dictionary = {
	CropComponent.CropType.Wheat: "Wheat",
	CropComponent.CropType.Beet: "Beet",
}


var coins: int = 50
var _slots: Array = [] # Inventario
	
var _crop_inventory: Dictionary = {}  # CropType → int
var _seed_inventory: Dictionary = {   # CropType → int (starting seeds)
	CropComponent.CropType.Wheat: 5,
	CropComponent.CropType.Beet:  3,
}

# Base de datos de los sprites
var _crop_database: Dictionary = {
	CropComponent.CropType.Wheat: preload("res://data/definition/wheat.tres"),
	CropComponent.CropType.Beet: preload("res://data/definition/beet.tres")
}

var _seed_database: Dictionary = {
	CropComponent.CropType.Wheat: preload("res://data/definition/wheat_seed.tres"),
	CropComponent.CropType.Beet: preload("res://data/definition/beet_seed.tres")
}

var active_hotbar_index: int = 0 # Guardará un número del 0 al 3

func _init() -> void:
	# Preparamos los 16 huecos vacíos
	_slots.resize(MAX_SLOTS)
	_slots.fill(null)
	_add_to_inventory(_seed_database[CropComponent.CropType.Wheat], 5)
	_add_to_inventory(_seed_database[CropComponent.CropType.Beet], 3)

func connect_signals() -> void:
	EventBus.crop_harvested.connect(_on_crop_harvested)

##Buscamos si Resource existe. Si existe, lo apilamos. Si no existe, lo añadimos si quedan huecos libres
func _add_to_inventory(item_resource: Resource, amount: int) -> bool:
	#stackeamos items
	for i in range(_slots.size()):
		if _slots[i] != null and _slots[i]["item"] == item_resource:
			_slots[i]["amount"] += amount
			return true
			
	#si no, buscamos hueco vacío
	for i in range(_slots.size()):
		if _slots[i] == null:
			_slots[i] = {"item": item_resource, "amount": amount}
			return true
			
	return false # Inventario lleno

##Si el item Resource se encuentra en el inventario, eliminamos amount cantidad
func _remove_from_inventory(item_resource: Resource, amount: int) -> bool:
	#miramos los slots
	for i in range(_slots.size()):
		#encontramos el slot con el item a eliminar
		if _slots[i] != null and _slots[i]["item"] == item_resource:
			#eliminamos amount items
			if _slots[i]["amount"] >= amount:
				_slots[i]["amount"] -= amount
				if _slots[i]["amount"] <= 0:
					_slots[i] = null
				return true
	return false


##Añadimos al inventario una unidad del crop type recogido y emitimos señal de inventory updated
func _on_crop_harvested(_tile_pos: Vector2i, crop_type: CropComponent.CropType) -> void:
	var item_to_add = _crop_database[crop_type]
	if _add_to_inventory(item_to_add, 1):
		EventBus.inventory_updated.emit(_slots, coins)

##Buscamos crop_type en el inventario y devolvemos su amount, o 0 si no tenemos.
func get_crop_count(crop_type: CropComponent.CropType) -> int:
	var item = _crop_database[crop_type]
	for slot in _slots:
		if slot != null and slot["item"] == item: return slot["amount"]
	return 0

##Buscamos crop_type en el inventario y devolvemos su amount, o 0 si no tenemos.
func get_seed_count(crop_type: CropComponent.CropType) -> int:
	var item = _seed_database[crop_type]
	for slot in _slots:
		if slot != null and slot["item"] == item: return slot["amount"]
	return 0


#func consume_seed(crop_type: CropComponent.CropType) -> bool:
	#var item_to_consume = _seed_database[crop_type]
	#if _remove_from_inventory(item_to_consume, 1):
		#EventBus.inventory_updated.emit(_slots, coins)
		#return true
	#return false

#shop logic-------------

func sell_crop(crop_type: CropComponent.CropType) -> bool:
	var item_to_sell = _crop_database[crop_type]
	if _remove_from_inventory(item_to_sell, 1):
		coins += SELL_PRICES.get(crop_type, 0)
		EventBus.inventory_updated.emit(_slots, coins)
		return true
	return false


func buy_seeds(crop_type: CropComponent.CropType) -> bool:
	var price: int = SEED_PRICES.get(crop_type, 0)
	#dinero insuficiente
	if coins < price:
		return false
	var item_to_buy = _seed_database[crop_type]
	#intentamos meter el item
	if _add_to_inventory(item_to_buy, 1):
		coins -= price
		EventBus.inventory_updated.emit(_slots, coins)
		return true
		#no se pudo añadir (inventario lleno)
	else: return false

#Hotbar logic-------------
## Cambia el slot activo a index
func set_active_slot(index: int) -> void:
	if index >= 0 and index <= 3:
		active_hotbar_index = index
		EventBus.hotbar_selection_changed.emit(index) 

## Devuelve la información completa del slot actual seleccionado
func get_active_slot_data() -> Variant:
	return _slots[active_hotbar_index]

## Devuelve la semilla que tienes seleccionada (o null si no es una semilla)
func get_active_seed() -> CropComponent:
	var data = get_active_slot_data()
	if data and data["item"].is_seed:
		return data["item"]
	return null

## Gasta una unidad del item en la mano (
func consume_active_item() -> void:
	var data = get_active_slot_data()
	if data:
		_remove_from_inventory(data["item"], 1)
		EventBus.inventory_updated.emit(_slots, coins)
