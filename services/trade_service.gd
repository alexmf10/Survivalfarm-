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

const MAX_SLOTS = 21
const MAX_STACK_SIZE = 64

const SELL_PRICES: Dictionary = {
	CropComponent.CropType.Wheat: 5,
	CropComponent.CropType.Beet: 8,
	CropComponent.CropType.Lavender: 15,
	CropComponent.CropType.Ember_lily: 40,
	CropComponent.CropType.Cotton: 75,
}

const SEED_PRICES: Dictionary = {
	CropComponent.CropType.Wheat: 3,
	CropComponent.CropType.Beet: 5,
		CropComponent.CropType.Lavender: 10,
	CropComponent.CropType.Ember_lily: 25,
	CropComponent.CropType.Cotton: 50,
}

const CROP_NAMES: Dictionary = {
	CropComponent.CropType.Wheat: "Wheat",
	CropComponent.CropType.Beet: "Beet",
	CropComponent.CropType.Lavender: "Lavender",
	CropComponent.CropType.Ember_lily: "Ember lily",
	CropComponent.CropType.Cotton: "Cotton",
}

var coins: int = 0
var _slots: Array = [] # Inventario
	
var _crop_inventory: Dictionary = {}  # CropType → int
var _seed_inventory: Dictionary = {   # CropType → int (starting seeds)
	CropComponent.CropType.Wheat: 5,
	CropComponent.CropType.Beet:  3,
}

# Base de datos de los sprites
var _crop_database: Dictionary = {
	CropComponent.CropType.Wheat: preload("res://data/definition/wheat.tres"),
	CropComponent.CropType.Beet: preload("res://data/definition/beet.tres"),
	CropComponent.CropType.Cotton: preload("res://data/definition/cotton.tres"),
	CropComponent.CropType.Ember_lily: preload("res://data/definition/ember_lily.tres"),
	CropComponent.CropType.Lavender: preload("res://data/definition/lavender.tres")
}

var _seed_database: Dictionary = {
	CropComponent.CropType.Wheat: preload("res://data/definition/wheat_seed.tres"),
	CropComponent.CropType.Beet: preload("res://data/definition/beet_seed.tres"),
	CropComponent.CropType.Cotton: preload("res://data/definition/cotton_seed.tres"),
	CropComponent.CropType.Ember_lily: preload("res://data/definition/ember_lily_seed.tres"),
	CropComponent.CropType.Lavender: preload("res://data/definition/lavender_seed.tres")
	
}

var _tool_database: Dictionary = {
	ToolsComponent.Tools.TillGround: preload("res://data/definition/hoe.tres"),
	ToolsComponent.Tools.WaterCrops: preload("res://data/definition/watering_can.tres"),
	ToolsComponent.Tools.Sword: preload("res://data/definition/weapon.tres")
}

var active_hotbar_index: int = 0 # Guardará un número del 0 al 3
var starter_pack_granted: bool = false
var _loading_state: bool = false

func _init() -> void:
	# Preparamos los 16 huecos vacíos
	_slots.resize(MAX_SLOTS)
	_slots.fill(null)

func connect_signals() -> void:
	EventBus.crop_harvested.connect(_on_crop_harvested)
	EventBus.inventory_slot_swapped.connect(_on_inventory_slot_swapped)


func get_save_data() -> Dictionary:
	var serialized: Array = []
	for slot in _slots:
		if slot == null:
			serialized.append(null)
		else:
			serialized.append({
				"item_path": (slot["item"] as Resource).resource_path,
				"amount": slot["amount"],
			})
	return {
		"coins": coins,
		"inventory": serialized,
		"active_hotbar_index": active_hotbar_index,
		"starter_pack_granted": starter_pack_granted,
	}


func load_from_save(data: Dictionary) -> void:
	coins = data.get("coins", 0)
	active_hotbar_index = clampi(int(data.get("active_hotbar_index", 0)), 0, 3)
	starter_pack_granted = bool(data.get("starter_pack_granted", false))
	_slots.fill(null)
	var saved: Array = data.get("inventory", [])
	for i: int in range(mini(saved.size(), MAX_SLOTS)):
		var entry = saved[i]
		if entry == null:
			continue
		var item_path: String = entry.get("item_path", "")
		if item_path == "":
			continue
		var item: Resource = load(item_path)
		if item:
			_slots[i] = {"item": item, "amount": entry.get("amount", 1)}
	EventBus.inventory_updated.emit(_slots, coins)

##Buscamos si Resource existe. Si existe, lo apilamos. Si no existe, lo añadimos si quedan huecos libres
## Añade items al inventario respetando el MAX_STACK_SIZE
func _add_to_inventory(item_resource: Resource, amount: int) -> bool:
	var amount_left = amount

	# Intentamos apilar en slots existentes que ya tengan este item y NO estén llenos
	for i in range(_slots.size()):
		if _slots[i] != null and _slots[i]["item"] == item_resource:
			var current_amount = _slots[i]["amount"]
			if current_amount < MAX_STACK_SIZE:
				var space_left = MAX_STACK_SIZE - current_amount
				
				# Si todo lo que entra cabe en el slot
				if amount_left <= space_left:
					_slots[i]["amount"] += amount_left
					return true 
				# Si sobra, llenamos este slot y seguimos buscando
				else:
					_slots[i]["amount"] = MAX_STACK_SIZE
					amount_left -= space_left

	# Si todavía queda cantidad por dejar, buscamos huecos vacíos
	for i in range(_slots.size()):
		if amount_left <= 0:
			break # Ya guardamos todo
			
		if _slots[i] == null:
			if amount_left <= MAX_STACK_SIZE:
				_slots[i] = {"item": item_resource, "amount": amount_left}
				return true
			else:
				_slots[i] = {"item": item_resource, "amount": MAX_STACK_SIZE}
				amount_left -= MAX_STACK_SIZE

	# Si llegamos aquí y amount_left > 0, el inventario, el espacio es insuficiente, el resto de items se pierden
	if amount_left > 0:
		return false 

	return true

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

## Vacía completamente un slot específico (usado por la papelera)
func clear_slot(index: int) -> void:
	if index >= 0 and index < _slots.size():
		_slots[index] = null
		EventBus.inventory_updated.emit(_slots, coins)

func _on_inventory_slot_swapped(from_index: int, to_index: int) -> void:
	# Verificación de seguridad
	if from_index < 0 or from_index >= MAX_SLOTS or to_index < 0 or to_index >= MAX_SLOTS: return
	if from_index == to_index: return
	
	var item_from = _slots[from_index]
	var item_to = _slots[to_index]
	
	# Si ambos slots tienen el MISMO item, intentamos fusionarlos
	if item_from != null and item_to != null and item_from["item"] == item_to["item"]:
		var total_amount = item_from["amount"] + item_to["amount"]
		
		# Si la suma no supera el límite, se junta todo en el slot elegido
		if total_amount <= MAX_STACK_SIZE:
			_slots[to_index]["amount"] = total_amount
			_slots[from_index] = null
		# Si lo supera, llenamos el slot elegido hasta 64 y dejamos el resto en el slot original
		else:
			_slots[to_index]["amount"] = MAX_STACK_SIZE
			_slots[from_index]["amount"] = total_amount - MAX_STACK_SIZE
			
	# Si son items diferentes o hay un hueco vacío, hacemos un intercambio normal
	else:
		var temp = _slots[from_index]
		_slots[from_index] = _slots[to_index]
		_slots[to_index] = temp
	
	# Avisamos a las interfaces para que se repinten
	_emit_inventory_updated()

##Añadimos al inventario una unidad del crop type recogido y emitimos señal de inventory updated
func _on_crop_harvested(_tile_pos: Vector2i, crop_type: CropComponent.CropType) -> void:
	var item_to_add = _crop_database[crop_type]
	if _add_to_inventory(item_to_add, 1):
		_emit_inventory_updated()

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


func grant_starter_pack() -> bool:
	if starter_pack_granted:
		return false
	starter_pack_granted = true
	coins += 50
	
	_add_to_inventory(_tool_database[ToolsComponent.Tools.TillGround], 1)
	_add_to_inventory(_tool_database[ToolsComponent.Tools.WaterCrops], 1)
	_add_to_inventory(_tool_database[ToolsComponent.Tools.Sword], 1)
	
	add_seeds(CropComponent.CropType.Wheat, 40, false)
	add_seeds(CropComponent.CropType.Beet, 20, false)
	_emit_inventory_updated()
	return true


func has_crops(wheat_amount: int, beet_amount: int) -> bool:
	return (
		get_crop_count(CropComponent.CropType.Wheat) >= wheat_amount
		and get_crop_count(CropComponent.CropType.Beet) >= beet_amount
	)


func remove_crops(wheat_amount: int, beet_amount: int) -> bool:
	if not has_crops(wheat_amount, beet_amount):
		return false
	_remove_from_inventory(_crop_database[CropComponent.CropType.Wheat], wheat_amount)
	_remove_from_inventory(_crop_database[CropComponent.CropType.Beet], beet_amount)
	_emit_inventory_updated()
	return true


func add_seeds(crop_type: CropComponent.CropType, amount: int, emit_update: bool = true) -> bool:
	if amount <= 0:
		return true
	var success := _add_to_inventory(_seed_database[crop_type], amount)
	if success and emit_update:
		_emit_inventory_updated()
	return success

#shop logic-------------

func sell_crop(crop_type: CropComponent.CropType) -> bool:
	var item_to_sell = _crop_database[crop_type]
	if _remove_from_inventory(item_to_sell, 1):
		coins += SELL_PRICES.get(crop_type, 0)
		_emit_inventory_updated()
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
		_emit_inventory_updated()
		EventBus.seeds_purchased.emit(crop_type)
		return true
		#no se pudo añadir (inventario lleno)
	else: return false

#Hotbar logic-------------
## Cambia el slot activo a index
func set_active_slot(index: int) -> void:
	if index >= 0 and index <= 3:
		active_hotbar_index = index
		_save_state()
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
		_emit_inventory_updated()


func apply_save_state(state: Dictionary) -> void:
	_loading_state = true
	coins = int(state.get("coins", 0))
	active_hotbar_index = clampi(int(state.get("active_hotbar_index", 0)), 0, 3)
	starter_pack_granted = bool(state.get("starter_pack_granted", false))
	_slots.resize(MAX_SLOTS)
	_slots.fill(null)

	var saved_slots: Array = state.get("slots", [])
	for i in range(min(saved_slots.size(), MAX_SLOTS)):
		var slot_data = saved_slots[i]
		if slot_data is Dictionary:
			var item := _item_from_saved_slot(slot_data)
			var amount: int = int(slot_data.get("amount", 0))
			if item and amount > 0:
				_slots[i] = {"item": item, "amount": amount}

	_loading_state = false
	EventBus.inventory_updated.emit(_slots, coins)


func get_save_state() -> Dictionary:
	var saved_slots: Array = []
	for slot in _slots:
		saved_slots.append(_saved_slot_from_inventory_slot(slot))
	return {
		"coins": coins,
		"slots": saved_slots,
		"active_hotbar_index": active_hotbar_index,
		"starter_pack_granted": starter_pack_granted,
	}


func _saved_slot_from_inventory_slot(slot) -> Variant:
	if slot == null:
		return null
	var item: Resource = slot["item"]
	
	#Comprobamos si el objeto es una herramienta
	for tool_key in _tool_database:
		if _tool_database[tool_key] == item:
			return {
				"is_tool": true,
				"tool_type": int(tool_key),
				"amount": int(slot["amount"])
			}

	#Si no es herramienta, seguimos con la lógica normal de cultivos/semillas
	var crop_type: int = _crop_type_for_item(item)
	if crop_type == -1:
		return null
		
	return {
		"is_tool": false,
		"crop_type": crop_type,
		"is_seed": bool(item.is_seed),
		"amount": int(slot["amount"]),
	}


func _item_from_saved_slot(slot_data: Dictionary) -> Resource:
	#Si los datos guardados dicen que es una herramienta, la cargamos
	if slot_data.get("is_tool", false):
		var tool_type: int = int(slot_data.get("tool_type", -1))
		if _tool_database.has(tool_type):
			return _tool_database[tool_type]
		return null

	#Si no es herramienta, cargamos semillas o cultivos
	var crop_type: int = int(slot_data.get("crop_type", -1))
	var is_seed: bool = bool(slot_data.get("is_seed", false))
	
	if is_seed and _seed_database.has(crop_type):
		return _seed_database[crop_type]
	if not is_seed and _crop_database.has(crop_type):
		return _crop_database[crop_type]
	return null


func _crop_type_for_item(item: Resource) -> int:
	for crop_type in _crop_database:
		if _crop_database[crop_type] == item:
			return int(crop_type)
	for crop_type in _seed_database:
		if _seed_database[crop_type] == item:
			return int(crop_type)
	return -1


func _emit_inventory_updated() -> void:
	_save_state()
	EventBus.inventory_updated.emit(_slots, coins)


func _save_state() -> void:
	if _loading_state:
		return
	var save_svc := EventBus.services.save as SaveService
	if save_svc and save_svc.active_slot > 0:
		save_svc.save_trade_state(save_svc.active_slot, get_save_state())
