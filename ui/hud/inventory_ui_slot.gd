extends Panel

@onready var item_icon: TextureRect = $itemIcon
@onready var amount_label: Label = $amountLabel

func display(data) -> void:
	if data != null:
		var item: CropComponent = data["item"] # ¡Ahora se llama item!
		var amount: int = data["amount"]
		
		var atlas = AtlasTexture.new()
		atlas.atlas = item.spritesheet
		
		# Siempre usamos drop_col como la columna visual de este ítem
		var x_pos = item.drop_col * item.frame_width 
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
		item_icon.visible = false
		amount_label.visible = false
