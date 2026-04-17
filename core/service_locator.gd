## Registro centralizado de servicios. Permite acceder a cualquier servicio por nombre.
## Uso: EventBus.services.get_service(&"nombre") as MiServicio
class_name ServiceLocator
extends RefCounted

var _services: Dictionary = {} # StringName → Variant

# Registra un servicio
func register(service_name: StringName, service: Variant) -> void:
	if _services.has(service_name):
		push_warning("ServiceLocator: servicio '%s' ya registrado, se sobreescribe." % service_name)
	_services[service_name] = service

# Obtiene un servicio
func get_service(service_name: StringName) -> Variant:
	if not _services.has(service_name):
		push_error("ServiceLocator: servicio '%s' no encontrado." % service_name)
		return null
	return _services[service_name]

# Verifica si un servicio existe
func has_service(service_name: StringName) -> bool:
	return _services.has(service_name)


## Atajos de acceso rápido

var profile: RefCounted:
	get: return get_service(&"profile")

var save: RefCounted:
	get: return get_service(&"save")

## Atajo para DayCycleService (Node, no RefCounted).
## Registrado por main.gd al arrancar.
var day_cycle: Node:
	get: return get_service(&"day_cycle")

var input: RefCounted:
	get: return get_service(&"input")

var crop: RefCounted:
	get: return get_service(&"crop")
