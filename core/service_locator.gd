## Registro centralizado de servicios. Permite acceder a cualquier servicio por nombre.
## Uso: EventBus.services.get_service(&"nombre") as MiServicio
class_name ServiceLocator
extends RefCounted

var _services: Dictionary = {} # StringName → Variant

# Registra un servicio
func register(service_name: StringName, service: Variant) -> void:
	if _services.has(service_name):
		# Si ya existía, avisamos y simplemente lo sustituimos.
		push_warning("ServiceLocator: servicio '%s' ya registrado, se sobreescribe." % service_name)
	_services[service_name] = service

# Obtiene un servicio
func get_service(service_name: StringName) -> Variant:
	if not _services.has(service_name):
		# Si no existe, 
		push_error("ServiceLocator: servicio '%s' no encontrado." % service_name)
		return null
	return _services[service_name]

# Verifica si un servicio existe
func has_service(service_name: StringName) -> bool:
	return _services.has(service_name)
