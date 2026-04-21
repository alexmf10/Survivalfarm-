# Guía de Eliminación del Código de Test

Este documento lista exactamente qué borrar para eliminar todo el código de test
sin romper el juego.

## Paso 1: Borrar la carpeta `test/`

Eliminar toda la carpeta `res://test/` (3 archivos):
- `test/test_toolbar_hud.gd`
- `test/test_debug_commands.gd`
- `test/test_removal_guide.md` (este archivo)

## Paso 2: Modificar `services/game_world.gd`

Eliminar las líneas marcadas con `# [TEST]`:

```gdscript
# Buscar y eliminar estas líneas:
# [TEST] Mini-inventario de prueba
var test_toolbar_hud_scene: PackedScene = load("res://test/test_toolbar_hud.gd")
# ... y su instanciación

# [TEST] Debug commands
var test_debug: TestDebugCommands = TestDebugCommands.new()
# ... y su add_child
```

## Paso 3: Modificar `core/event_bus.gd`

Eliminar la señal marcada con `# [TEST]`:

```gdscript
# Buscar y eliminar esta línea:
# [TEST] Señal de debug — avanzar crecimiento de un cultivo manualmente.
signal debug_advance_crop(tile_pos: Vector2i)
```

## Paso 4: Modificar `services/crop_service.gd`

Eliminar las líneas marcadas con `# [TEST]`:

```gdscript
# En connect_signals(), eliminar:
# [TEST] Debug: avanzar crecimiento manualmente
EventBus.debug_advance_crop.connect(_on_debug_advance_crop)

# Eliminar los métodos:
func _on_debug_advance_crop(tile_pos: Vector2i) -> void:
    ...

func debug_advance_all() -> void:
    ...
```

## Verificación

Después de eliminar todo, ejecutar el juego y verificar que:
1. El menú principal carga sin errores
2. El juego carga la escena del mundo sin errores
3. El ciclo de cultivos funciona (arar → plantar → regar → esperar día → cosechar)
4. No aparecen errores en la consola de Godot
