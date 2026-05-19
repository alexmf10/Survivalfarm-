extends Panel

@onready var item_icon = $itemIcon
@onready var amount_label: Label = $amountLabel
@export var is_weapon_slot: bool = false
@export var is_helm_slot: bool = false
@export var is_chest_slot: bool = false
@export var is_bot_slot: bool = false

var my_index: int = -1
var has_item: bool = false
var current_item: Resource = null # Aquí se guardará el hacha globalmente

func display(data, index: int) -> void:
	my_index = index 
	
	if data != null:
		has_item = true
		# Asignamos a la variable global de la clase para usarla después
		current_item = data["item"] if data.has("item") else data["crop"]
		var amount: int = data["amount"]
		
		var atlas = AtlasTexture.new()
		atlas.atlas = current_item.spritesheet # Usamos current_item
		
		# Calculamos el recorte
		var target_col = current_item.drop_col
		if current_item.get("is_seed") != null and current_item.is_seed: 
			target_col = current_item.seed_col if current_item.get("seed_col") != null else 0
			
		var x_pos = target_col * current_item.frame_width
		var y_pos = current_item.spritesheet_row * current_item.frame_height
		atlas.region = Rect2(x_pos, y_pos, current_item.frame_width, current_item.frame_height)
		
		item_icon.texture = atlas
		item_icon.visible = true
		
		if amount > 1:
			amount_label.text = str(amount)
			amount_label.visible = true
		else:
			amount_label.visible = false
	else:
		has_item = false
		current_item = null
		item_icon.visible = false
		amount_label.visible = false

# ==========================================
# DRAG & DROP NATIVO DE GODOT
# ==========================================

func _get_drag_data(at_position: Vector2) -> Variant:
	if not has_item:
		return null 
		
	var preview_texture = TextureRect.new()
	preview_texture.texture = item_icon.texture
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.custom_minimum_size = size 
	preview_texture.modulate = Color(1, 1, 1, 0.7) 
	
	var control_wrapper = Control.new()
	control_wrapper.add_child(preview_texture)
	preview_texture.position = -size / 2 
	
	set_drag_preview(control_wrapper) 
	
	# Enviamos info del slot a parte del item para ver sus restricciones
	return {
		"type": "inventory_slot", 
		"index": my_index, 
		"item": current_item, 
		"is_weapon_slot": is_weapon_slot
	}

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("type") or data["type"] != "inventory_slot":
		return false

	var dragged_item = data.get("item")
	var dragged_from_weapon_slot = data.get("is_weapon_slot", false)

	# CASO 1: weapon slot. Comparamos con el enum Sword (valor 5)
	if is_weapon_slot:
		if dragged_item is ToolsComponent and dragged_item.tool_type == ToolsComponent.Tools.Sword:
			return true
		return false 

	# CASO 2: otros slots.
	# Evitamos que al intercambiar, mandemos algo que no sea una espada al slot de armas.
	if dragged_from_weapon_slot and has_item:
		if not (current_item is ToolsComponent and current_item.tool_type == ToolsComponent.Tools.Sword):
			return false
			
	return true

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var from_index = data["index"]
	var to_index = my_index
	
	EventBus.inventory_slot_swapped.emit(from_index, to_index)
