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
var _crop_inventory: Dictionary = {}  # CropType → int
var _seed_inventory: Dictionary = {}  # CropType → int


func connect_signals() -> void:
	EventBus.crop_harvested.connect(_on_crop_harvested)


func _on_crop_harvested(_tile_pos: Vector2i, crop_type: CropComponent.CropType) -> void:
	_crop_inventory[crop_type] = _crop_inventory.get(crop_type, 0) + 1
	EventBus.inventory_updated.emit(coins)


func get_crop_count(crop_type: CropComponent.CropType) -> int:
	return _crop_inventory.get(crop_type, 0)


func get_seed_count(crop_type: CropComponent.CropType) -> int:
	return _seed_inventory.get(crop_type, 0)


func sell_crop(crop_type: CropComponent.CropType) -> bool:
	if _crop_inventory.get(crop_type, 0) <= 0:
		return false
	_crop_inventory[crop_type] -= 1
	coins += SELL_PRICES.get(crop_type, 0)
	EventBus.inventory_updated.emit(coins)
	return true


func buy_seeds(crop_type: CropComponent.CropType) -> bool:
	var price: int = SEED_PRICES.get(crop_type, 0)
	if coins < price:
		return false
	coins -= price
	_seed_inventory[crop_type] = _seed_inventory.get(crop_type, 0) + 1
	EventBus.inventory_updated.emit(coins)
	return true
