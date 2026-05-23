## CombatService — Servicio auxiliar de cálculo de daño.
##
## Centraliza TODA la matemática de combate en un solo lugar.
## Recibe un daño base y una armadura, y devuelve un daño neto.
##
## --- Arquitectura ---
## • Registrado por main.gd con clave "combat" en el ServiceLocator.
## • Es RefCounted: no necesita _process() ni estar en el árbol.
## • NO colisiona. NO sabe quién golpeó a quién.
##   Solo recibe dos números y devuelve uno.
##
## --- Fórmulas ---
## • Daño neto = max(base_damage - armor, min_damage)
## • min_damage garantiza que siempre se haga al menos 1 de daño.
##
## --- Límites ---
## No detecta colisiones, no conoce posiciones, no modifica HP.
## Solo calcula y devuelve un número.
class_name CombatService
extends RefCounted

## Daño mínimo que siempre se aplica, incluso con armadura alta.
const MIN_DAMAGE: float = 1.0


## Calcula el daño neto dado un daño base y una armadura defensiva.
## Devuelve el daño final validado (siempre >= MIN_DAMAGE).
func calculate_damage(base_damage: float, flat_armor: float = 0.0, percent_armor: float = 0.0) -> float:
	var net_damage: float = maxf(base_damage * (1.0 - percent_armor) - flat_armor, MIN_DAMAGE)
	return net_damage


## Variante con multiplicador crítico.
## critical_multiplier = 1.0 para golpe normal, 2.0 para crítico, etc.
func calculate_critical_damage(base_damage: float,critical_multiplier: float, flat_armor: float = 0.0, percent_armor: float = 0.0) -> float:
	var raw: float = base_damage * critical_multiplier
	return maxf(base_damage * (1.0 - percent_armor) - flat_armor, MIN_DAMAGE)
