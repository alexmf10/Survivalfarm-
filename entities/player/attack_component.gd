## AttackComponent — Componente de ataque cuerpo a cuerpo del jugador.
##
## Responsabilidad única: detectar el input de ataque (clic izquierdo con
## espada equipada), reproducir la animación one-shot de ataque vía
## AnimationComponent, crear un hitbox temporal (Area2D) en la dirección
## a la que mira el jugador, y enviar el daño a los HealthComponent
## de las entidades impactadas usando CombatService.
##
## --- Arquitectura ---
## • Se cuelga como hijo del Player (CharacterBody2D).
## • Escucha la señal tool_changed del ToolComponent hermano para saber
##   cuándo la espada está equipada.
## • Usa AnimationComponent.play_action("attack") para la animación one-shot.
## • El hitbox se crea durante la animación y se destruye al terminar.
## • Emite EventBus.player_attack_started cuando se lanza un ataque.
##
## --- Daño ---
## • base_damage: daño base sin armadura (configurable por export).
## • El daño neto se calcula con CombatService.calculate_damage().
##
## --- Hitbox ---
## • Rectangular, posicionada delante del jugador según su facing.
## • Detecta colisiones con entidades que tengan HealthComponent.
## • Solo activa durante la ventana de impacto de la animación.
class_name AttackComponent
extends Node

# ── Configuración ────────────────────────────────────────────────────────────
## Daño base del ataque con espada (sin armadura del objetivo).
@export var base_damage: float = 15.0

## Alcance del hitbox en píxeles desde el centro del jugador.
@export var attack_range: float = 14.0

## Ancho del hitbox perpendicular a la dirección de ataque.
@export var attack_width: float = 12.0

## Fuerza del knockback aplicado a los enemigos golpeados (px/s de impulso).
@export var knockback_force: float = 130.0

## Duración del hitbox activo en segundos (ventana de impacto).
const HITBOX_DURATION: float = 0.25

# ── Estado interno ───────────────────────────────────────────────────────────
var _body: CharacterBody2D
var _animation: AnimationComponent
var _movement: MovementComponent
var _tool_component: Node  # ToolComponent
var _is_sword_equipped: bool = false
var _is_attacking: bool = false
var _hitbox: Area2D = null
var _damaged_entities: Array = []  # Evitar dañar al mismo enemigo dos veces
var _last_attack_facing: Vector2 = Vector2.DOWN  # Para calcular knockback


func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	if _body == null:
		push_error("AttackComponent: el padre no es un CharacterBody2D.")
		return

	# Buscar componentes hermanos
	for child in _body.get_children():
		if child is AnimationComponent:
			_animation = child
		if child is MovementComponent:
			_movement = child
		if child.get_script() and child is Node and child.has_signal("tool_changed"):
			_tool_component = child

	if _tool_component:
		_tool_component.tool_changed.connect(_on_tool_changed)

	if _animation:
		_animation.action_finished.connect(_on_attack_finished)


func _exit_tree() -> void:
	if _tool_component and _tool_component.tool_changed.is_connected(_on_tool_changed):
		_tool_component.tool_changed.disconnect(_on_tool_changed)
	if _animation and _animation.action_finished.is_connected(_on_attack_finished):
		_animation.action_finished.disconnect(_on_attack_finished)
	_cleanup_hitbox()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_sword_equipped or _is_attacking:
		return

	# Clic izquierdo → atacar
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_perform_attack()


# ── Handlers ─────────────────────────────────────────────────────────────────

func _on_tool_changed(new_tool: ToolsComponent.Tools) -> void:
	_is_sword_equipped = (new_tool == ToolsComponent.Tools.Sword)


func _on_attack_finished() -> void:
	if _is_attacking:
		_is_attacking = false
		_cleanup_hitbox()


# ── Lógica de ataque ─────────────────────────────────────────────────────────

func _perform_attack() -> void:
	if _animation == null or _body == null:
		return

	_is_attacking = true
	_damaged_entities.clear()

	# Bloquear movimiento durante el ataque
	if _movement:
		_movement.stop()

	# Reproducir animación de ataque (one-shot)
	_animation.play_action("attack")

	# Obtener dirección de facing
	var facing: Vector2 = Vector2.DOWN
	if _movement:
		facing = _movement.get_facing()
	_last_attack_facing = facing

	# Crear hitbox en la dirección del ataque
	_spawn_hitbox(facing)

	# Emitir señal global
	EventBus.player_attack_started.emit(base_damage, facing, _body.global_position)

	# Destruir hitbox tras la ventana de impacto
	await _body.get_tree().create_timer(HITBOX_DURATION).timeout
	_cleanup_hitbox()


func _spawn_hitbox(facing: Vector2) -> void:
	_cleanup_hitbox()

	_hitbox = Area2D.new()
	_hitbox.name = "AttackHitbox"
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 4  # Capa 3 = enemigos (bit 2)
	_hitbox.monitorable = false
	_hitbox.monitoring = true

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()

	# Orientar el hitbox según la dirección
	if facing == Vector2.LEFT or facing == Vector2.RIGHT:
		rect.size = Vector2(attack_range, attack_width)
	else:
		rect.size = Vector2(attack_width, attack_range)

	shape.shape = rect

	# Posicionar el hitbox delante del jugador
	var offset: Vector2 = facing * (attack_range * 0.5 + 2.0)
	_hitbox.position = offset

	_hitbox.add_child(shape)
	_body.add_child(_hitbox)

	# Conectar detección de colisiones
	_hitbox.body_entered.connect(_on_hitbox_body_entered)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body == _body:
		return  # No dañarse a sí mismo
	if body in _damaged_entities:
		return  # Ya dañado en este ataque

	# Buscar HealthComponent en la entidad impactada
	var health: HealthComponent = null
	for child in body.get_children():
		if child is HealthComponent:
			health = child
			break

	if health == null:
		return  # La entidad no tiene vida

	_damaged_entities.append(body)

	# Calcular daño usando CombatService
	var combat_svc: CombatService = EventBus.services.combat as CombatService
	var net_damage: float = base_damage
	if combat_svc:
		net_damage = combat_svc.calculate_damage(base_damage, 0.0)

	health.take_damage(net_damage)

	# Empuje + interrupción: el golpe del player no es solo daño, también
	# desplaza al enemigo y le corta cualquier ataque en preparación.
	# Dirección del knockback: del player al enemigo (o facing si están encima).
	var push_dir: Vector2 = (body.global_position - _body.global_position)
	if push_dir.length_squared() < 0.01:
		push_dir = _last_attack_facing
	else:
		push_dir = push_dir.normalized()
	for child in body.get_children():
		if child is MovementComponent:
			(child as MovementComponent).apply_knockback(push_dir * knockback_force)
		if child.has_method("interrupt"):
			child.interrupt()


func _cleanup_hitbox() -> void:
	if _hitbox and is_instance_valid(_hitbox):
		_hitbox.queue_free()
		_hitbox = null
