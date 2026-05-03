extends Panel

@onready var item_icon = $itemIcon
@onready var amount_label: Label = $amountLabel

var my_index: int = -1
var has_item: bool = false

func display(data, index: int) -> void:
	my_index = index # Guardamos quiénes somos
	
	if data != null:
		has_item = true
		var item: CropComponent = data["item"] if data.has("item") else data["crop"]
		var amount: int = data["amount"]
		
		var atlas = AtlasTexture.new()
		atlas.atlas = item.spritesheet
		
		# Calculamos el recorte
		var target_col = item.drop_col
		if item.get("is_seed") != null and item.is_seed: 
			target_col = item.seed_col if item.get("seed_col") != null else 0
			
		var x_pos = target_col * item.frame_width
		var y_pos = item.spritesheet_row * item.frame_height
		atlas.region = Rect2(x_pos, y_pos, item.frame_width, item.frame_height)
		
		item_icon.texture = atlas
		item_icon.visible = true
		
		if amount > 1:
			amount_label.text = str(amount)
			amount_label.visible = true
		else:
			amount_label.visible = false
	else:
		has_item = false
		item_icon.visible = false
		amount_label.visible = false

# ==========================================
# DRAG & DROP NATIVO DE GODOT
# ==========================================

## 1. Al hacer clic y empezar a arrastrar
func _get_drag_data(at_position: Vector2) -> Variant:
	if not has_item:
		return null # Si está vacío, no arrastramos nada
		
	# Creamos un pequeño "fantasma" visual para que siga al ratón
	var preview_texture = TextureRect.new()
	preview_texture.texture = item_icon.texture
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.custom_minimum_size = size # El tamaño de nuestro panel
	preview_texture.modulate = Color(1, 1, 1, 0.7) # Un poco transparente
	
	var control_wrapper = Control.new()
	control_wrapper.add_child(preview_texture)
	preview_texture.position = -size / 2 # Centrar el dibujo en el puntero
	
	set_drag_preview(control_wrapper) # Godot se encarga de moverlo
	
	# Devolvemos un diccionario con nuestro índice para que el otro slot sepa quiénes somos
	return {"type": "inventory_slot", "index": my_index}

## 2. Al pasar el ratón por encima de este slot (mientras arrastramos algo)
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	# Comprobamos si lo que estamos soltando es un slot del inventario
	return typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "inventory_slot"

## 3. Al soltar el clic sobre este slot
func _drop_data(at_position: Vector2, data: Variant) -> void:
	var from_index = data["index"]
	var to_index = my_index
	
	# Gritamos al EventBus que queremos intercambiarnos
	EventBus.inventory_slot_swapped.emit(from_index, to_index)
