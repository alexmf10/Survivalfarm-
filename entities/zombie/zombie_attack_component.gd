## ZombieAttackComponent — Ataque cuerpo a cuerpo del zombie con fases.
##
## A diferencia del modelo "tocas y haces daño", el zombi solo hace daño
## cuando ejecuta un ataque real. El ataque tiene tres fases legibles:
##
##   WINDUP   → telegraph: se frena, mira al jugador, scale crece (0.45 s)
##   STRIKE   → hitbox activa + lunge corto en dirección bloqueada (0.15 s)
##   RECOVERY → vendido, no puede atacar (0.55 s) → ventana de castigo
##
## Si el jugador golpea al zombi, interrupt() cancela el estado actual y
## entra en HIT_STUN durante un instante. La IA detecta is_busy() y no
## intenta mover al zombi mientras hay una fase de ataque activa.
##
## --- Coordinación entre varios zombies ---
## Antes de entrar en WINDUP se pide un slot a EnemyCoordinatorService.
## Si no hay slot disponible, try_start_attack() devuelve false y el
## ZombieAIComponent pasa a CIRCLE para presionar sin pegar.
##
## --- API ---
## • try_start_attack(target_pos) → bool (la llama la IA en rango)
## • is_busy() → bool (consulta de la IA)
## • interrupt() (la llama zombie.gd al recibir daño)
class_name ZombieAttackComponent
extends Node

enum State { IDLE, WINDUP, STRIKE, RECOVERY, HIT_STUN }

# ── Configuración ────────────────────────────────────────────────────────────
@export var base_damage: float = 8.0

## Tamaño del hitbox a lo largo del eje del ataque. También determina cuán
## adelante del zombi se coloca el hitbox (a attack_range/2 + 2 px).
@export var attack_range: float = 18.0

## Tamaño del hitbox perpendicular al eje del ataque.
@export var attack_width: float = 14.0

## Tiempo de telegraph antes del golpe (jugador puede leerlo y esquivar).
@export var windup_duration: float = 0.45

## Tiempo en el que el hitbox está activo y el zombi se compromete.
@export var strike_duration: float = 0.15

## Tiempo de "vendido" tras el golpe — ventana de castigo del jugador.
@export var recovery_duration: float = 0.55

## Tiempo de stun cuando el zombi recibe un golpe.
@export var hit_stun_duration: float = 0.30

## Escala objetivo del sprite al final del WINDUP (telegraph).
@export var windup_scale_factor: float = 1.12

# ── Estado interno ───────────────────────────────────────────────────────────
var _state: int = State.IDLE
var _state_timer: float = 0.0
var _locked_direction: Vector2 = Vector2.DOWN
var _hitbox: Area2D = null
var _has_dealt_damage: bool = false
var _original_scale: Vector2 = Vector2.ONE
var _telegraph_tween: Tween = null

# Referencias a hermanos
var _body: CharacterBody2D
var _animation: AnimationComponent
var _movement: MovementComponent
var _sprite: AnimatedSprite2D
var _coord: EnemyCoordinatorService = null


func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	if _body == null:
		push_error("ZombieAttackComponent: el padre no es CharacterBody2D.")
		set_process(false)
		return

	for child in _body.get_children():
		if child is AnimationComponent:
			_animation = child
		if child is MovementComponent:
			_movement = child
		if child is AnimatedSprite2D:
			_sprite = child

	if _sprite:
		_original_scale = _sprite.scale

	_coord = EventBus.services.enemy_coord as EnemyCoordinatorService


func _exit_tree() -> void:
	_kill_telegraph_tween()
	_cleanup_hitbox()
	_release_slot()
	if is_instance_valid(_sprite):
		_sprite.scale = _original_scale


func _process(delta: float) -> void:
	if _state == State.IDLE:
		return
	_state_timer -= delta
	if _state_timer > 0.0:
		return
	# Transición al siguiente estado al expirar el timer
	match _state:
		State.WINDUP:
			_enter_strike()
		State.STRIKE:
			_enter_recovery()
		State.RECOVERY:
			_release_slot()
			_state = State.IDLE
		State.HIT_STUN:
			# El slot ya se liberó en interrupt()
			_state = State.IDLE


# ── API pública ──────────────────────────────────────────────────────────────

## Devuelve true si el componente está procesando un ataque (cualquier fase
## distinta de IDLE). La IA usa esto para no pelearse por el movimiento.
func is_busy() -> bool:
	return _state != State.IDLE


## Intenta iniciar un ataque dirigido a target_pos. Devuelve true si se
## inició (entró en WINDUP). Si está ocupado o no hay slot del coordinador,
## devuelve false.
func try_start_attack(target_pos: Vector2) -> bool:
	if _state != State.IDLE or _body == null:
		return false
	if _coord and not _coord.request_attack_slot(_body):
		return false

	_locked_direction = _to_cardinal(_body.global_position.direction_to(target_pos))
	if _movement:
		_movement.face_direction(_locked_direction)
	_enter_windup()
	return true


## Cancela el estado actual y entra en HIT_STUN. La llama zombie.gd cuando
## el zombi recibe daño. Libera el slot del coordinador y limpia el hitbox.
func interrupt() -> void:
	if _state == State.IDLE:
		return
	_release_slot()
	_cleanup_hitbox()
	_kill_telegraph_tween()
	if is_instance_valid(_sprite):
		_sprite.scale = _original_scale
	if _movement:
		_movement.set_direction(Vector2.ZERO)
	_state = State.HIT_STUN
	_state_timer = hit_stun_duration


# ── Transiciones de estado ───────────────────────────────────────────────────

func _enter_windup() -> void:
	_state = State.WINDUP
	_state_timer = windup_duration
	if _movement:
		# Forzar el facing hacia el jugador antes de parar
		_movement.face_direction(_locked_direction)
		_movement.set_direction(Vector2.ZERO)
	# Telegraph visual: el sprite crece progresivamente durante el windup.
	_kill_telegraph_tween()
	if is_instance_valid(_sprite):
		_telegraph_tween = create_tween()
		_telegraph_tween.tween_property(
			_sprite, "scale", _original_scale * windup_scale_factor, windup_duration
		)


func _enter_strike() -> void:
	_state = State.STRIKE
	_state_timer = strike_duration
	_has_dealt_damage = false
	# Snap rápido del scale a normal: comunica el "lanzazo".
	_kill_telegraph_tween()
	if is_instance_valid(_sprite):
		_telegraph_tween = create_tween()
		_telegraph_tween.tween_property(_sprite, "scale", _original_scale, 0.05)
	# Lunge: dirección bloqueada + velocidad de embestida durante esta fase.
	if _movement:
		_movement.face_direction(_locked_direction)
		_movement.set_direction(Vector2.ZERO)
	# Animación de ataque y hitbox físico.
	if _animation:
		_animation.play_action("attack")
	_spawn_hitbox(_locked_direction)


func _enter_recovery() -> void:
	_state = State.RECOVERY
	_state_timer = recovery_duration
	_cleanup_hitbox()
	if _movement:
		_movement.set_direction(Vector2.ZERO)


# ── Hitbox ───────────────────────────────────────────────────────────────────

func _spawn_hitbox(facing: Vector2) -> void:
	_cleanup_hitbox()
	_hitbox = Area2D.new()
	_hitbox.name = "ZombieHitbox"
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 2  # Solo player (capa 2)
	_hitbox.monitorable = false
	_hitbox.monitoring = true

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	if facing.x != 0.0:
		rect.size = Vector2(attack_range, attack_width)
	else:
		rect.size = Vector2(attack_width, attack_range)
	shape.shape = rect
	_hitbox.add_child(shape)
	_hitbox.position = facing * (attack_range * 0.5 + 2.0)
	_body.add_child(_hitbox)
	_hitbox.body_entered.connect(_on_hitbox_body_entered)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if _has_dealt_damage:
		return
	if not (body is Player):
		return
	var health: HealthComponent = null
	for child in body.get_children():
		if child is HealthComponent:
			health = child
			break
	if health == null:
		return
	_has_dealt_damage = true
	var combat_svc: CombatService = EventBus.services.combat as CombatService
	var net_damage: float = base_damage
	if combat_svc:
		net_damage = combat_svc.calculate_damage(base_damage, 0.0)
	health.take_damage(net_damage)
	# Pequeño empujón al jugador hacia atrás del zombi.
	for child in body.get_children():
		if child is MovementComponent:
			(child as MovementComponent).apply_knockback(_locked_direction * 80.0)
			break


func _cleanup_hitbox() -> void:
	if _hitbox and is_instance_valid(_hitbox):
		_hitbox.queue_free()
	_hitbox = null


# ── Helpers ──────────────────────────────────────────────────────────────────

func _release_slot() -> void:
	if _coord and _body:
		_coord.release_attack_slot(_body)


func _kill_telegraph_tween() -> void:
	if _telegraph_tween and _telegraph_tween.is_running():
		_telegraph_tween.kill()
	_telegraph_tween = null


func _to_cardinal(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2.RIGHT if v.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if v.y > 0.0 else Vector2.UP
