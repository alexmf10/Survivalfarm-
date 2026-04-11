## Bus de eventos global (Autoload). Canal central de comunicación.
## Los actores y servicios emiten señales aquí; la UI las escucha sin conocer al emisor.
## También aloja el ServiceLocator para acceso global a servicios.
##
## Conexiones:
## • ProfileService emite: achievement_unlocked
## • UI screens emiten/escuchan: screen_change_requested, profile_updated
extends Node

# Señales globales
signal achievement_unlocked(achievement_id: String)
signal profile_updated()
signal screen_change_requested(screen_name: String)

# Registro de servicios compartidos.
var services: ServiceLocator = ServiceLocator.new()
