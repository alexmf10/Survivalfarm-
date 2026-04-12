extends Control

var is_open = false

## Para que el inventario se abra de momento se debe asignar un inventario al jugador para que pueda abrirlo
## Y meter el inventario en un canvasLayer dentro del world para verlo
##luego habrá que añadir el service para coger o tirar objetos

#############
##hay que cambiar el process para que se abra con el inventory service
#############

##Empezamos con el inventario cerrado
func _ready():
	close()

##Process que abre o cierra el inventario con la letra e
func _process(delta):
	if Input.is_action_just_pressed("e"):
		if is_open:
			close()
		else: 
			open()
	

##abrir inventario
func open():
	visible = true
	is_open = true

##Cerrar inventario
func close():
	visible = false
	is_open = false
