## Bus de eventos global (Autoload). Canal central de comunicación.
## Los actores y servicios emiten señales aquí; la UI las escucha sin conocer al emisor.
## También aloja el ServiceLocator para acceso global a servicios.
extends Node

# Registro de servicios compartidos.
var services: ServiceLocator = ServiceLocator.new()
